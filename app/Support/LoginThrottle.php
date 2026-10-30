<?php

namespace App\Support;

use Illuminate\Support\Facades\RateLimiter;

/**
 * Per-account lockout shared by the app and website logins. The route
 * throttles limit each IP; this limits each email, so guesses spread
 * over many IPs still stop. Keyed on the typed email whether or not an
 * account exists, so a lockout doesn't reveal which emails are registered.
 */
final class LoginThrottle
{
    public const MAX_FAILURES  = 10;
    public const DECAY_SECONDS = 15 * 60;

    /** Seconds until the account may try again, or 0 when it isn't locked. */
    public static function lockedFor(string $email): int
    {
        $key = self::key($email);
        return RateLimiter::tooManyAttempts($key, self::MAX_FAILURES) ? RateLimiter::availableIn($key) : 0;
    }

    public static function failed(string $email): void
    {
        RateLimiter::hit(self::key($email), self::DECAY_SECONDS);
    }

    public static function succeeded(string $email): void
    {
        RateLimiter::clear(self::key($email));
    }

    public static function message(int $seconds): string
    {
        $minutes = max(1, (int) ceil($seconds / 60));
        return "Too many failed sign-in attempts. Try again in {$minutes} minute" . ($minutes === 1 ? '' : 's') . '.';
    }

    private static function key(string $email): string
    {
        return 'login-failures:' . sha1(mb_strtolower(trim($email)));
    }
}
