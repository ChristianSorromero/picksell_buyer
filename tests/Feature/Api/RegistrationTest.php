<?php

namespace Tests\Feature\Api;

use App\Mail\EmailVerificationCodeMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Tests\Feature\Api\Concerns\BuildsMarketplace;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use BuildsMarketplace, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
        Storage::fake('public');
    }

    private function latestCode(): string
    {
        $codes = [];
        Mail::assertSent(EmailVerificationCodeMail::class, function ($mail) use (&$codes) { $codes[] = $mail->code; return true; });

        return end($codes);
    }

    private function verifiedToken(string $email = 'ana@test.ph'): string
    {
        $this->postJson('/api/register/email-code', ['email' => $email, 'first_name' => 'Ana'])->assertOk();

        return $this->postJson('/api/register/email-code/verify', ['email' => $email, 'code' => $this->latestCode()])
            ->assertOk()->json('registration_token');
    }

    private function form(array $overrides = []): array
    {
        return $overrides + [
            'first_name' => 'Ana', 'last_name' => 'Reyes', 'sex' => 'Female', 'email' => 'ana@test.ph',
            'password' => 'Secret1!x', 'password_confirmation' => 'Secret1!x', 'contact_no' => '09171112222',
            'birthday' => '1995-01-01', 'province' => 'Cebu', 'municipality' => 'City of Cebu', 'barangay' => 'Lahug',
            'street' => 'Gorordo Ave', 'terms' => '1', 'confirmed' => '1',
            'id_upload' => UploadedFile::fake()->image('id.jpg'),
        ];
    }

    public function test_a_verified_email_registers_a_pending_buyer_like_the_website(): void
    {
        $admin = $this->admin();
        DB::table('geo_provinces')->insert(['code' => '072200000', 'region_code' => '070000000', 'name' => 'Cebu', 'kind' => 'province']);
        DB::table('geo_municipalities')->insert(['code' => '072217000', 'province_code' => '072200000', 'region_code' => '070000000', 'name' => 'Cebu City', 'is_city' => 1, 'is_capital' => 1]);
        DB::table('geo_barangays')->insert(['code' => '072217050', 'municipality_code' => '072217000', 'name' => 'Lahug']);

        $token = $this->verifiedToken();
        $this->post('/api/register', $this->form(['registration_token' => $token]), ['Accept' => 'application/json'])
            ->assertCreated()->assertJsonPath('status', 'pending');

        $buyer = User::firstWhere('email', 'ana@test.ph');
        $this->assertSame(['buyer', 'pending'], [$buyer->role, $buyer->status]);
        $this->assertNotNull($buyer->email_verified_at);
        // The ID is where the website's admin Registrations page reads it.
        $this->assertStringStartsWith('uploads/ids/', $buyer->id_upload);
        Storage::disk('public')->assertExists($buyer->id_upload);
        // Address codes resolved the website's way (spelling variants included) for Pickrush routing.
        $this->assertSame(['072200000', '072217000', '072217050'], [$buyer->province_code, $buyer->municipality_code, $buyer->barangay_code]);
        // Admins get the same "Pending registration" alert as for a website sign-up.
        $alert = $admin->notifications()->first();
        $this->assertSame('App\\Notifications\\AdminActivity', $alert->type);
        $this->assertSame('/admin/registrations/'.$buyer->id, $alert->data['url']);

        // Pending accounts cannot sign in until an admin approves them on the website.
        $this->postJson('/api/login', ['email' => 'ana@test.ph', 'password' => 'Secret1!x'])
            ->assertForbidden()->assertJsonPath('status', 'pending');
        $buyer->update(['status' => 'approved']);
        $this->postJson('/api/login', ['email' => 'ana@test.ph', 'password' => 'Secret1!x'])->assertOk()->assertJsonStructure(['token']);
    }

    public function test_registration_needs_the_code_for_that_exact_email_and_an_id(): void
    {
        $this->post('/api/register', $this->form(['registration_token' => 'made-up']), ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');

        $token = $this->verifiedToken('someone-else@test.ph');
        $this->post('/api/register', $this->form(['registration_token' => $token]), ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');

        $token = $this->verifiedToken();
        $this->post('/api/register', $this->form(['registration_token' => $token, 'id_upload' => null]), ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('id_upload');
        $this->post('/api/register', $this->form(['registration_token' => $token, 'birthday' => now()->subYears(17)->toDateString()]), ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('birthday');
        $this->assertSame(0, User::count());

        // A token is single use.
        $this->post('/api/register', $this->form(['registration_token' => $token]), ['Accept' => 'application/json'])->assertCreated();
        $this->post('/api/register', $this->form(['registration_token' => $token, 'email' => 'ana@test.ph', 'contact_no' => '09179998888']), ['Accept' => 'application/json'])
            ->assertUnprocessable();
    }

    public function test_taken_emails_and_numbers_are_refused_before_a_code_is_sent(): void
    {
        $this->buyer(['email' => 'taken@test.ph', 'contact_no' => '09170000001']);

        $this->postJson('/api/register/email-code', ['email' => 'Taken@test.ph'])->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->postJson('/api/register/check-contact', ['contact_no' => '09170000001'])->assertUnprocessable()->assertJsonValidationErrors('contact_no');
        $this->postJson('/api/register/check-contact', ['email' => 'free@test.ph', 'contact_no' => '09170000002'])->assertOk();
        Mail::assertNothingSent();
    }

    public function test_wrong_codes_are_limited_per_code_and_per_hour(): void
    {
        $this->postJson('/api/register/email-code', ['email' => 'ana@test.ph'])->assertOk();
        $code = $this->latestCode();
        $wrong = $code === '000000' ? '111111' : '000000';

        for ($i = 0; $i < 5; $i++) {
            $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])->postJson('/api/register/email-code/verify', ['email' => 'ana@test.ph', 'code' => $wrong])->assertUnprocessable();
        }
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.1.1'])->postJson('/api/register/email-code/verify', ['email' => 'ana@test.ph', 'code' => $code])
            ->assertUnprocessable()->assertJsonPath('message', 'Too many incorrect attempts. Send a new code and try again.');

        // New codes don't give a guesser a fresh hour.
        for ($round = 0; $round < 2; $round++) {
            $this->travel(61)->seconds();
            $this->postJson('/api/register/email-code', ['email' => 'ana@test.ph'])->assertOk();
            $code = $this->latestCode();
            for ($i = 0; $i < 5; $i++) {
                $this->withServerVariables(['REMOTE_ADDR' => "10.1.{$round}.{$i}"])->postJson('/api/register/email-code/verify', ['email' => 'ana@test.ph', 'code' => $code === '000000' ? '111111' : '000000']);
            }
        }
        $this->travel(61)->seconds();
        $this->postJson('/api/register/email-code', ['email' => 'ana@test.ph'])->assertOk();
        $this->withServerVariables(['REMOTE_ADDR' => '10.9.9.9'])->postJson('/api/register/email-code/verify', ['email' => 'ana@test.ph', 'code' => $this->latestCode()])
            ->assertUnprocessable()->assertJsonPath('message', 'Too many incorrect attempts. Please try again in an hour.');
    }
}
