<?php

namespace Tests\Feature\Api\Concerns;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;

/** Rows shaped like the ones the Picksell website writes. */
trait BuildsMarketplace
{
    private int $people = 0;

    protected function person(string $role, array $extra = []): User
    {
        $n = ++$this->people;

        return User::create($extra + [
            'role' => $role, 'status' => 'approved', 'first_name' => 'Test', 'last_name' => ucfirst($role).$n,
            'sex' => 'Female', 'email' => "{$role}{$n}@test.ph", 'password' => Hash::make('Password1!'),
            'contact_no' => '0917'.str_pad((string) $n, 7, '0', STR_PAD_LEFT), 'birthday' => '1995-01-01', 'age' => 30,
            'province' => 'Cebu', 'municipality' => 'Cebu City', 'barangay' => 'Lahug', 'street' => 'Gorordo Ave', 'house_no' => '12',
        ]);
    }

    protected function seller(array $extra = []): User
    {
        return $this->person('seller', $extra + ['business_name' => 'Lamp Shop']);
    }

    protected function buyer(array $extra = []): User
    {
        return $this->person('buyer', $extra);
    }

    protected function admin(): User
    {
        return $this->person('admin');
    }

    protected function actingAsBuyer(?User $buyer = null): User
    {
        $buyer ??= $this->buyer();
        Sanctum::actingAs($buyer);

        return $buyer;
    }

    protected function product(User $seller, array $extra = []): Product
    {
        $product = Product::create($extra + [
            'seller_id' => $seller->id, 'name' => 'Desk Lamp', 'category' => 'Home & Living',
            'price' => 1000, 'discount' => 0, 'stock' => 5, 'status' => 'active',
        ]);
        ProductImage::create(['product_id' => $product->id, 'image_url' => "products/{$product->id}.jpg", 'is_primary' => true, 'display_order' => 0]);

        return $product->fresh();
    }

    protected function cartLine(User $buyer, Product $product, int $quantity = 1, ?int $variationId = null): CartItem
    {
        $cart = Cart::firstOrCreate(['buyer_id' => $buyer->id]);

        return CartItem::create(['cart_id' => $cart->id, 'product_id' => $product->id, 'variation_id' => $variationId, 'quantity' => $quantity]);
    }

    protected function order(User $buyer, Product $product, string $status = 'placed', array $extra = []): Order
    {
        return Order::create($extra + [
            'order_number' => 'ORD-'.strtoupper(substr(md5((string) microtime(true).mt_rand()), 0, 8)),
            'product_id' => $product->id, 'buyer_id' => $buyer->id, 'seller_id' => $product->seller_id,
            'product_name' => $product->name, 'quantity' => 2, 'amount' => 2000, 'commission' => 200, 'commission_rate' => 10,
            'status' => $status, 'tracking_status' => 'Order placed and awaiting seller preparation',
        ]);
    }
}
