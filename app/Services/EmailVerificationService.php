<?php

namespace App\Services;

use App\Mail\EmailVerificationCodeMail;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * One-time codes that prove a person owns an email address before their account is created
 * (the registration form's Account step). A code is 6 digits, lives 5 minutes, allows 5 attempts,
 * and is replaced by every resend. Codes are kept hashed in the cache, keyed by email.
 */
class EmailVerificationService
{
    public const CODE_TTL_MINUTES = 5;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_COOLDOWN_SECONDS = 60;

    /** Replace any outstanding code for this email with a new one and send it. Returns whether it was sent. */
    public function send(string $email, ?string $name = null): bool
    {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        Cache::put($this->key($email), [
            'hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(self::CODE_TTL_MINUTES)->getTimestamp(),
            'sent_at' => now()->getTimestamp(),
            'attempts' => 0,
        ], now()->addMinutes(self::CODE_TTL_MINUTES + 10));

        try {
            Mail::to($email)->send(new EmailVerificationCodeMail($name, $code, self::CODE_TTL_MINUTES));

            return true;
        } catch (Throwable $exception) {
            Log::warning('Email verification code could not be sent.', ['email' => $email, 'error' => $exception->getMessage()]);

            return false;
        }
    }

    /** Seconds until another code may be sent to this email; 0 when it may be sent now. */
    public function resendWaitSeconds(string $email): int
    {
        $entry = Cache::get($this->key($email));

        return $entry ? max(0, self::RESEND_COOLDOWN_SECONDS - (now()->getTimestamp() - $entry['sent_at'])) : 0;
    }

    /**
     * @return 'verified'|'invalid'|'expired'|'locked'|'missing'
     */
    public function check(string $email, string $code): string
    {
        return Cache::lock($this->key($email).':lock', 5)->block(5, function () use ($email, $code): string {
            $entry = Cache::get($this->key($email));
            if (! $entry) {
                return 'missing';
            }
            if (now()->getTimestamp() > $entry['expires_at']) {
                return 'expired';
            }
            if ($entry['attempts'] >= self::MAX_ATTEMPTS) {
                return 'locked';
            }
            if (! Hash::check($code, $entry['hash'])) {
                $entry['attempts']++;
                Cache::put($this->key($email), $entry, now()->addMinutes(self::CODE_TTL_MINUTES + 10));

                return $entry['attempts'] >= self::MAX_ATTEMPTS ? 'locked' : 'invalid';
            }

            Cache::forget($this->key($email));

            return 'verified';
        });
    }

    public function attemptsLeft(string $email): int
    {
        return self::MAX_ATTEMPTS - (int) (Cache::get($this->key($email))['attempts'] ?? 0);
    }

    private function key(string $email): string
    {
        return 'email-otp:'.sha1(strtolower(trim($email)));
    }
}
