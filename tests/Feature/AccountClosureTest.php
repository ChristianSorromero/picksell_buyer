<?php

namespace Tests\Feature;

use App\Models\BuyerAddress;
use App\Models\Order;
use App\Models\Product;
use App\Models\ReturnRequest;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class AccountClosureTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;
    private User $seller;
    private Product $mug;

    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
        $this->buyer = $this->user('buyer', 'buyer@test.ph');
        $this->seller = $this->user('seller', 'seller@test.ph', ['business_name' => 'Mug House']);
        $this->mug = Product::create([
            'seller_id' => $this->seller->id, 'name' => 'Ceramic Mug', 'price' => 300, 'stock' => 5, 'status' => 'active',
        ]);
    }

    private function user(string $role, string $email, array $extra = []): User
    {
        static $n = 0;
        $n++;
        return User::create($extra + [
            'role' => $role, 'status' => 'approved', 'first_name' => 'Test', 'last_name' => ucfirst($role),
            'email' => $email, 'password' => Hash::make('Password1!'), 'contact_no' => '0917300' . str_pad((string) $n, 4, '0', STR_PAD_LEFT),
            'birthday' => '1995-01-01', 'age' => 30, 'province' => 'Cebu', 'municipality' => 'Cebu City', 'barangay' => 'Lahug',
        ]);
    }

    private function order(string $status): Order
    {
        return Order::create([
            'order_number' => 'ORD-' . uniqid(), 'product_id' => $this->mug->id, 'buyer_id' => $this->buyer->id,
            'seller_id' => $this->seller->id, 'product_name' => 'Ceramic Mug', 'quantity' => 1,
            'amount' => 300, 'commission' => 30, 'status' => $status,
        ]);
    }

    private function closeAccount(User $user)
    {
        return $this->actingAs($user)->from('/account')->delete('/account', ['password' => 'Password1!']);
    }

    public function test_accounts_with_orders_in_progress_cannot_be_closed(): void
    {
        $this->order('processing');

        foreach ([$this->buyer, $this->seller] as $user) {
            $this->closeAccount($user)->assertRedirect('/account')->assertSessionHasErrors('account');
            $this->assertNull($user->fresh()->anonymized_at);
        }
    }

    public function test_an_open_return_blocks_closing_even_after_delivery(): void
    {
        $order = $this->order('completed');
        ReturnRequest::create([
            'order_id' => $order->id, 'buyer_id' => $this->buyer->id, 'quantity' => 1, 'reason' => 'Damaged item',
            'refund_amount' => 300, 'refund_to' => 'gcash', 'status' => 'under_review',
        ]);

        $this->closeAccount($this->seller)->assertSessionHasErrors('account');
        $this->closeAccount($this->buyer)->assertSessionHasErrors('account');
    }

    public function test_closing_a_buyer_account_erases_personal_data_but_keeps_order_history(): void
    {
        $order = $this->order('completed');
        BuyerAddress::create([
            'user_id' => $this->buyer->id, 'label' => 'home', 'recipient_name' => 'Test Buyer', 'phone' => '09171234567',
            'province' => 'Cebu', 'municipality' => 'Cebu City', 'barangay' => 'Lahug', 'street' => 'Gorordo Ave', 'is_default' => true,
        ]);
        $this->buyer->createToken('mobile');

        $this->closeAccount($this->buyer)->assertRedirect('/');
        $this->assertGuest();

        $closed = $this->buyer->fresh();
        $this->assertNotNull($closed->anonymized_at);
        $this->assertSame('deactivated', $closed->status);
        $this->assertSame('Deleted User', $closed->full_name);
        $this->assertSame("deleted-{$closed->id}@deleted.invalid", $closed->email);
        $this->assertNull($closed->street);
        $this->assertSame(0, $closed->tokens()->count());
        $this->assertSame(0, $closed->addresses()->count());

        // The seller still has the sale on record.
        $this->assertNotNull(Order::find($order->id));
        $this->assertSame(1, $this->seller->ordersAsSeller()->count());

        // Old credentials no longer work; the email can be used again.
        $this->post('/login', ['email' => 'buyer@test.ph', 'password' => 'Password1!'])->assertSessionHasErrors('email');
        $this->postJson('/api/login', ['email' => 'buyer@test.ph', 'password' => 'Password1!'])->assertUnauthorized();
        $this->postJson('/api/register/check-contact', ['email' => 'buyer@test.ph', 'contact_no' => '09179999999'])->assertOk();
    }

    public function test_closing_a_seller_account_takes_products_down_and_keeps_buyer_orders(): void
    {
        $order = $this->order('cancelled');

        $this->closeAccount($this->seller)->assertRedirect('/');

        $this->assertSame('archived', $this->mug->fresh()->status);
        $this->assertSame($this->seller->id, Order::find($order->id)->seller_id);
        $this->assertSame('Mug House', $this->seller->fresh()->business_name);
    }

    public function test_a_hard_delete_can_no_longer_erase_order_history(): void
    {
        $this->order('completed');

        $this->expectException(QueryException::class);
        $this->seller->delete();
    }

    public function test_admin_can_deactivate_but_not_revive_a_closed_account(): void
    {
        $admin = $this->user('admin', 'admin@test.ph');
        $other = $this->user('buyer', 'other@test.ph');

        $this->actingAs($admin)->patch("/admin/users/{$other->id}/status", ['status' => 'deactivated'])->assertSessionHasNoErrors();
        $this->assertSame('deactivated', $other->fresh()->status);

        $this->buyer->anonymize();
        $this->actingAs($admin)->patch("/admin/users/{$this->buyer->id}/status", ['status' => 'approved'])->assertSessionHasErrors('status');
        $this->assertSame('deactivated', $this->buyer->fresh()->status);
    }
}
