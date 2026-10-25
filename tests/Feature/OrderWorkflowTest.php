<?php

namespace Tests\Feature;

use App\Models\BuyerAddress;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * The order lifecycle across roles: buyer app → seller → sorting center
 * → rider → buyer, with each web action allowed only from its step.
 */
class OrderWorkflowTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;
    private User $seller;
    private User $logistics;
    private User $courier;
    private User $admin;
    private Product $mug;

    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
        // App sign-ups have no profile address; delivery comes from checkout.
        $this->buyer = $this->user('buyer', 'buyer@test.ph', ['email_verified_at' => now()]);
        $this->seller = $this->user('seller', 'seller@test.ph', ['business_name' => 'Shop']);
        $this->logistics = $this->user('logistics', 'logistics@test.ph', ['delivery_area' => 'Metro Manila', 'provider_type' => 'company']);
        $this->courier = $this->user('courier', 'rider@test.ph', ['delivery_area' => 'Quezon City', 'vehicle_type' => 'Motorcycle']);
        $this->admin = $this->user('admin', 'admin@test.ph');
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
            'email' => $email, 'password' => Hash::make('Password1!'), 'contact_no' => '0917200' . str_pad((string) $n, 4, '0', STR_PAD_LEFT),
            'birthday' => '1995-01-01', 'age' => 30,
        ]);
    }

    private function placeOrder(int $quantity = 1): Order
    {
        Sanctum::actingAs($this->buyer);
        $address = BuyerAddress::create([
            'user_id' => $this->buyer->id, 'label' => 'home', 'recipient_name' => 'Ana Reyes', 'phone' => '09171234567',
            'province' => 'Metro Manila', 'municipality' => 'Quezon City', 'barangay' => 'Diliman',
            'street' => 'Katipunan Ave', 'house_no' => '12', 'landmark' => 'Blue gate', 'is_default' => true,
        ]);
        $item = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => $quantity])->json('cart_item_id');
        $this->postJson('/api/buyer/checkout', [
            'item_ids' => [$item], 'address_id' => $address->id, 'payment_method' => 'cod', 'shipping_option' => 'standard',
        ])->assertCreated();

        // Back to session auth for the web dashboards.
        $this->app['auth']->forgetGuards();
        $this->app['auth']->shouldUse('web');

        return Order::latest('id')->first();
    }

    private function state(Order $order): string
    {
        return $order->fresh()->canonical_status;
    }

    public function test_an_order_moves_through_every_role_to_completion(): void
    {
        $order = $this->placeOrder();

        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/pack")->assertRedirect();
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/handover", ['waybill_number' => 'WB-1'])->assertRedirect();
        $this->assertSame('picked_up', $this->state($order));

        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/scan")->assertRedirect();
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertRedirect();
        $this->assertSame('assigned_to_rider', $this->state($order));
        $this->assertSame('Sorted for Quezon City, Metro Manila; assigned to Test Courier', $order->fresh()->tracking_status);

        $this->actingAs($this->courier)->get('/courier/orders')->assertOk()->assertSee('Out for Delivery')->assertDontSee('Mark Delivered');
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertRedirect();
        $this->assertSame('out_for_delivery', $this->state($order));
        $this->actingAs($this->courier)->get('/courier/orders')->assertOk()->assertSee('Mark Delivered');
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '345.00', 'recipient_name' => 'Ana Reyes'])->assertRedirect();
        $this->assertSame('delivered', $this->state($order));
        $this->assertSame('collected', $order->fresh()->payment_status); // paid only once the cash is handed in

        Sanctum::actingAs($this->buyer);
        $this->postJson("/api/buyer/orders/{$order->id}/rate", ['rating' => 5])->assertOk();
        $this->assertSame('completed', $this->state($order));
    }

    public function test_seller_cannot_revive_a_cancelled_order(): void
    {
        $order = $this->placeOrder(2);
        Sanctum::actingAs($this->buyer);
        $this->postJson("/api/buyer/orders/{$order->id}/cancel", ['reason' => 'Changed my mind'])->assertOk();
        $this->app['auth']->forgetGuards();
        $this->app['auth']->shouldUse('web');

        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/pack")->assertStatus(422);
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/handover", ['waybill_number' => 'WB-1'])->assertStatus(422);
        $this->assertSame('cancelled', $this->state($order));
        $this->assertSame(5, $this->mug->fresh()->stock);
    }

    public function test_steps_cannot_be_skipped_or_reversed(): void
    {
        $order = $this->placeOrder();

        // Seller: handover needs packing first.
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/handover", ['waybill_number' => 'WB-1'])->assertStatus(422);
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/pack")->assertRedirect();
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/pack")->assertStatus(422);

        // Sorting center: nothing before handover; assign needs a scan.
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/scan")->assertStatus(422);
        $this->actingAs($this->admin)->patch("/admin/logistics/orders/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/handover", ['waybill_number' => 'WB-1'])->assertRedirect();
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/scan")->assertRedirect();
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/scan")->assertStatus(422);
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertRedirect();

        // Rider: no delivering before setting out, no going backwards.
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '345.00', 'recipient_name' => 'Ana Reyes'])->assertStatus(422);
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertRedirect();
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '345.00', 'recipient_name' => 'Ana Reyes'])->assertRedirect();
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertStatus(422);
        $this->assertSame('delivered', $this->state($order));
    }

    public function test_checkout_address_reaches_seller_sorting_center_and_rider(): void
    {
        $order = $this->placeOrder();

        $this->actingAs($this->seller)->get("/seller/orders/{$order->id}")->assertOk()
            ->assertSee('Ana Reyes')->assertSee('Katipunan Ave')->assertSee('09171234567')->assertSee('Blue gate');

        $order->update(['status' => 'shipped', 'tracking_status' => 'Handed over to courier']);
        $this->actingAs($this->logistics)->get('/logistics/parcels')->assertOk()
            ->assertSee('Quezon City, Metro Manila')->assertSee('Katipunan Ave');
        $this->actingAs($this->admin)->get('/admin/logistics')->assertOk()->assertSee('Katipunan Ave');

        $order->update(['courier_id' => $this->courier->id, 'tracking_status' => 'Sorted for QC; assigned to Test Courier']);
        $this->actingAs($this->courier)->get('/courier/orders')->assertOk()
            ->assertSee('Ana Reyes')->assertSee('Katipunan Ave')->assertSee('09171234567');
    }

    public function test_unrouted_parcels_reach_the_provider_and_other_providers_are_refused(): void
    {
        $order = $this->placeOrder();
        $order->update(['logistics_id' => null, 'status' => 'shipped', 'tracking_status' => 'Handed over to courier']);

        $this->actingAs($this->logistics)->get('/logistics/parcels')->assertOk()->assertSee($order->order_number);
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/scan")->assertRedirect();
        $this->assertSame($this->logistics->id, $order->fresh()->logistics_id);

        $other = $this->user('logistics', 'other-logistics@test.ph', ['delivery_area' => 'Davao', 'provider_type' => 'company']);
        $this->actingAs($other)->get('/logistics/parcels')->assertOk()
            ->assertViewHas('orders', fn ($orders) => !$orders->contains('id', $order->id));
        $this->actingAs($other)->patch("/logistics/parcels/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertForbidden();
        $this->assertNull($order->fresh()->courier_id);
    }

    public function test_orders_without_a_checkout_address_fall_back_to_the_buyer_profile(): void
    {
        $webBuyer = $this->user('buyer', 'web@test.ph', [
            'province' => 'Cebu', 'municipality' => 'Cebu City', 'barangay' => 'Lahug', 'street' => 'Gorordo Ave',
        ]);
        $order = Order::create([
            'order_number' => 'ORD-LEGACY1', 'product_id' => $this->mug->id, 'buyer_id' => $webBuyer->id,
            'seller_id' => $this->seller->id, 'product_name' => 'Ceramic Mug', 'quantity' => 1,
            'amount' => 300, 'commission' => 30, 'status' => 'pending',
        ]);

        $this->assertSame('Cebu City, Cebu', $order->delivery['area']);
        $this->assertSame('Gorordo Ave, Lahug, Cebu City, Cebu', $order->delivery['address']);
        $this->actingAs($this->seller)->get("/seller/orders/{$order->id}")->assertOk()->assertSee('Gorordo Ave');
    }
}
