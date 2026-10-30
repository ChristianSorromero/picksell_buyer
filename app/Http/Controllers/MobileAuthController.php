<?php

namespace App\Http\Controllers;

use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use App\Services\AdminNotificationService;
use App\Services\EmailVerificationService;
use App\Support\LoginThrottle;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/**
 * Buyer sign-up, login and password reset for the app, following the website's registration
 * (AuthController): the email is proven with a one-time code first, then the account is created
 * with a valid ID and address and stays pending until an admin approves it on the website.
 */
class MobileAuthController extends Controller
{
    private const CODE_TTL_MINUTES = 5;
    private const RESEND_COOLDOWN_S = 60;
    // Guesses per email per hour across every code. Each new code resets the per-code count,
    // so without this cap a guesser would just keep asking for new codes.
    private const MAX_HOURLY_GUESSES = 15;
    // How long a verified email may be used to finish the sign-up form.
    private const VERIFIED_TTL_MINUTES = 30;

    public function __construct(private EmailVerificationService $verification) {}

    // ── Registration, step 1: prove the email ────────────────────────────

    /** POST /register/email-code {email, first_name?} */
    public function sendRegistrationCode(Request $request)
    {
        $request->merge(['email' => strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate(['email' => $this->emailRules(), 'first_name' => ['nullable', 'string', 'max:50']], $this->emailMessages());

        if (($wait = $this->verification->resendWaitSeconds($data['email'])) > 0) {
            return response()->json(['message' => "Please wait {$wait} seconds before requesting another code.", 'resend_in' => $wait], 429);
        }
        if (! $this->verification->send($data['email'], $data['first_name'] ?? null)) {
            return response()->json(['message' => 'The code could not be sent. Check the email address and try again.'], 503);
        }

        return response()->json([
            'message'      => 'We sent a 6-digit code to your email.',
            'masked_email' => $this->maskEmail($data['email']),
            'expires_in'   => EmailVerificationService::CODE_TTL_MINUTES * 60,
            'resend_in'    => EmailVerificationService::RESEND_COOLDOWN_SECONDS,
        ]);
    }

    /** POST /register/email-code/verify {email, code} → {registration_token} for the sign-up form. */
    public function verifyRegistrationCode(Request $request)
    {
        $request->merge([
            'email' => strtolower(trim((string) $request->input('email'))),
            'code' => preg_replace('/\s+/', '', (string) $request->input('code')),
        ]);
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'code' => ['required', 'regex:/^\d{6}$/'],
        ], ['code.required' => 'Enter the 6-digit code from the email.', 'code.regex' => 'The code must be exactly 6 digits.']);

        if (! $this->allowGuess('verify-email', $data['email'])) {
            return $this->codeError('Too many incorrect attempts. Please try again in an hour.');
        }

        $result = $this->verification->check($data['email'], $data['code']);
        if ($result !== 'verified') {
            $left = $this->verification->attemptsLeft($data['email']);

            return $this->codeError(match ($result) {
                'invalid' => "That code is incorrect. You have {$left} ".($left === 1 ? 'try' : 'tries').' left.',
                'expired' => 'This code has expired. Send a new code and try again.',
                'locked'  => 'Too many incorrect attempts. Send a new code and try again.',
                default   => 'Send a code to this email first.',
            });
        }

        RateLimiter::clear($this->guessKey('verify-email', $data['email']));
        $token = Str::random(48);
        Cache::put($this->verifiedKey($token), $data['email'], now()->addMinutes(self::VERIFIED_TTL_MINUTES));

        return response()->json([
            'verified'           => true,
            'message'            => 'Email verified.',
            'registration_token' => $token,
            'expires_in'         => self::VERIFIED_TTL_MINUTES * 60,
        ]);
    }

    /** POST /register/check-contact {email?, contact_no?} — lets the form flag a taken email or number early. */
    public function checkContact(Request $request)
    {
        $request->merge(array_filter(['email' => $request->has('email') ? strtolower(trim((string) $request->input('email'))) : null]));
        $request->validate([
            'email'      => ['sometimes', ...$this->emailRules()],
            'contact_no' => ['sometimes', 'regex:/^09\d{9}$/', Rule::unique('users', 'contact_no')],
        ], [...$this->emailMessages(), 'contact_no.regex' => 'Enter a valid PH mobile number (e.g. 09171234567).', 'contact_no.unique' => 'This mobile number is already in use.']);

        return response()->json(['message' => 'Available.']);
    }

    // ── Registration, step 2: create the pending account ─────────────────

