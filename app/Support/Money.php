<?php

namespace App\Support;

use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;

/**
 * Finance code works in integer centavos. These helpers convert the
 * decimal peso columns (strings from MySQL, numbers from SQLite) without
 * floating-point arithmetic.
 */
final class Money
{
    /** "645.50" / 645.5 / null → 64550 */
    public static function cents(string|int|float|null $pesos): int
    {
        if ($pesos === null || $pesos === '') return 0;
        return BigDecimal::of((string) $pesos)->toScale(2, RoundingMode::HalfUp)->getUnscaledValue()->toInt();
    }

    /** 64550 → "645.50" (for decimal columns and inputs) */
    public static function pesos(int $cents): string
    {
        return (string) BigDecimal::ofUnscaledValue($cents, 2);
    }

    /** 64550 → "₱645.50", with thousands separators. */
    public static function format(int $cents): string
    {
        $sign = $cents < 0 ? '-' : '';
        [$whole, $fraction] = explode('.', self::pesos(abs($cents)));
        return $sign . '₱' . strrev(implode(',', str_split(strrev($whole), 3))) . '.' . $fraction;
    }

    /** $cents × a decimal rate given as a string ("0.10"), rounded half-up to the centavo. */
    public static function times(int $cents, string $rate): int
    {
        return BigDecimal::of($cents)->multipliedBy($rate)->toScale(0, RoundingMode::HalfUp)->toInt();
    }
}
