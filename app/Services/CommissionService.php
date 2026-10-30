<?php

namespace App\Services;

use App\Models\Order;

class CommissionService
{
    public function rate(): float
    {
        return (float) config('app.platform_commission_rate', 10);
    }

    /** @return array{rate: string, commission: string, seller_net: string} */
    public function calculate(string|int|float $grossAmount): array
    {
        $grossCents = $this->toCents($grossAmount);
        $rateBasisPoints = (int) round($this->rate() * 100, 0, PHP_ROUND_HALF_UP);
        $commissionCents = intdiv(($grossCents * $rateBasisPoints) + 5000, 10000);

        return [
            'rate' => number_format($rateBasisPoints / 100, 2, '.', ''),
            'commission' => $this->fromCents($commissionCents),
            'seller_net' => $this->fromCents($grossCents - $commissionCents),
        ];
    }

    public function deduction(float $grossAmount): float
    {
        return (float) $this->calculate($grossAmount)['commission'];
    }

    public function rateForOrder(Order $order): float
    {
        if ($order->commission_rate !== null) {
            return (float) $order->commission_rate;
        }

        $amountCents = $this->toCents($order->amount);
        if ($amountCents === 0) {
            return 0.0;
        }

        return round($this->toCents($order->commission) / $amountCents * 100, 2, PHP_ROUND_HALF_UP);
    }

    public function commissionForOrder(Order $order): float
    {
        return (float) $this->fromCents($this->toCents($order->commission));
    }

    public function refundCommissionReversal(
        string|int|float $refundAmount,
        string|int|float $orderCommission,
        string|int|float $orderGross,
    ): string {
        $refundCents = $this->toCents($refundAmount);
        $commissionCents = $this->toCents($orderCommission);
        $grossCents = $this->toCents($orderGross);

        if ($refundCents < 0 || $commissionCents < 0 || $grossCents < 0) {
            throw new \InvalidArgumentException('Refund and order amounts cannot be negative.');
        }
        if ($grossCents === 0 || $commissionCents === 0) {
            return '0.00';
        }

        $reversalCents = intdiv(($refundCents * $commissionCents) + intdiv($grossCents, 2), $grossCents);

        return $this->fromCents(min($refundCents, $commissionCents, $reversalCents));
    }

    public function sellerNet(string|int|float $grossAmount, string|int|float $commission): float
    {
        return (float) $this->fromCents($this->toCents($grossAmount) - $this->toCents($commission));
    }

    public function sum(iterable $amounts): float
    {
        $totalCents = 0;
        foreach ($amounts as $amount) {
            $totalCents += $this->toCents($amount);
        }

        return (float) $this->fromCents($totalCents);
    }

    public function toCents(string|int|float $amount): int
    {
        $value = trim((string) $amount);
        if (! preg_match('/^(-?)(\d+)(?:\.(\d+))?$/', $value, $matches)) {
            throw new \InvalidArgumentException('Money values must be a plain decimal number.');
        }

        $fraction = str_pad($matches[3] ?? '', 3, '0');
        $cents = ((int) $matches[2] * 100) + (int) substr($fraction, 0, 2);
        if ((int) $fraction[2] >= 5) {
            $cents++;
        }

        return ($matches[1] ?? '') === '-' ? -$cents : $cents;
    }

    public function fromCents(int $cents): string
    {
        $sign = $cents < 0 ? '-' : '';
        $absolute = abs($cents);

        return $sign.intdiv($absolute, 100).'.'.str_pad((string) ($absolute % 100), 2, '0', STR_PAD_LEFT);
    }
}