    /** POST /register (multipart) — the website's buyer registration rules. */
    public function register(Request $request)
    {
        $request->merge([
            'email' => strtolower(trim((string) $request->input('email'))),
            'first_name' => Str::squish((string) $request->input('first_name')),
            'last_name' => Str::squish((string) $request->input('last_name')),
        ]);
        $verifiedEmail = Cache::get($this->verifiedKey((string) $request->input('registration_token')));
        $namePattern = "/^\\pL[\\pL\\s.'\\-]*$/u";

        $data = $request->validate([
            'registration_token' => ['required', 'string'],
            'first_name'     => ['required', 'string', 'min:2', 'max:50', "regex:{$namePattern}"],
            'last_name'      => ['required', 'string', 'min:2', 'max:50', "regex:{$namePattern}"],
            'middle_initial' => ['nullable', 'string', 'max:5', "regex:/^[\\pL.\\s]+$/u"],
            'sex'            => 'required|in:Male,Female',
            'email'          => [...$this->emailRules(), function (string $attribute, $value, $fail) use ($verifiedEmail): void {
                if ($verifiedEmail !== $value) {
                    $fail('Verify your email with the 6-digit code we send you before submitting.');
                }
            }],
            'password'       => ['required', 'confirmed', Password::min(8)->letters()->mixedCase()->numbers()->symbols()],
            'terms'          => 'accepted',
            'confirmed'      => 'accepted',
            'contact_no'     => ['required', 'regex:/^09\d{9}$/', Rule::unique('users', 'contact_no')],
            'birthday'       => ['required', 'date_format:Y-m-d', 'before_or_equal:-18 years', 'after:1900-01-01'],
            'province'       => 'required|string|max:100',
            'municipality'   => 'required|string|max:100',
            'barangay'       => 'required|string|max:100',
            'street'         => 'nullable|string|max:255',
            'house_no'       => 'nullable|string|max:100',
            'id_upload'      => 'required|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ], [
            ...$this->emailMessages(),
            'first_name.regex'         => 'The first name may only contain letters, spaces, hyphens (-), apostrophes (\') and periods.',
            'last_name.regex'          => 'The last name may only contain letters, spaces, hyphens (-), apostrophes (\') and periods.',
            'middle_initial.regex'     => 'The middle initial may only contain letters and periods.',
            'contact_no.regex'         => 'Enter a valid PH mobile number (e.g. 09171234567).',
            'contact_no.unique'        => 'This mobile number is already in use.',
            'birthday.before_or_equal' => 'You must be at least 18 years old to register.',
            'password.confirmed'       => 'The passwords do not match.',
            'terms.accepted'           => 'You must accept the Terms of Service and Privacy Policy to register.',
            'confirmed.accepted'       => 'Confirm that the information and documents you provided are accurate.',
            'id_upload.required'       => 'Upload a photo of a valid ID.',
        ]);

        // Stored where the website keeps IDs, so admins see it on the Registrations page.
        $idPath = $request->file('id_upload')->store('uploads/ids', 'public');
        $applicant = User::create([
            'role'           => 'buyer',
            'status'         => 'pending',
            'first_name'     => $data['first_name'],
            'last_name'      => $data['last_name'],
            'middle_initial' => $data['middle_initial'] ?? null,
            'sex'            => $data['sex'],
            'email'          => $data['email'],
            'password'       => Hash::make($data['password']),
            'contact_no'     => $data['contact_no'],
            'birthday'       => $data['birthday'],
            'age'            => Carbon::parse($data['birthday'])->age,
            'province'       => $data['province'],
            'municipality'   => $data['municipality'],
            'barangay'       => $data['barangay'],
            'street'         => $data['street'] ?? null,
            'house_no'       => $data['house_no'] ?? null,
            'id_upload'      => $idPath,
        ]);
        $applicant->forceFill(['email_verified_at' => now()])->save();
        Cache::forget($this->verifiedKey($data['registration_token']));

        app(AdminNotificationService::class)->notifyAdmins(
            'registration.pending',
            'Pending registration',
            "{$applicant->first_name} {$applicant->last_name} submitted a buyer registration.",
            "/admin/registrations/{$applicant->id}",
            subject: "registration:{$applicant->id}",
        );

        return response()->json([
            'status'  => 'pending',
            'message' => 'Registration submitted! Please wait for admin approval. You will be notified via email.',
        ], 201);
    }

    private function emailRules(): array
    {
        return ['required', 'string', 'max:255', 'email:rfc', 'regex:/^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$/', Rule::unique('users', 'email')];
    }

    private function emailMessages(): array
    {
        return [
            'email.email'  => 'Enter a valid email address, like name@example.com.',
            'email.regex'  => 'Enter a valid email address, like name@example.com.',
            'email.unique' => 'This email is already registered. Try logging in instead.',
        ];
    }

    private function verifiedKey(string $token): string
    {
        return 'mobile-registration-verified:'.sha1($token);
    }

    /** Counts one guess against the email's hourly cap; false once it is used up. */
    private function allowGuess(string $purpose, string $email): bool
    {
        return RateLimiter::hit($this->guessKey($purpose, $email), 3600) <= self::MAX_HOURLY_GUESSES;
    }

    private function guessKey(string $purpose, string $email): string
    {
        return "{$purpose}-guesses:".sha1(mb_strtolower($email));
    }

    private function codeError(string $message)
    {
        return response()->json(['message' => $message, 'errors' => ['code' => [$message]]], 422);
    }

