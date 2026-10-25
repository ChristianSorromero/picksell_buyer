<?php

namespace App\Http\Controllers;

use App\Mail\BuyerVerificationCodeMail;
use App\Models\User;
use App\Models\Product;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class MobileAuthController extends Controller
{
    public function products(Request $request)
    {
        $query = Product::where('status', 'active')
            ->where('stock', '>', 0)
            ->with('seller');

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        if ($request->filled('search')) {
            $query->where('name', 'like', '%' . $request->search . '%');
        }

        $products = $query->latest()->get()->map(fn($p) => [
            'id'             => $p->id,
            'name'           => $p->name,
            'description'    => $p->description ?? '',
            'category'       => $p->category ?? '',
            'price'          => (float) $p->effective_price,
            'original_price' => $p->discount > 0 ? (float) $p->price : null,
            'stock'          => $p->stock,
            'seller_name'    => $p->seller?->business_name ?? $p->seller?->full_name ?? '',
            'seller_location'=> trim(($p->seller?->municipality ?? '') . ', ' . ($p->seller?->province ?? ''), ', '),
            'image'          => $p->image ? url('storage/' . $p->image) : null,
        ]);

        return response()->json(['products' => $products]);
    }

    // ── Buyer registration ───────────────────────────────────────────────
    // Step 1-3 in the app collect name/DOB, email/mobile, password/consent.
    // The account stays pending until the emailed 6-digit code is verified,
    // at which point the buyer is approved and logged in.

    private const CODE_TTL_MINUTES   = 5;
    private const RESEND_COOLDOWN_S  = 60;
    private const MAX_CODE_ATTEMPTS  = 5;

    /** Step 2: lets the app flag a taken email/mobile before step 3. */
    public function checkContact(Request $request)
    {
        $request->validate($this->contactRules(), $this->registrationMessages());

        return response()->json(['message' => 'Email and mobile number are available.']);
    }

    public function register(Request $request)
    {
        $data = $request->validate([
            'first_name' => ['required', 'string', 'max:100', "regex:/^[\pL\s.'-]+$/u"],
            'last_name'  => ['required', 'string', 'max:100', "regex:/^[\pL\s.'-]+$/u"],
            'birthday'   => ['required', 'date_format:Y-m-d', 'after:1900-01-01', 'before_or_equal:-18 years'],
            ...$this->contactRules(),
            'password'   => ['required', 'confirmed', Password::min(8)->mixedCase()->numbers()->symbols()],
            'terms'      => ['accepted'],
        ], $this->registrationMessages());

        $user = DB::transaction(function () use ($data) {
            // An earlier sign-up that was never verified must not block a retry.
            $this->unverifiedBuyers()
                ->where(fn ($q) => $q->where('email', $data['email'])->orWhere('contact_no', $data['contact_no']))
                ->delete();

            $user = User::create([
                'role'       => 'buyer',
                'status'     => 'pending',
                'first_name' => $data['first_name'],
                'last_name'  => $data['last_name'],
                'email'      => $data['email'],
                'password'   => Hash::make($data['password']),
                'contact_no' => $data['contact_no'],
                'birthday'   => $data['birthday'],
                'age'        => Carbon::parse($data['birthday'])->age,
            ]);
            $user->forceFill(['terms_accepted_at' => now()])->save();

            return $user;
        });

        $this->sendVerificationCode($user);

        return response()->json([
            'message'      => 'We sent a six-digit verification code to your email.',
            'email'        => $user->email,
            'masked_email' => $this->maskEmail($user->email),
            'expires_in'   => self::CODE_TTL_MINUTES * 60,
            'resend_in'    => self::RESEND_COOLDOWN_S,
        ], 201);
    }

    public function verifyEmail(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'code'  => 'required|digits:6',
        ], ['code.digits' => 'Enter the six-digit code from your email.']);

        $user = $this->unverifiedBuyers()->where('email', $request->email)->first();

        if (!$user) {
            return $this->codeError('This verification request is no longer valid. Please register again or log in.');
        }
        if ($user->email_verification_attempts >= self::MAX_CODE_ATTEMPTS) {
            return $this->codeError('Too many incorrect attempts. Tap Resend Code to get a new code.');
        }
        if ($user->email_verification_expires_at->isPast()) {
            return $this->codeError('This code has expired. Tap Resend Code to get a new one.');
        }
        if (!Hash::check($request->code, $user->email_verification_code)) {
            $user->increment('email_verification_attempts');
            return $this->codeError('The code is incorrect. Check your email and try again.');
        }

        $user->forceFill([
            'status'                        => 'approved',
            'email_verified_at'             => now(),
            'email_verification_code'       => null,
            'email_verification_expires_at' => null,
            'email_verification_attempts'   => 0,
        ])->save();

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Your email is verified. Welcome to PickSell!',
            'token'   => $token,
            'user'    => ['id' => $user->id, 'name' => $user->full_name, 'email' => $user->email],
        ]);
    }

    public function resendCode(Request $request)
    {
        $request->validate(['email' => 'required|email']);

        $user = $this->unverifiedBuyers()->where('email', $request->email)->first();

        if (!$user) {
            return $this->codeError('This verification request is no longer valid. Please register again or log in.');
        }

        $wait = self::RESEND_COOLDOWN_S - (int) $user->email_verification_sent_at->diffInSeconds(now());
        if ($wait > 0) {
            return response()->json([
                'message'   => "Please wait {$wait} seconds before requesting a new code.",
                'resend_in' => $wait,
            ], 429);
        }

        $this->sendVerificationCode($user);

        return response()->json([
            'message'    => 'A new code has been sent to your email.',
            'expires_in' => self::CODE_TTL_MINUTES * 60,
            'resend_in'  => self::RESEND_COOLDOWN_S,
        ]);
    }

    private function contactRules(): array
    {
        return [
            'email'      => ['required', 'email:rfc', 'max:255', $this->uniqueAmongActiveUsers('email')],
            'contact_no' => ['required', 'regex:/^09\d{9}$/', $this->uniqueAmongActiveUsers('contact_no')],
        ];
    }

    private function registrationMessages(): array
    {
        return [
            'first_name.regex'         => 'Use letters, spaces, hyphens or apostrophes only.',
            'last_name.regex'          => 'Use letters, spaces, hyphens or apostrophes only.',
            'birthday.before_or_equal' => 'You must be at least 18 years old to register.',
            'email.unique'             => 'This email is already registered. Try logging in instead.',
            'contact_no.regex'         => 'Enter a valid PH mobile number (e.g. 917 123 4567).',
            'contact_no.unique'        => 'This mobile number is already in use.',
            'terms.accepted'           => 'Please agree to the Terms of Service and Privacy Policy.',
        ];
    }

    /** Unique, ignoring buyer sign-ups that never finished email verification. */
    private function uniqueAmongActiveUsers(string $column)
    {
        return Rule::unique('users', $column)->where(
            fn ($q) => $q->whereNotNull('email_verified_at')->orWhereNull('email_verification_code')
        );
    }

    private function unverifiedBuyers()
    {
        return User::where('role', 'buyer')
            ->whereNull('email_verified_at')
            ->whereNotNull('email_verification_code');
    }

    private function sendVerificationCode(User $user): void
    {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            'email_verification_code'       => Hash::make($code),
            'email_verification_expires_at' => now()->addMinutes(self::CODE_TTL_MINUTES),
            'email_verification_sent_at'    => now(),
            'email_verification_attempts'   => 0,
        ])->save();

        Mail::to($user->email)->send(new BuyerVerificationCodeMail($user, $code, self::CODE_TTL_MINUTES));
    }

    private function codeError(string $message)
    {
        return response()->json(['message' => $message, 'errors' => ['code' => [$message]]], 422);
    }

    /** john.doe@gmail.com -> j***e@gmail.com */
    private function maskEmail(string $email): string
    {
        [$local, $domain] = explode('@', $email, 2);
        $masked = strlen($local) <= 2
            ? $local[0] . '***'
            : $local[0] . '***' . substr($local, -1);

        return "{$masked}@{$domain}";
    }


    public function login(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        if ($user->role !== 'buyer') {
            return response()->json(['message' => 'This app is for buyers only.'], 403);
        }

        // Signed up but never entered the emailed code: send them back to it.
        if ($user->email_verification_code && !$user->email_verified_at) {
            return response()->json([
                'message'            => 'Please verify your email to finish creating your account.',
                'needs_verification' => true,
                'email'              => $user->email,
                'masked_email'       => $this->maskEmail($user->email),
                'expires_in'         => max(0, (int) now()->diffInSeconds($user->email_verification_expires_at, false)),
            ], 403);
        }

        if ($user->isPending()) {
            return response()->json(['message' => 'Your account is still pending approval. Please check your email.'], 403);
        }

        if ($user->status === 'disapproved') {
            return response()->json(['message' => 'Your registration was disapproved. Please contact support.'], 403);
        }

        if ($user->status === 'suspended') {
            return response()->json(['message' => 'Your account has been suspended. Please contact support.'], 403);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Login successful.',
            'token'   => $token,
            'user'    => ['id' => $user->id, 'name' => $user->full_name, 'email' => $user->email],
        ]);
    }
}
