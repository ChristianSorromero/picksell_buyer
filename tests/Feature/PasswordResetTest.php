<?php

namespace Tests\Feature;

use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;

    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
        $this->buyer = User::create([
            'role' => 'buyer', 'status' => 'approved', 'first_name' => 'Ana', 'last_name' => 'Reyes',
            'email' => 'ana@test.ph', 'password' => Hash::make('OldPass1!'), 'contact_no' => '09171112222',
            'birthday' => '1995-01-01', 'age' => 30, 'email_verified_at' => now(),
        ]);
    }

    private function requestCode(string $email = 'ana@test.ph')
    {
        return $this->postJson('/api/password/forgot', ['email' => $email]);
    }

    private function sentCode(): string
    {
        $code = '';
        Mail::assertSent(PasswordResetCodeMail::class, function ($mail) use (&$code) { $code = $mail->code; return true; });
        return $code;
    }

    private function reset(string $code, string $password = 'NewPass1!')
    {
        return $this->postJson('/api/password/reset', ['email' => 'ana@test.ph', 'code' => $code, 'password' => $password, 'password_confirmation' => $password]);
    }

    public function test_the_answer_never_reveals_whether_an_account_exists(): void
    {
        $known = $this->requestCode()->assertOk()->json('message');
        $unknown = $this->requestCode('nobody@test.ph')->assertOk()->json('message');
        $this->assertSame($known, $unknown);
        Mail::assertSent(PasswordResetCodeMail::class, 1);

        // Sellers and admins reset through the website, not the buyer app.
        User::create(['role' => 'seller', 'status' => 'approved', 'first_name' => 'S', 'last_name' => 'S', 'email' => 'shop@test.ph',
            'password' => Hash::make('x'), 'contact_no' => '09179998888', 'birthday' => '1990-01-01', 'age' => 35]);
        $this->requestCode('shop@test.ph')->assertOk();
        Mail::assertSent(PasswordResetCodeMail::class, 1);
    }

    public function test_a_correct_code_changes_the_password_and_signs_out_every_device(): void
    {
        $this->buyer->createToken('phone');
        $this->buyer->createToken('tablet');
        $this->requestCode();
        $code = $this->sentCode();

        $this->reset($code, 'weak')->assertStatus(422)->assertJsonValidationErrors('password');
        $this->reset($code)->assertOk();

        $this->assertTrue(Hash::check('NewPass1!', $this->buyer->fresh()->password));
        $this->assertSame(0, $this->buyer->tokens()->count());
        $this->reset($code)->assertStatus(422); // single use
        $this->postJson('/api/login', ['email' => 'ana@test.ph', 'password' => 'OldPass1!'])->assertUnauthorized();
        $this->postJson('/api/login', ['email' => 'ana@test.ph', 'password' => 'NewPass1!'])->assertOk();
    }

    public function test_wrong_codes_are_limited_and_codes_expire(): void
    {
        $this->requestCode();
        $code = $this->sentCode();
        $wrong = $code === '000000' ? '111111' : '000000';

        for ($i = 0; $i < 5; $i++) $this->reset($wrong)->assertStatus(422);
        $this->reset($code)->assertStatus(422)->assertJsonPath('message', 'Too many incorrect attempts. Request a new code.');

        // A new code (after the cooldown) works, but not once it expires.
        $this->travel(2)->minutes();
        $this->requestCode();
        Mail::assertSent(PasswordResetCodeMail::class, 2);
        $this->travel(6)->minutes();
        $this->reset($this->latestCode())->assertStatus(422);
        $this->assertTrue(Hash::check('OldPass1!', $this->buyer->fresh()->password));
    }

    public function test_codes_are_not_resent_within_the_cooldown(): void
    {
        $this->requestCode();
        $this->requestCode();
        Mail::assertSent(PasswordResetCodeMail::class, 1);
    }

    public function test_the_website_reset_is_generic_and_rate_limited(): void
    {
        $this->post('/forgot-password', ['email' => 'nobody@test.ph'])->assertSessionHas('success', 'If an account uses that email, we sent it a password reset link.');
        for ($i = 0; $i < 10; $i++) {
            $this->post('/login', ['email' => 'ana@test.ph', 'password' => 'wrong']);
        }
        $this->post('/login', ['email' => 'ana@test.ph', 'password' => 'OldPass1!'])->assertStatus(429);
    }

    private function latestCode(): string
    {
        $codes = [];
        Mail::assertSent(PasswordResetCodeMail::class, function ($mail) use (&$codes) { $codes[] = $mail->code; return true; });
        return end($codes);
    }
}