    /** john.doe@gmail.com -> j***e@gmail.com */
    private function maskEmail(string $email): string
    {
        [$local, $domain] = explode('@', $email, 2);
        $masked = strlen($local) <= 2 ? $local[0].'***' : $local[0].'***'.substr($local, -1);

        return "{$masked}@{$domain}";
    }

    // ── Password reset (buyers) ──────────────────────────────────────────
    // The same answer is returned whether or not the email is registered,
    // so the endpoint can't be used to discover accounts.

    private const RESET_MAX_ATTEMPTS = 5;

    public function forgotPassword(Request $request)
    {
        $request->validate(['email' => 'required|email']);
        $email = mb_strtolower(trim($request->email));
        $generic = response()->json([
            'message'    => 'If a PickSell account uses that email, we sent it a six-digit code.',
            'expires_in' => self::CODE_TTL_MINUTES * 60,
            'resend_in'  => self::RESEND_COOLDOWN_S,
        ]);

        $user = User::whereRaw('LOWER(email) = ?', [$email])->where('role', 'buyer')->where('status', 'approved')->first();
        if (! $user) return $generic;

        $existing = DB::table('password_reset_tokens')->where('email', $user->email)->first();
        if ($existing && Carbon::parse($existing->created_at)->gt(now()->subSeconds(self::RESEND_COOLDOWN_S))) {
            return $generic; // cooldown: don't send again yet
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        DB::table('password_reset_tokens')->updateOrInsert(['email' => $user->email], ['token' => Hash::make($code), 'created_at' => now()]);
        RateLimiter::clear($this->resetAttemptsKey($user->email));
        Mail::to($user->email)->send(new PasswordResetCodeMail($user, $code, self::CODE_TTL_MINUTES));

        return $generic;
    }

    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'email'    => 'required|email',
            'code'     => 'required|digits:6',
            'password' => ['required', 'confirmed', Password::min(8)->letters()->mixedCase()->numbers()->symbols()],
        ], ['code.digits' => 'Enter the six-digit code from your email.']);

        $invalid = fn (string $message = 'The code is incorrect or has expired. Request a new one.') =>
            response()->json(['message' => $message, 'errors' => ['code' => [$message]]], 422);

        $user = User::whereRaw('LOWER(email) = ?', [mb_strtolower(trim($data['email']))])->where('role', 'buyer')
            ->where('status', 'approved')->first();
        $row = $user ? DB::table('password_reset_tokens')->where('email', $user->email)->first() : null;
        if (! $row || Carbon::parse($row->created_at)->lt(now()->subMinutes(self::CODE_TTL_MINUTES))) return $invalid();

        if (! $this->allowGuess('password-reset', $user->email)) {
            return $invalid('Too many incorrect attempts. Please try again in an hour.');
        }
        // Counted before the check (an atomic increment), so parallel
        // requests can't exceed the per-code limit.
        $attemptsKey = $this->resetAttemptsKey($user->email);
        if (RateLimiter::hit($attemptsKey, self::CODE_TTL_MINUTES * 60) > self::RESET_MAX_ATTEMPTS) {
            return $invalid('Too many incorrect attempts. Request a new code.');
        }
        if (! Hash::check($data['code'], $row->token)) {
            return $invalid();
        }

        DB::transaction(function () use ($user, $data) {
            $user->forceFill(['password' => Hash::make($data['password']), 'remember_token' => null])->save();
            $user->tokens()->delete(); // sign out every device
            DB::table('password_reset_tokens')->where('email', $user->email)->delete();
        });
        RateLimiter::clear($attemptsKey);
        RateLimiter::clear($this->guessKey('password-reset', $user->email));

        return response()->json(['message' => 'Your password was changed. Log in with your new password.']);
    }

    private function resetAttemptsKey(string $email): string
    {
        return 'password-reset-attempts:'.sha1(mb_strtolower($email));
    }

    // ── Login ────────────────────────────────────────────────────────────

    public function login(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        if ($wait = LoginThrottle::lockedFor($request->email)) {
            return response()->json(['message' => LoginThrottle::message($wait), 'retry_after' => $wait], 429);
        }

        $user = User::where('email', strtolower(trim($request->email)))->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            LoginThrottle::failed($request->email);

            return response()->json(['message' => 'Invalid email or password.'], 401);
        }
        LoginThrottle::succeeded($request->email);

        if ($user->role !== 'buyer') {
            return response()->json(['message' => 'This app is for buyers only.'], 403);
        }

        $refusal = match ($user->status) {
            'approved'    => null,
            'pending'     => 'Your account is still pending approval. Please check your email.',
            'disapproved' => 'Your registration was disapproved. Please contact support.',
            'suspended'   => 'Your account has been suspended. Please contact support.',
            default       => 'Your account is not active. Please contact support.',
        };
        if ($refusal) {
            return response()->json(['message' => $refusal, 'status' => $user->status], 403);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Login successful.',
            'token'   => $token,
            'user'    => ['id' => $user->id, 'name' => $user->full_name, 'email' => $user->email],
        ]);
    }
}
