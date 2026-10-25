<?php

namespace App\Services;

use App\Models\DeliveryAttempt;
use App\Models\LedgerTransaction;
use App\Models\Order;
use App\Models\User;
use App\Support\Money;

/**
 * Rider compensation (config picksell.finance.rider_pay). Nothing accrues
 * unless the policy status is 'active' and a base rate is set.
 *
 * Per delivered order, to the rider who delivered it and collected the
 * cash, once that cash is handed in:
 *   first parcel at a stop  = base_per_stop + zone adjustment
 *   each extra parcel there = additional_parcel
 * A stop is one rider, one delivery address, one day. Cancelled orders,
 * parcels returned to the seller and reassigned parcels earn nothing for
 * the delivery itself; failed attempts earn failed_attempt if it is set.
 * Pay is charged to Picksell's revenue, never to the seller or the order.
 */
class RiderPay
{
    public function __construct(private Ledger $ledger) {}

    /** unconfigured | proposed | active (active without a base rate counts as unconfigured). */
    public function status(): string
    {
        $status = config('picksell.finance.rider_pay.status', 'unconfigured');
        return $this->cents('base_per_stop') === null || !in_array($status, ['proposed', 'active'], true) ? 'unconfigured' : $status;
    }

    public function isActive(): bool
    {
        return $this->status() === 'active';
    }

    /** The configured rates in centavos, for display (proposed or active). */
    public function rates(): ?array
    {
        if ($this->status() === 'unconfigured') return null;
        return [
            'base_per_stop'     => $this->cents('base_per_stop'),
            'additional_parcel' => $this->cents('additional_parcel') ?? 0,
            'failed_attempt'    => $this->cents('failed_attempt') ?? 0,
            'zone_adjustments'  => array_map(fn ($p) => Money::cents($p), config('picksell.finance.rider_pay.zone_adjustments', [])),
        ];
    }

    public function accrueDelivery(Order $order, ?User $actor = null): ?LedgerTransaction
    {
        $riderId = $order->cod_collected_by;
        $key = "rider_pay:delivery:order:{$order->id}";
        if (!$this->isActive() || !$riderId || $order->status !== 'completed' || $this->ledger->posted($key)) return null;

        $rates = $this->rates();
        $stop = $this->stopKey($order);
        $firstAtStop = !LedgerTransaction::where('type', 'rider_pay_accrued')->where('details->stop_key', $stop)->exists();
        $zone = $firstAtStop ? $this->zoneAdjustment($order, $rates['zone_adjustments']) : ['area' => null, 'cents' => 0];
        $base = $firstAtStop ? $rates['base_per_stop'] : $rates['additional_parcel'];
        $amount = $base + $zone['cents'];
        if ($amount <= 0) return null;

        return $this->ledger->post('rider_pay_accrued', $key, [
            [Ledger::PLATFORM_REVENUE, null, $amount, $order->id],
            [Ledger::RIDER_PAYABLE, $riderId, -$amount, $order->id],
        ], ['order_id' => $order->id], $actor, "Rider pay for delivering {$order->order_number}", [
            'rule'        => $firstAtStop ? 'first_parcel_at_stop' : 'additional_parcel_at_stop',
            'stop_key'    => $stop,
            'base_cents'  => $base,
            'zone'        => $zone['area'],
            'zone_cents'  => $zone['cents'],
            'total_cents' => $amount,
        ]);
    }

    public function accrueFailedAttempt(DeliveryAttempt $attempt, ?User $actor = null): ?LedgerTransaction
    {
        $fee = $this->isActive() ? ($this->rates()['failed_attempt'] ?? 0) : 0;
        $key = "rider_pay:attempt:{$attempt->id}";
        if ($fee <= 0 || !$attempt->courier_id || $this->ledger->posted($key)) return null;

        return $this->ledger->post('rider_pay_accrued', $key, [
            [Ledger::PLATFORM_REVENUE, null, $fee, $attempt->order_id],
            [Ledger::RIDER_PAYABLE, $attempt->courier_id, -$fee, $attempt->order_id],
        ], ['order_id' => $attempt->order_id], $actor, 'Rider pay for a failed delivery attempt', [
            'rule' => 'failed_attempt', 'attempt_id' => $attempt->id, 'reason' => $attempt->reason, 'total_cents' => $fee,
        ]);
    }

    private function stopKey(Order $order): string
    {
        $address = $order->delivery['address'] ?? '';
        return $order->cod_collected_by . ':' . md5(mb_strtolower(trim($address))) . ':' . $order->delivered_at?->toDateString();
    }

    /** @return array{area: ?string, cents: int} */
    private function zoneAdjustment(Order $order, array $zones): array
    {
        foreach ([$order->ship_to['municipality'] ?? null, $order->ship_to['province'] ?? null] as $area) {
            if ($area && isset($zones[$area])) return ['area' => $area, 'cents' => $zones[$area]];
        }
        return ['area' => null, 'cents' => 0];
    }

    private function cents(string $setting): ?int
    {
        $value = config("picksell.finance.rider_pay.{$setting}");
        return $value === null || $value === '' ? null : Money::cents($value);
    }
}
