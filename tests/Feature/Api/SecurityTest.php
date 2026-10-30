<?php

namespace Tests\Feature\Api;

use App\Mail\PasswordResetCodeMail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Api\Concerns\BuildsMarketplace;
use Tests\TestCase;

class SecurityTest extends TestCase
{
    use BuildsMarketplace, RefreshDatabase;

    public function test_only_approved_buyers_use_the_buyer_api(): void
    {
        Sanctum::actingAs($this->seller());
        $this->getJson('/api/buyer/cart')->assertForbidden();

        $this->postJson('/api/login', ['email' => $this->admin()->email, 'password' => 'Password1!'])
            ->assertForbidden()->assertJsonPath('message', 'This app is for buyers only.');
    }

    public function test_an_admin_suspension_ends_the_app_session(): void
    {
        $buyer = $this->buyer();
        $token = $buyer->createToken('mobile')->plainTextToken;
        $buyer->update(['status' => 'suspended']);
        $this->withToken($token)->getJson('/api/buyer/profile')->assertUnauthorized();
        $this->assertSame(0, $buyer->tokens()->count());
    }

    public function test_login_failures_are_generic_and_logout_revokes_the_token(): void
    {
        $buyer = $this->buyer();
        $this->postJson('/api/login', ['email' => $buyer->email, 'password' => 'wrong'])->assertUnauthorized()->assertExactJson(['message' => 'Invalid email or password.']);
        $this->postJson('/api/login', ['email' => 'nobody@test.ph', 'password' => 'wrong'])->assertUnauthorized()->assertExactJson(['message' => 'Invalid email or password.']);

        $token = $this->postJson('/api/login', ['email' => $buyer->email, 'password' => 'Password1!'])->assertOk()->json('token');
        $this->withToken($token)->getJson('/api/buyer/profile')->assertOk()->assertJsonPath('user.email', $buyer->email);
        $this->withToken($token)->postJson('/api/buyer/logout')->assertOk();
        $this->assertSame(0, $buyer->tokens()->count());
    }

    public function test_an_account_locks_after_failures_from_many_ips(): void
    {
        $buyer = $this->buyer();
        for ($i = 0; $i < 10; $i++) {
            $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])
                ->postJson('/api/login', ['email' => strtoupper($buyer->email), 'password' => 'wrong'])->assertUnauthorized();
        }
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.1.1'])
            ->postJson('/api/login', ['email' => $buyer->email, 'password' => 'Password1!'])
            ->assertStatus(429)->assertJsonPath('message', 'Too many failed sign-in attempts. Try again in 15 minutes.');

        $this->travel(16)->minutes();
        $this->postJson('/api/login', ['email' => $buyer->email, 'password' => 'Password1!'])->assertOk();
    }

    public function test_password_reset_codes_cannot_be_brute_forced(): void
    {
        Mail::fake();
        $buyer = $this->buyer();
        $codes = function () {
            $all = [];
            Mail::assertSent(PasswordResetCodeMail::class, function ($mail) use (&$all) { $all[] = $mail->code; return true; });

            return $all;
        };
        $reset = fn (string $code, string $ip) => $this->withServerVariables(['REMOTE_ADDR' => $ip])->postJson('/api/password/reset', [
            'email' => $buyer->email, 'code' => $code, 'password' => 'NewPass1!x', 'password_confirmation' => 'NewPass1!x',
        ]);

        // Unknown accounts get the same answer and no email.
        $this->assertSame(
            $this->postJson('/api/password/forgot', ['email' => 'nobody@test.ph'])->json('message'),
            $this->postJson('/api/password/forgot', ['email' => $buyer->email])->json('message'),
        );
        for ($round = 0; $round < 3; $round++) {
            if ($round > 0) {
                $this->travel(61)->seconds();
                $this->postJson('/api/password/forgot', ['email' => $buyer->email]);
            }
            $code = last($codes());
            for ($i = 0; $i < 5; $i++) $reset($code === '000000' ? '111111' : '000000', "10.{$round}.0.{$i}")->assertUnprocessable();
        }
        $this->travel(61)->seconds();
        $this->postJson('/api/password/forgot', ['email' => $buyer->email]);
        $reset(last($codes()), '10.9.9.9')->assertUnprocessable()->assertJsonPath('message', 'Too many incorrect attempts. Please try again in an hour.');
        $this->assertTrue(Hash::check('Password1!', $buyer->fresh()->password));

        $this->travel(61)->minutes();
        $this->postJson('/api/password/forgot', ['email' => $buyer->email]);
        $buyer->createToken('phone');
        $reset(last($codes()), '10.9.9.10')->assertOk();
        $this->assertTrue(Hash::check('NewPass1!x', $buyer->fresh()->password));
        $this->assertSame(0, $buyer->tokens()->count());
    }

    public function test_the_profile_cannot_change_email_or_role(): void
    {
        $buyer = $this->actingAsBuyer();
        $this->patchJson('/api/buyer/profile', [
            'first_name' => 'Ana', 'last_name' => 'Cruz', 'birthday' => '1995-01-01', 'contact_no' => '09175550000',
            'province' => 'Cebu', 'municipality' => 'Mandaue City', 'barangay' => 'Banilad',
            'email' => 'attacker@test.ph', 'role' => 'admin', 'status' => 'approved',
        ])->assertOk();

        $fresh = $buyer->fresh();
        $this->assertSame(['Ana', 'Mandaue City', $buyer->email, 'buyer'], [$fresh->first_name, $fresh->municipality, $fresh->email, $fresh->role]);
    }

    public function test_old_web_pages_and_endpoints_are_gone(): void
    {
        $this->get('/buyer/shop')->assertNotFound();
        $this->get('/admin/dashboard')->assertNotFound();
        $this->actingAsBuyer();
        $this->postJson('/api/buyer/addresses', [])->assertNotFound();
        $this->getJson('/api/buyer/vouchers')->assertNotFound();
    }
}
