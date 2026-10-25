<?php

namespace Tests\Feature\Api;

use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SecurityTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $role, string $email, array $extra = []): User
    {
        static $n = 0;
        $n++;
        return User::create($extra + [
            'role' => $role, 'status' => 'approved', 'first_name' => 'Test', 'last_name' => ucfirst($role),
            'email' => $email, 'password' => Hash::make('Password1!'), 'contact_no' => '0917000' . str_pad((string) $n, 4, '0', STR_PAD_LEFT),
            'birthday' => '1995-01-01', 'age' => 30,
        ]);
    }

    public function test_non_buyers_cannot_use_the_buyer_api(): void
    {
        Sanctum::actingAs($this->user('seller', 'seller@test.ph'));
        $this->getJson('/api/buyer/cart')->assertForbidden();
        $this->getJson('/api/buyer/profile')->assertForbidden();
    }

    public function test_suspended_buyer_is_locked_out_and_token_revoked(): void
    {
        $buyer = $this->user('buyer', 'buyer@test.ph');
        $token = $buyer->createToken('mobile')->plainTextToken;
        $buyer->update(['status' => 'suspended']);

        $this->withToken($token)->getJson('/api/buyer/profile')->assertUnauthorized()
            ->assertJsonPath('message', 'Your account has been suspended. Please contact support.');
        $this->assertSame(0, $buyer->tokens()->count());
    }

    public function test_login_failures_are_generic_and_logout_revokes_the_token(): void
    {
        $buyer = $this->user('buyer', 'buyer@test.ph');

        // Wrong password and unknown email must be indistinguishable.
        $this->postJson('/api/login', ['email' => 'buyer@test.ph', 'password' => 'wrong'])
            ->assertUnauthorized()->assertExactJson(['message' => 'Invalid email or password.']);
        $this->postJson('/api/login', ['email' => 'nobody@test.ph', 'password' => 'wrong'])
            ->assertUnauthorized()->assertExactJson(['message' => 'Invalid email or password.']);
        $this->postJson('/api/login', [])->assertUnprocessable()->assertJsonValidationErrors(['email', 'password']);
        $this->getJson('/api/buyer/profile')->assertUnauthorized();

        $token = $this->postJson('/api/login', ['email' => 'buyer@test.ph', 'password' => 'Password1!'])
            ->assertOk()->assertJsonPath('user.id', $buyer->id)->json('token');
        $other = $buyer->createToken('mobile')->plainTextToken; // e.g. a second device

        $this->withToken($token)->getJson('/api/buyer/profile')->assertOk();
        $this->withToken($token)->postJson('/api/buyer/logout')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/buyer/profile')->assertUnauthorized();
        $this->withToken($other)->getJson('/api/buyer/profile')->assertOk();
        $this->assertSame(1, $buyer->tokens()->count());
    }

    public function test_legacy_unauthenticated_id_upload_endpoint_is_gone(): void
    {
        $victim = $this->user('buyer', 'victim@test.ph');
        $this->postJson('/api/upload-id', [
            'user_id' => $victim->id,
            'id_file' => UploadedFile::fake()->image('x.jpg'),
        ])->assertNotFound();
    }

    public function test_identity_documents_are_private_and_access_controlled(): void
    {
        Storage::fake('local');
        Storage::disk('local')->put('uploads/ids/abc.jpg', 'secret-id');
        $seller = $this->user('seller', 'seller@test.ph', ['id_upload' => 'uploads/ids/abc.jpg']);
        $stranger = $this->user('seller', 'other@test.ph');
        $admin = $this->user('admin', 'admin@test.ph');

        // Not reachable through the public storage URL.
        $this->assertContains($this->get('/storage/uploads/ids/abc.jpg')->status(), [403, 404]);
        $this->actingAs($stranger)->get("/documents/users/{$seller->id}/id")->assertForbidden();
        $this->actingAs($admin)->get("/documents/users/{$seller->id}/id")->assertOk();
        $this->actingAs($seller)->get("/documents/users/{$seller->id}/id")->assertOk();
    }

    public function test_login_is_rate_limited(): void
    {
        $this->user('buyer', 'buyer@test.ph');
        for ($i = 0; $i < 10; $i++) {
            $this->postJson('/api/login', ['email' => 'buyer@test.ph', 'password' => 'wrong'])->assertUnauthorized();
        }
        $this->postJson('/api/login', ['email' => 'buyer@test.ph', 'password' => 'wrong'])->assertStatus(429);
    }

    public function test_buyers_cannot_touch_each_others_data(): void
    {
        $seller = $this->user('seller', 'seller@test.ph');
        $owner = $this->user('buyer', 'owner@test.ph');
        $intruder = $this->user('buyer', 'intruder@test.ph');
        $product = Product::create(['seller_id' => $seller->id, 'name' => 'Mug', 'price' => 100, 'stock' => 5, 'status' => 'active']);

        Sanctum::actingAs($owner);
        $itemId = $this->postJson('/api/buyer/cart', ['product_id' => $product->id, 'quantity' => 1])->json('cart_item_id');
        $addressId = $this->postJson('/api/buyer/addresses', [
            'label' => 'home', 'recipient_name' => 'Owner', 'phone' => '09171234567', 'province' => 'Cebu',
            'municipality' => 'Cebu City', 'barangay' => 'Lahug', 'street' => 'Gorordo',
        ])->json('address.id');
        $order = Order::create([
            'order_number' => 'PS-1', 'buyer_id' => $owner->id, 'seller_id' => $seller->id,
            'product_name' => 'Mug', 'amount' => 100, 'commission' => 10,
        ]);

        Sanctum::actingAs($intruder);
        $this->patchJson("/api/buyer/cart/{$itemId}", ['quantity' => 2])->assertNotFound();
        $this->deleteJson("/api/buyer/cart/{$itemId}")->assertNotFound();
        $this->patchJson("/api/buyer/addresses/{$addressId}", ['street' => 'Hacked'])->assertNotFound();
        $this->getJson("/api/buyer/orders/{$order->id}")->assertNotFound();
        $this->postJson("/api/buyer/orders/{$order->id}/cancel", ['reason' => 'x'])->assertNotFound();
        // Checkout with someone else's cart line / address places nothing.
        $this->postJson('/api/buyer/checkout', ['item_ids' => [$itemId], 'address_id' => $addressId, 'payment_method' => 'cod'])
            ->assertStatus(422);
        $this->assertSame(1, Order::count());
    }

    public function test_prices_cannot_be_set_by_the_client(): void
    {
        $seller = $this->user('seller', 'seller@test.ph');
        $buyer = $this->user('buyer', 'buyer@test.ph');
        $product = Product::create(['seller_id' => $seller->id, 'name' => 'Lamp', 'price' => 850, 'stock' => 5, 'status' => 'active']);
        Sanctum::actingAs($buyer);

        $id = $this->postJson('/api/buyer/cart', ['product_id' => $product->id, 'quantity' => 1, 'price' => 1, 'unit_price' => 1])
            ->json('cart_item_id');
        $this->getJson('/api/buyer/cart')->assertJsonPath('cart.groups.0.items.0.unit_price', 850);
        $this->assertNotNull($id);
    }

    public function test_evidence_uploads_reject_non_images(): void
    {
        $seller = $this->user('seller', 'seller@test.ph');
        $buyer = $this->user('buyer', 'buyer@test.ph');
        $order = Order::create([
            'order_number' => 'PS-2', 'buyer_id' => $buyer->id, 'seller_id' => $seller->id,
            'product_name' => 'Mug', 'amount' => 100, 'commission' => 10, 'status' => 'processing',
        ]);
        Sanctum::actingAs($buyer);

        $this->post("/api/buyer/orders/{$order->id}/report", [
            'category' => 'Damaged Item',
            'details'  => 'Arrived broken into pieces.',
            'evidence' => [UploadedFile::fake()->create('shell.php', 10, 'application/x-php')],
        ], ['Accept' => 'application/json'])->assertStatus(422)->assertJsonValidationErrors('evidence.0');
    }
}
