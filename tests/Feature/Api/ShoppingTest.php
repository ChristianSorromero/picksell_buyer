<?php

namespace Tests\Feature\Api;

use App\Models\CartItem;
use App\Models\Order;
use App\Models\OrderStatusHistory;
use App\Models\ProductVariation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Api\Concerns\BuildsMarketplace;
use Tests\TestCase;

class ShoppingTest extends TestCase
{
    use BuildsMarketplace, RefreshDatabase;

    public function test_the_catalog_shows_what_the_website_shop_shows(): void
    {
        $seller = $this->seller();
        $pending = $this->person('seller', ['status' => 'pending']);
        $lamp = $this->product($seller, ['name' => 'Desk Lamp', 'discount' => 20]);
        $this->product($seller, ['name' => 'Sold Out Mug', 'stock' => 0]);
        $this->product($seller, ['name' => 'Archived Vase', 'status' => 'archived']);
        $this->product($pending, ['name' => 'Unapproved Shop Item']);

        $names = collect($this->getJson('/api/products')->assertOk()->json('products'))->pluck('name')->all();
        $this->assertSame(['Desk Lamp'], $names);

        $card = $this->getJson("/api/products/{$lamp->id}")->assertOk()->json('product');
        $this->assertSame(800, (int) $card['price']);
        $this->assertSame(1000, (int) $card['original_price']);
        $this->assertStringEndsWith("/storage/products/{$lamp->id}.jpg", $card['image']);
        $this->getJson('/api/home')->assertOk()->assertJsonPath('hot_discounts.0.name', 'Desk Lamp');
    }

    public function test_cart_lines_follow_the_website_cart_model(): void
    {
        $seller = $this->seller();
        $lamp = $this->product($seller);
        $red = ProductVariation::create(['product_id' => $lamp->id, 'type' => 'Color', 'value' => 'Red', 'stock' => 3]);
        $blue = ProductVariation::create(['product_id' => $lamp->id, 'type' => 'Color', 'value' => 'Blue', 'stock' => 3]);
        $this->actingAsBuyer();

        $this->postJson('/api/buyer/cart', ['product_id' => $lamp->id, 'quantity' => 1, 'variation_ids' => [$red->id]])->assertCreated();
        $this->postJson('/api/buyer/cart', ['product_id' => $lamp->id, 'quantity' => 1, 'variation_ids' => [$red->id]])->assertCreated();
        $this->postJson('/api/buyer/cart', ['product_id' => $lamp->id, 'quantity' => 1, 'variation_ids' => [$red->id, $blue->id]])
            ->assertUnprocessable()->assertJsonValidationErrors('variation_ids');
        $this->postJson('/api/buyer/cart', ['product_id' => $lamp->id, 'quantity' => 9])->assertUnprocessable()->assertJsonValidationErrors('quantity');

        $line = CartItem::sole();
        $this->assertSame([$red->id, 2], [$line->variation_id, $line->quantity]);
        $this->getJson('/api/buyer/cart')->assertOk()
            ->assertJsonPath('cart.groups.0.items.0.variation_label', 'Color: Red')
            ->assertJsonPath('cart.totals.total', 2000);
    }

