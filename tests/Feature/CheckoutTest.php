<?php

namespace Tests\Feature;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class CheckoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_buyer_can_checkout_selected_cart_items(): void
    {
        $buyer = User::create([
            'role' => 'buyer',
            'status' => 'approved',
            'last_name' => 'Buyer',
            'first_name' => 'Test',
            'middle_initial' => null,
            'sex' => 'Male',
            'email' => 'buyer.checkout@example.com',
            'password' => Hash::make('secret123'),
            'contact_no' => '09123456789',
            'birthday' => '1995-01-01',
            'age' => 31,
            'province' => 'Metro Manila',
            'municipality' => 'Quezon City',
            'barangay' => 'Diliman',
            'street' => 'Katipunan Ave',
            'house_no' => '123',
            'id_upload' => 'uploads/test.jpg',
        ]);

        $seller = User::create([
            'role' => 'seller',
            'status' => 'approved',
            'last_name' => 'Seller',
            'first_name' => 'Test',
            'middle_initial' => null,
            'sex' => 'Female',
            'email' => 'seller.checkout@example.com',
            'password' => Hash::make('secret123'),
            'contact_no' => '09987654321',
            'birthday' => '1990-01-01',
            'age' => 36,
            'province' => 'Metro Manila',
            'municipality' => 'Taguig',
            'barangay' => 'Fort Bonifacio',
            'street' => 'Main St',
            'house_no' => '9',
            'id_upload' => 'uploads/seller.jpg',
            'business_name' => 'Test Shop',
            'line_of_business' => 'Retail',
            'business_permit' => 'uploads/permit.pdf',
        ]);

        $product = Product::create([
            'seller_id' => $seller->id,
            'name' => 'Sample Product',
            'description' => 'Test product',
            'category' => 'Electronics',
            'price' => 500.00,
            'discount' => 0,
            'voucher_code' => null,
            'voucher_discount' => 0,
            'stock' => 10,
            'image' => null,
            'status' => 'active',
        ]);

        $logistics = User::create([
            'role' => 'logistics',
            'status' => 'approved',
            'first_name' => 'Test',
            'last_name' => 'Logistics',
            'business_name' => 'Test Express',
            'email' => 'logistics.checkout@example.com',
            'password' => Hash::make('secret123'),
            'contact_no' => '09111111112',
            'birthday' => '1990-01-01',
            'age' => 36,
        ]);

        $cart = Cart::create(['buyer_id' => $buyer->id]);
        $item = CartItem::create([
            'cart_id' => $cart->id,
            'product_id' => $product->id,
            'quantity' => 1,
        ]);

        $response = $this->actingAs($buyer)
            ->from('/buyer/cart')
            ->post('/buyer/cart/checkout', [
                'item_ids' => [$item->id],
                'payment_method' => 'cod',
                'logistics_id' => $logistics->id,
            ]);

        $response->assertRedirect('/buyer/orders');
        $this->assertDatabaseHas('orders', [
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'quantity' => 1,
            'status' => 'pending',
        ]);
    }
}
