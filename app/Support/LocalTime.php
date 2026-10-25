<?php

namespace App\Support;

use Carbon\CarbonImmutable;
use DateTimeInterface;

/**
 * Philippine time for people, UTC for storage.
 *
 * Stored timestamps are UTC. Use this class to show them, and to turn a
 * calendar day as people mean it ("Oct 26") into the UTC instants that
 * bound it. Never save a value returned by of()/now()/today() to a model
 * or bind it to a query: Laravel writes dates in their own time zone. Use
 * dayRange() for queries; it returns UTC.
 */
final class LocalTime
{
    public static function zone(): string
    {
        return (string) config('app.display_timezone', 'Asia/Manila');
    }

    /** The same instant on the Philippine clock (null stays null). */
    public static function of(?DateTimeInterface $at): ?CarbonImmutable
    {
        return $at ? CarbonImmutable::instance($at)->setTimezone(self::zone()) : null;
    }

    public static function now(): CarbonImmutable
    {
        return CarbonImmutable::now(self::zone());
    }

    /** Midnight today, Philippine time. */
    public static function today(): CarbonImmutable
    {
        return self::now()->startOfDay();
    }

    /** The Philippine calendar date (Y-m-d) of an instant. */
    public static function dateOf(?DateTimeInterface $at): ?string
    {
        return self::of($at)?->toDateString();
    }

    /**
     * UTC instants from the start of the first local day to the end of the
     * last, for whereBetween() on stored timestamps.
     *
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}
     */
    public static function dayRange(string|DateTimeInterface $from, string|DateTimeInterface|null $to = null): array
    {
        return [
            self::localDay($from)->startOfDay()->utc(),
            self::localDay($to ?? $from)->endOfDay()->utc(),
        ];
    }

    /** A date string or a date as the local calendar day it names. */
    private static function localDay(string|DateTimeInterface $day): CarbonImmutable
    {
        $date = $day instanceof DateTimeInterface ? self::of($day)->toDateString() : $day;
        return CarbonImmutable::parse($date, self::zone());
    }
}