    public function test_checkout_stores_orders_exactly_like_the_website(): void
    {
        $seller = $this->seller();
        $lamp = $this->product($seller, ['price' => 1000, 'discount' => 10, 'voucher_code' => 'LAMP5', 'voucher_discount' => 5]);
        $mug = $this->product($seller, ['name' => 'Mug', 'price' => 250, 'stock' => 3]);
        $buyer = $this->actingAsBuyer();
        $lampLine = $this->cartLine($buyer, $lamp, 2);
        $mugLine = $this->cartLine($buyer, $mug, 1);

        // The quote is what the order will store: 1000 -10% = 900, LAMP5 -5% = 855 each.
        $this->postJson('/api/buyer/checkout/quote', ['item_ids' => [$lampLine->id, $mugLine->id], 'voucher_code' => 'LAMP5'])
            ->assertOk()
            ->assertJsonPath('quote.totals.merchandise_subtotal', 2050)
            ->assertJsonPath('quote.totals.discount_total', 90)
            ->assertJsonPath('quote.totals.total', 1960)
            ->assertJsonPath('quote.totals.shipping_total', 0)
            ->assertJsonPath('delivery_address.full_address', '12, Gorordo Ave, Lahug, Cebu City, Cebu');
        // Product vouchers match case-sensitively, as on the website.
        $this->postJson('/api/buyer/checkout/quote', ['item_ids' => [$lampLine->id], 'voucher_code' => 'lamp5'])
            ->assertJsonPath('quote.totals.discount_total', 0);

        $this->postJson('/api/buyer/checkout', ['item_ids' => [$lampLine->id, $mugLine->id], 'voucher_code' => 'LAMP5', 'payment_method' => 'cod'])
            ->assertCreated()->assertJsonPath('total', 1960);

        $order = Order::where('product_id', $lamp->id)->sole();
        $this->assertMatchesRegularExpression('/^ORD-[A-Z0-9]{8}$/', $order->order_number);
        $this->assertSame(
            ['placed', 'Order placed and awaiting seller preparation', 2, 1710.0, 171.0, '10.00', $seller->id],
            [$order->status, $order->tracking_status, $order->quantity, (float) $order->amount, (float) $order->commission, (string) $order->commission_rate, $order->seller_id],
        );
        $this->assertSame([3, 2], [$lamp->fresh()->stock, $mug->fresh()->stock]);
        $this->assertSame(0, CartItem::count());
        // The order history and the seller's bell get the same rows a website order creates.
        $this->assertSame('placed', OrderStatusHistory::where('order_id', $order->id)->sole()->to_status);
        $notice = $seller->notifications()->where('type', 'App\\Notifications\\NewSellerOrder')->where('data', 'like', '%'.$order->order_number.'%')->sole();
        $this->assertStringContainsString("New order #{$order->order_number}", $notice->data['message']);
    }

    public function test_checkout_refuses_like_the_website(): void
    {
        $seller = $this->seller();
        $lamp = $this->product($seller, ['stock' => 2]);
        $buyer = $this->actingAsBuyer();
        $first = $this->cartLine($buyer, $lamp, 2);
        $red = ProductVariation::create(['product_id' => $lamp->id, 'type' => 'Color', 'value' => 'Red', 'stock' => 5]);
        $second = $this->cartLine($buyer, $lamp, 1, $red->id);

        // Lines of the same product share its stock.
        $this->postJson('/api/buyer/checkout', ['item_ids' => [$first->id, $second->id]])
            ->assertUnprocessable()->assertJsonPath('errors.item_ids.0', 'Not enough stock for: Desk Lamp.');

        $lamp->update(['status' => 'archived']);
        $this->postJson('/api/buyer/checkout', ['item_ids' => [$first->id]])
            ->assertUnprocessable()->assertJsonPath('errors.item_ids.0', 'No longer available: Desk Lamp. Remove it from your cart to continue.');

        $lamp->update(['status' => 'active']);
        $buyer->update(['barangay' => '']);
        $this->postJson('/api/buyer/checkout', ['item_ids' => [$first->id]])->assertUnprocessable()->assertJsonValidationErrors('address');
        $this->assertSame(0, Order::count());
        $this->assertSame(2, $lamp->fresh()->stock);
    }

    public function test_buyers_cannot_check_out_someone_elses_cart(): void
    {
        $lamp = $this->product($this->seller());
        $owner = $this->buyer();
        $line = $this->cartLine($owner, $lamp);
        $this->actingAsBuyer();

        $this->postJson('/api/buyer/checkout', ['item_ids' => [$line->id]])->assertUnprocessable()->assertJsonPath('errors.item_ids.0', 'No items selected.');
        $this->patchJson("/api/buyer/cart/{$line->id}", ['quantity' => 3])->assertNotFound();
        $this->assertSame(1, $line->fresh()->quantity);
    }
}
