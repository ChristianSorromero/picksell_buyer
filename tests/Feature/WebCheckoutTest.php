<?php

namespace Tests\Feature;

use App\Models\BuyerAddress;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** The web shop's cart and checkout charge and reserve stock exactly like the app. */
class WebCheckoutTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;
    private User $seller;
    private User $logistics;
    private Product $mug;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buyer = $this->user('buyer', 'buyer@test.ph', [
            'province' => 'Metro Manila', 'municipality' => 'Pasig', 'barangay' => 'Kapitolyo', 'street' => 'United St', 'house_no' => '5',
        ]);
        $this->seller = $this->user('seller', 'seller@test.ph', ['business_name' => 'Mug House']);
        $this->logistics = $this->user('logistics', 'logistics@test.ph', ['delivery_area' => 'Metro Manila', 'provider_type' => 'company']);
        $this->mug = Product::create([
            'seller_id' => $this->seller->id, 'name' => 'Ceramic Mug', 'category' => 'Home',
            'price' => 300, 'discount' => 0, 'stock' => 5, 'status' => 'active',
        ]);
    }

    private function user(string $role, string $email, array $extra = []): User
    {
        static $n = 0;
        $n++;
        return User::create($extra + [
            'role' => $role, 'status' => 'approved', 'first_name' => 'Test', 'last_name' => ucfirst($role),
            'email' => $email, 'password' => Hash::make('Password1!'), 'contact_no' => '0917400' . str_pad((string) $n, 4, '0', STR_PAD_LEFT),
            'birthday' => '1995-01-01', 'age' => 30,
        ]);
    }

    private function cartItem(int $quantity = 1, ?Product $product = null): CartItem
    {
        $cart = Cart::firstOrCreate(['buyer_id' => $this->buyer->id]);
        return CartItem::create(['cart_id' => $cart->id, 'product_id' => ($product ?? $this->mug)->id, 'quantity' => $quantity]);
    }

    private function checkout(array $items, array $extra = [])
    {
        return $this->actingAs($this->buyer)->from('/buyer/cart')->post('/buyer/cart/checkout', $extra + [
            'item_ids' => collect($items)->pluck('id')->all(), 'payment_method' => 'cod', 'shipping_option' => 'standard',
        ]);
    }

    public function test_web_checkout_charges_shipping_snapshots_the_address_and_routes_logistics(): void
    {
        $item = $this->cartItem(2);

        $this->checkout([$item])->assertRedirect('/buyer/orders')->assertSessionHas('success', 'Order placed! Total charged on delivery: ₱645.00.');

        $order = Order::sole();
        $this->assertEquals(600, $order->amount);
        $this->assertEquals(45, $order->shipping_fee);
        $this->assertEquals(645, $order->total);
        $this->assertSame($this->logistics->id, $order->logistics_id);
        $this->assertSame('5, United St, Kapitolyo, Pasig, Metro Manila', $order->ship_to['full_address']);
        $this->assertSame('placed', $order->canonical_status);
        $this->assertSame(3, $this->mug->fresh()->stock);
        $this->assertNull(CartItem::find($item->id));
    }

    public function test_a_saved_default_address_is_preferred_over_the_profile(): void
    {
        BuyerAddress::create([
            'user_id' => $this->buyer->id, 'label' => 'work', 'recipient_name' => 'Office Desk', 'phone' => '09170000000',
            'province' => 'Cebu', 'municipality' => 'Cebu City', 'barangay' => 'Lahug', 'street' => 'IT Park', 'is_default' => true,
        ]);

        $this->checkout([$this->cartItem()])->assertRedirect('/buyer/orders');

        $this->assertSame('Office Desk', Order::sole()->ship_to['recipient_name']);
        $this->assertSame('Cebu City, Cebu', Order::sole()->delivery['area']);
    }

    public function test_checkout_refuses_when_stock_ran_out_and_reserves_nothing(): void
    {
        $item = $this->cartItem(4);
        $this->mug->update(['stock' => 2]);

        $this->checkout([$item])->assertRedirect('/buyer/cart')->assertSessionHasErrors('item_ids');

        $this->assertSame(0, Order::count());
        $this->assertSame(2, $this->mug->fresh()->stock);
    }

    public function test_archived_products_cannot_be_added_or_bought(): void
    {
        $item = $this->cartItem();
        $this->mug->update(['status' => 'archived']);

        $this->actingAs($this->buyer)->from('/buyer/cart')->post("/buyer/cart/{$this->mug->id}", ['quantity' => 1])
            ->assertSessionHasErrors('quantity');
        $this->checkout([$item])->assertSessionHasErrors('item_ids');
        $this->assertSame(0, Order::count());
    }

    public function test_cart_quantities_are_capped_by_stock(): void
    {
        $this->actingAs($this->buyer)->from('/buyer/cart')->post("/buyer/cart/{$this->mug->id}", ['quantity' => 9])
            ->assertSessionHasErrors(['quantity' => 'Only 5 left in stock.']);
        $this->actingAs($this->buyer)->post("/buyer/cart/{$this->mug->id}", ['quantity' => 3])->assertRedirect('/buyer/cart');
        $this->actingAs($this->buyer)->from('/buyer/cart')->post("/buyer/cart/{$this->mug->id}", ['quantity' => 3])
            ->assertSessionHasErrors('quantity'); // 3 already in the cart

        $item = CartItem::sole();
        $this->actingAs($this->buyer)->patchJson("/buyer/cart/item/{$item->id}", ['quantity' => 6])->assertStatus(422)
            ->assertJsonPath('errors.quantity.0', 'Only 5 left in stock.');
        $this->assertSame(3, $item->fresh()->quantity);
    }

    public function test_a_variation_from_another_product_is_rejected(): void
    {
        $other = Product::create(['seller_id' => $this->seller->id, 'name' => 'Tee', 'price' => 200, 'stock' => 5, 'status' => 'active']);
        $size = ProductVariation::create(['product_id' => $other->id, 'type' => 'Size', 'value' => 'M', 'stock' => 5]);

        $this->actingAs($this->buyer)->from('/buyer/cart')->post("/buyer/cart/{$this->mug->id}", ['quantity' => 1, 'variation_id' => $size->id])
            ->assertSessionHasErrors('variation_id');
        $this->assertSame(0, CartItem::count());
    }

    public function test_unavailable_payment_methods_and_missing_addresses_are_refused(): void
    {
        $item = $this->cartItem();
        $this->checkout([$item], ['payment_method' => 'gcash'])->assertSessionHasErrors('payment_method');

        $this->buyer->update(['province' => null, 'municipality' => null, 'barangay' => null]);
        $this->checkout([$item])->assertSessionHasErrors('address');
        $this->assertSame(0, Order::count());
    }
}
