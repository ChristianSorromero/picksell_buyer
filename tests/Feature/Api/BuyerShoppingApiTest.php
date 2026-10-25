<?php

namespace Tests\Feature\Api;

use App\Models\BuyerAddress;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BuyerShoppingApiTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;
    private User $seller;
    private Product $shirt;
    private Product $mug;
    private BuyerAddress $address;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buyer = $this->user('buyer', 'buyer@test.ph', '09170000001');
        $this->seller = $this->user('seller', 'seller@test.ph', '09170000002', ['business_name' => 'Island Threads']);

        $this->shirt = Product::create([
            'seller_id' => $this->seller->id, 'name' => 'Cotton Tee', 'category' => 'Fashion',
            'price' => 500, 'discount' => 20, 'stock' => 5, 'status' => 'active',
        ]);
        foreach (['Color' => ['White' => 3, 'Black' => 5], 'Size' => ['M' => 5, 'L' => 1]] as $type => $values) {
            foreach ($values as $value => $stock) {
                ProductVariation::create(['product_id' => $this->shirt->id, 'type' => $type, 'value' => $value, 'stock' => $stock]);
            }
        }
        $this->mug = Product::create([
            'seller_id' => $this->seller->id, 'name' => 'Ceramic Mug', 'category' => 'Home',
            'price' => 300, 'discount' => 0, 'stock' => 10, 'status' => 'active',
        ]);

        $this->address = BuyerAddress::create([
            'user_id' => $this->buyer->id, 'label' => 'home', 'recipient_name' => 'Juan Dela Cruz',
            'phone' => '09171234567', 'province' => 'Metro Manila', 'municipality' => 'Quezon City',
            'barangay' => 'Diliman', 'street' => 'Rizal Ave', 'is_default' => true,
        ]);

        Sanctum::actingAs($this->buyer);
    }

    private function user(string $role, string $email, string $phone, array $extra = []): User
    {
        return User::create($extra + [
            'role' => $role, 'status' => 'approved', 'first_name' => 'Test', 'last_name' => ucfirst($role),
            'email' => $email, 'password' => Hash::make('Password1!'), 'contact_no' => $phone,
            'birthday' => '1995-01-01', 'age' => 30,
        ]);
    }

    private function variation(string $value): int
    {
        return ProductVariation::where('product_id', $this->shirt->id)->where('value', $value)->value('id');
    }

    private function addShirt(int $qty = 1, array $values = ['White', 'M'])
    {
        return $this->postJson('/api/buyer/cart', [
            'product_id' => $this->shirt->id, 'quantity' => $qty,
            'variation_ids' => array_map(fn ($v) => $this->variation($v), $values),
        ]);
    }

    public function test_variations_are_required_and_same_choice_merges_lines(): void
    {
        $this->postJson('/api/buyer/cart', ['product_id' => $this->shirt->id, 'quantity' => 1])
            ->assertStatus(422)->assertJsonValidationErrors('variation_ids');

        $this->addShirt(1, ['White', 'M'])->assertCreated();
        $this->addShirt(1, ['M', 'White'])->assertCreated();

        $cart = $this->getJson('/api/buyer/cart')->assertOk()->json('cart');
        $this->assertCount(1, $cart['groups'][0]['items']);
        $this->assertSame(2, $cart['groups'][0]['items'][0]['quantity']);
        $this->assertSame('White, M', $cart['groups'][0]['items'][0]['variation_label']);
    }

    public function test_quantity_is_capped_by_the_lowest_variation_stock(): void
    {
        $this->addShirt(2, ['White', 'L'])->assertStatus(422)->assertJsonValidationErrors('quantity');
        $this->addShirt(1, ['White', 'L'])->assertCreated();
    }

    public function test_cart_quantity_update_and_removal(): void
    {
        $id = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1])->json('cart_item_id');

        $this->patchJson("/api/buyer/cart/{$id}", ['quantity' => 3])->assertOk()
            ->assertJsonPath('cart.groups.0.items.0.quantity', 3)
            ->assertJsonPath('cart.totals.merchandise_subtotal', 900);

        $this->patchJson("/api/buyer/cart/{$id}", ['quantity' => 0])->assertStatus(422);
        $this->deleteJson("/api/buyer/cart/{$id}")->assertOk()->assertJsonPath('cart.groups', []);
    }

    public function test_quote_and_placement_charge_the_same_total_with_voucher(): void
    {
        Voucher::create(['code' => 'SAVE50', 'scope' => 'platform', 'type' => 'fixed', 'value' => 50, 'min_spend' => 500, 'active' => true]);
        $a = $this->addShirt(2)->json('cart_item_id');                      // 2 × 400
        $b = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1])->json('cart_item_id');

        $payload = ['item_ids' => [$a, $b], 'shipping_option' => 'standard', 'voucher_code' => 'save50'];
        $quote = $this->postJson('/api/buyer/checkout/quote', $payload)->assertOk()->json('quote');

        $this->assertEquals(1100, $quote['totals']['merchandise_subtotal']);
        $this->assertEquals(45, $quote['totals']['shipping_total']); // one seller → one parcel fee
        $this->assertEquals(50, $quote['totals']['discount_total']);
        $this->assertEquals(1095, $quote['totals']['total']);

        $placed = $this->postJson('/api/buyer/checkout', $payload + ['address_id' => $this->address->id, 'payment_method' => 'cod'])
            ->assertCreated()->json();

        $this->assertEquals($quote['totals']['total'], $placed['totals']['total']);
        $this->assertEquals(1095, Order::sum('total'));
        $this->assertSame(3, $this->shirt->fresh()->stock);
        $this->assertSame(1, ProductVariation::find($this->variation('White'))->stock);
        $this->getJson('/api/buyer/cart')->assertJsonPath('cart.groups', []);
        $this->assertSame('Juan Dela Cruz', Order::first()->ship_to['recipient_name']);
    }

    public function test_voucher_min_spend_and_unavailable_payment_are_rejected(): void
    {
        Voucher::create(['code' => 'BIG', 'scope' => 'platform', 'type' => 'fixed', 'value' => 100, 'min_spend' => 5000, 'active' => true]);
        $id = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1])->json('cart_item_id');

        $this->postJson('/api/buyer/checkout/quote', ['item_ids' => [$id], 'voucher_code' => 'BIG'])
            ->assertOk()->assertJsonPath('quote.voucher', null)
            ->assertJsonPath('quote.voucher_error', 'Spend ₱4,700.00 more to use this voucher.');

        $this->postJson('/api/buyer/checkout', ['item_ids' => [$id], 'address_id' => $this->address->id, 'payment_method' => 'gcash'])
            ->assertStatus(422)->assertJsonValidationErrors('payment_method');
    }

    public function test_checkout_refuses_when_stock_ran_out(): void
    {
        $id = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 2])->json('cart_item_id');
        $this->mug->update(['stock' => 1]);

        $this->postJson('/api/buyer/checkout', ['item_ids' => [$id], 'address_id' => $this->address->id, 'payment_method' => 'cod'])
            ->assertStatus(409)->assertJsonPath('quote.groups.0.items.0.issue', 'insufficient_stock');
        $this->assertSame(0, Order::count());
    }

    public function test_order_lifecycle_tracking_cancel_rate_and_return(): void
    {
        $id = $this->addShirt(1)->json('cart_item_id');
        $orderId = $this->postJson('/api/buyer/checkout', ['item_ids' => [$id], 'address_id' => $this->address->id, 'payment_method' => 'cod'])
            ->json('orders.0.id');
        $order = Order::find($orderId);

        $this->getJson("/api/buyer/orders/{$orderId}")->assertOk()
            ->assertJsonPath('order.status', 'placed')
            ->assertJsonPath('order.actions.can_cancel', true);

        // Seller / logistics / courier dashboards update the row; events follow.
        $order->update(['status' => 'processing', 'packed_at' => now()]);
        $order->update(['status' => 'shipped', 'tracking_status' => 'Handed over to courier', 'handed_over_at' => now()]);
        $this->postJson("/api/buyer/orders/{$orderId}/cancel", ['reason' => 'Changed mind'])->assertStatus(422);
        $order->update(['tracking_status' => 'Out for delivery']);
        $order->update(['status' => 'completed', 'tracking_status' => 'Delivered', 'delivered_at' => now()]);

        $detail = $this->getJson("/api/buyer/orders/{$orderId}")->json('order');
        $this->assertSame(['placed', 'preparing', 'picked_up', 'out_for_delivery', 'delivered'], array_column($detail['events'], 'status'));
        $this->assertSame('to_rate', $detail['tab']);

        $this->postJson("/api/buyer/orders/{$orderId}/rate", ['rating' => 4, 'feedback' => 'Nice fit'])->assertOk()
            ->assertJsonPath('order.status', 'completed');
        $this->getJson("/api/products/{$this->shirt->id}/reviews")
            ->assertJsonPath('summary.count', 1)->assertJsonPath('reviews.0.comment', 'Nice fit');

        // COD only: refunds go back in cash, never to a wallet.
        $this->postJson("/api/buyer/orders/{$orderId}/return", ['quantity' => 1, 'reason' => 'Wrong item received', 'refund_to' => 'gcash'])
            ->assertStatus(422)->assertJsonValidationErrors('refund_to');
        $this->postJson("/api/buyer/orders/{$orderId}/return", ['quantity' => 1, 'reason' => 'Wrong item received', 'refund_to' => 'cash'])
            ->assertCreated()->assertJsonPath('return_request.refund_amount', 400)
            ->assertJsonPath('return_request.status', 'requested')->assertJsonPath('return_request.stage', 'requested');
        $this->postJson("/api/buyer/orders/{$orderId}/return", ['quantity' => 1, 'reason' => 'Wrong item received'])
            ->assertStatus(422);
    }

    public function test_cancelling_restores_stock_and_other_buyers_cannot_see_orders(): void
    {
        $id = $this->addShirt(2, ['Black', 'M'])->json('cart_item_id');
        $orderId = $this->postJson('/api/buyer/checkout', ['item_ids' => [$id], 'address_id' => $this->address->id, 'payment_method' => 'cod'])
            ->json('orders.0.id');
        $this->assertSame(3, $this->shirt->fresh()->stock);

        $this->postJson("/api/buyer/orders/{$orderId}/cancel", ['reason' => 'Ordered by mistake'])->assertOk()
            ->assertJsonPath('order.status', 'cancelled');
        $this->assertSame(5, $this->shirt->fresh()->stock);
        $this->assertSame(5, ProductVariation::find($this->variation('Black'))->stock);

        Sanctum::actingAs($this->user('buyer', 'other@test.ph', '09170000009'));
        $this->getJson("/api/buyer/orders/{$orderId}")->assertNotFound();
    }

    public function test_address_book_keeps_exactly_one_default(): void
    {
        $second = $this->postJson('/api/buyer/addresses', [
            'label' => 'work', 'recipient_name' => 'Juan', 'phone' => '09171234567', 'province' => 'Cebu',
            'municipality' => 'Cebu City', 'barangay' => 'Lahug', 'street' => 'Gorordo Ave', 'is_default' => true,
        ])->assertCreated()->json('address.id');

        $this->assertFalse($this->address->fresh()->is_default);
        $this->deleteJson("/api/buyer/addresses/{$second}")->assertOk();
        $this->assertTrue($this->address->fresh()->is_default);

        $this->postJson('/api/buyer/addresses', ['label' => 'home', 'phone' => '123'])
            ->assertStatus(422)->assertJsonValidationErrors(['recipient_name', 'phone']);
    }

    public function test_catalog_filters_sorts_and_wishlist_flag(): void
    {
        $this->postJson("/api/buyer/wishlist/{$this->mug->id}")->assertCreated();

        $res = $this->getJson('/api/products?sort=price_asc')->assertOk();
        $this->assertSame(['Ceramic Mug', 'Cotton Tee'], array_column($res->json('products'), 'name'));
        $this->assertTrue($res->json('products.0.wishlisted'));

        $this->getJson('/api/products?on_sale=1')->assertJsonCount(1, 'products')->assertJsonPath('products.0.discount_percent', 20);
        $this->getJson("/api/products/{$this->shirt->id}")->assertOk()
            ->assertJsonPath('product.variation_groups.0.name', 'Color')
            ->assertJsonPath('product.price', 400);
    }
}
