<?php

namespace Tests\Concerns;

use App\Models\BuyerAddress;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;

/** A small marketplace and orders placed through the real buyer API. */
trait BuildsMarketplace
{
    protected User $buyer;
    protected User $seller;
    protected User $logistics;
    protected User $courier;
    protected User $otherCourier;
    protected User $admin;
    protected Product $mug;

    protected function buildMarketplace(): void
    {
        Mail::fake();
        $this->buyer = $this->makeUser('buyer', 'buyer@test.ph', ['email_verified_at' => now()]);
        $this->seller = $this->makeUser('seller', 'seller@test.ph', ['business_name' => 'Mug House']);
        $this->logistics = $this->makeUser('logistics', 'logistics@test.ph', ['delivery_area' => 'Metro Manila', 'provider_type' => 'company']);
        $this->courier = $this->makeUser('courier', 'rider@test.ph', ['delivery_area' => 'Quezon City']);
        $this->otherCourier = $this->makeUser('courier', 'rider2@test.ph', ['delivery_area' => 'Pasig']);
        $this->admin = $this->makeUser('admin', 'admin@test.ph');
        $this->mug = Product::create([
            'seller_id' => $this->seller->id, 'name' => 'Ceramic Mug', 'category' => 'Home',
            'price' => 300, 'discount' => 0, 'stock' => 10, 'status' => 'active',
        ]);
    }

    protected function makeUser(string $role, string $email, array $extra = []): User
    {
        static $n = 0;
        $n++;
        return User::create($extra + [
            'role' => $role, 'status' => 'approved', 'first_name' => 'Test', 'last_name' => ucfirst($role) . $n,
            'email' => $email, 'password' => Hash::make('Password1!'), 'contact_no' => '0917600' . str_pad((string) $n, 4, '0', STR_PAD_LEFT),
            'birthday' => '1995-01-01', 'age' => 30,
        ]);
    }

    /** Places an order (₱300 × qty + ₱45 shipping, COD) through the buyer API. */
    protected function placeOrder(int $quantity = 1, array $extra = []): Order
    {
        Sanctum::actingAs($this->buyer);
        $address = BuyerAddress::firstOrCreate(['user_id' => $this->buyer->id], [
            'label' => 'home', 'recipient_name' => 'Ana Reyes', 'phone' => '09171234567',
            'province' => 'Metro Manila', 'municipality' => 'Quezon City', 'barangay' => 'Diliman',
            'street' => 'Katipunan Ave', 'is_default' => true,
        ]);
        $item = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => $quantity])->json('cart_item_id');
        $this->postJson('/api/buyer/checkout', $extra + [
            'item_ids' => [$item], 'address_id' => $address->id, 'payment_method' => 'cod', 'shipping_option' => 'standard',
        ])->assertCreated();
        $this->useWebGuard();

        return Order::latest('id')->first();
    }

    /** Fast-forwards an order to "out for delivery" with [$courier] (the web steps are covered by OrderWorkflowTest). */
    protected function outForDelivery(Order $order, ?User $courier = null): Order
    {
        $order->update([
            'status' => 'shipped', 'courier_id' => ($courier ?? $this->courier)->id,
            'tracking_status' => 'Out for delivery', 'handed_over_at' => now(),
        ]);
        return $order->fresh();
    }

    protected function deliver(Order $order, ?string $cash = null)
    {
        return $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", [
            'status' => 'completed', 'cash_collected' => $cash ?? \App\Support\Money::pesos($order->totalCents()),
        ]);
    }

    protected function remit(array $orders, ?User $as = null)
    {
        return $this->actingAs($as ?? $this->logistics)->post("/logistics/cash/riders/{$this->courier->id}/remit", [
            'order_ids' => collect($orders)->pluck('id')->all(),
        ]);
    }

    /** Placed → delivered with cash collected → cash handed in (paid). */
    protected function paidOrder(int $quantity = 1, array $extra = []): Order
    {
        $order = $this->outForDelivery($this->placeOrder($quantity, $extra));
        $this->deliver($order)->assertSessionHasNoErrors();
        $this->remit([$order])->assertSessionHasNoErrors();
        return $order->fresh();
    }

    protected function useWebGuard(): void
    {
        $this->app['auth']->forgetGuards();
        $this->app['auth']->shouldUse('web');
    }

    protected function asBuyerApi(): void
    {
        Sanctum::actingAs($this->buyer);
    }
}
