<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\Order;
use App\Models\User;
use App\Support\Money;
use App\Support\OrderStatus;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Cash on Delivery, the only payment method:
 *   placed (unpaid) → rider delivers and collects the exact total (collected)
 *   → the sorting center or admin counts the cash the rider hands in (paid).
 * An order is never "paid" until that hand-in is confirmed.
 */
class CodPayments
{
    public function __construct(private Ledger $ledger, private RiderPay $riderPay) {}

    /** The assigned rider delivers the parcel and records the cash taken from the buyer. */
    public function deliverAndCollect(Order $order, User $courier, string $collectedPesos): Order
    {
        return DB::transaction(function () use ($order, $courier, $collectedPesos) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_if($order->courier_id !== $courier->id, 403);
            OrderStatus::ensure($order, 'deliver');
            abort_unless($order->isCod(), 422, 'Only Cash on Delivery orders are supported.');
            abort_if($order->payment_status !== 'unpaid', 422, 'Payment for this order was already recorded.');

            $due = $order->totalCents();
            abort_if(Money::cents($collectedPesos) !== $due, 422,
                'Collect exactly ' . Money::format($due) . ' in cash before marking this parcel delivered.');

            $order->update([
                'status'           => 'completed',
                'tracking_status'  => 'Delivered',
                'delivered_at'     => now(),
                'payment_status'   => 'collected',
                'cod_collected_at' => now(),
                'cod_collected_by' => $courier->id,
            ]);
            $this->ledger->post('cod_collected', "cod_collected:order:{$order->id}", [
                [Ledger::RIDER_CASH, $courier->id, $due, $order->id],
                [Ledger::ORDER_FUNDS, null, -$due, $order->id],
            ], ['order_id' => $order->id], $courier, "Cash collected on delivery of {$order->order_number}");
            AuditLog::record($order, 'cod_collected', 'unpaid', 'collected', null, $due, $courier);

            return $order;
        });
    }

    /**
     * Sorting-center staff or an admin confirms they received the cash a
     * rider collected for these orders. Each order can be confirmed once.
     *
     * @return int centavos confirmed
     */
    public function confirmRemittance(User $courier, array $orderIds, User $confirmer): int
    {
        return DB::transaction(function () use ($courier, $orderIds, $confirmer) {
            $orderIds = array_values(array_unique(array_map('intval', $orderIds)));
            $orders = Order::whereIn('id', $orderIds)->where('cod_collected_by', $courier->id)
                ->where('payment_status', 'collected')->lockForUpdate()->get();
            abort_if($orders->isEmpty() || $orders->count() !== count($orderIds), 422,
                'Some selected parcels are not waiting for this rider to hand in cash.');

            $total = 0;
            foreach ($orders as $order) {
                $due = $order->totalCents();
                $this->ledger->post('cod_remitted', "cod_remitted:order:{$order->id}", [
                    [Ledger::PLATFORM_CASH, null, $due, $order->id],
                    [Ledger::RIDER_CASH, $courier->id, -$due, $order->id],
                ], ['order_id' => $order->id], $confirmer, "Cash for {$order->order_number} handed in by {$courier->full_name}");
                $order->update(['payment_status' => 'paid', 'paid_at' => now(), 'payment_confirmed_by' => $confirmer->id]);
                AuditLog::record($order, 'cod_remitted', 'collected', 'paid', "Handed in by {$courier->full_name}", $due, $confirmer);
                // The rider's delivery is now complete and its cash accounted for.
                $this->riderPay->accrueDelivery($order, $confirmer);
                $total += $due;
            }

            return $total;
        });
    }

    // ── Orders delivered before COD tracking existed ─────────────────────

    /** Delivered, never recorded as collected, and not yet reviewed. */
    public function legacyOrders()
    {
        return Order::where('status', 'completed')->where('payment_status', 'unpaid')->whereNull('cod_collected_by')
            ->whereNull('payment_backfilled_at')->orderBy('delivered_at');
    }

    /**
     * An admin records cash that was verifiably received for an order
     * delivered before COD tracking. Only dates backed by the evidence are
     * stored; the entry is marked historical and never earns rider pay.
     */
    public function backfillHistoricalCollection(Order $order, User $admin, string $amountPesos, string $evidence, string $reason, ?string $collectedOn): void
    {
        DB::transaction(function () use ($order, $admin, $amountPesos, $evidence, $reason, $collectedOn) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_unless($this->legacyOrders()->whereKey($order->id)->exists() || $order->payment_review === 'unverifiable', 422,
                'Only delivered orders with no recorded COD collection can be backfilled.');
            abort_unless($order->status === 'completed' && $order->payment_status === 'unpaid', 422, 'This order already has a payment record.');

            $due = $order->totalCents();
            abort_if(Money::cents($amountPesos) !== $due, 422,
                'The evidenced amount must equal the order total (' . Money::format($due) . '). Mark the order unverifiable instead.');

            $this->ledger->post('cod_backfill', "cod_backfill:order:{$order->id}", [
                [Ledger::PLATFORM_CASH, null, $due, $order->id],
                [Ledger::ORDER_FUNDS, null, -$due, $order->id],
            ], ['order_id' => $order->id], $admin, "Historical COD for {$order->order_number}", [
                'historical' => true, 'evidence' => $evidence, 'reason' => $reason,
                'collected_on' => $collectedOn, 'recorded_at' => now()->toIso8601String(),
            ]);
            $order->update([
                'payment_status'        => 'paid',
                'cod_collected_at'      => $collectedOn,   // only when the evidence shows it
                'paid_at'               => null,           // hand-in time unknown; see payment_backfilled_at
                'payment_confirmed_by'  => $admin->id,
                'payment_backfilled_at' => now(),
                'payment_review'        => null,
                'payment_review_note'   => null,
            ]);
            AuditLog::record($order, 'cod_backfilled', 'unpaid', 'paid', "Evidence: {$evidence}. {$reason}", $due, $admin);
        });
    }

    /** No trustworthy evidence: keep the order out of settlement and refunds until resolved. */
    public function markUnverifiable(Order $order, User $admin, string $note): void
    {
        DB::transaction(function () use ($order, $admin, $note) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_unless($this->legacyOrders()->whereKey($order->id)->exists(), 422, 'Only unreviewed legacy orders can be marked unverifiable.');
            $order->update(['payment_review' => 'unverifiable', 'payment_review_note' => $note]);
            AuditLog::record($order, 'payment_unverifiable', 'unpaid', 'unpaid', $note, null, $admin);
        });
    }

    /** Collected orders still in riders' hands, grouped by rider id. */
    public function awaitingRemittance(?int $logisticsId = null): Collection
    {
        return Order::with('collectedBy')->where('payment_status', 'collected')
            ->when($logisticsId, fn ($q) => $q->where(fn ($q) => $q->where('logistics_id', $logisticsId)->orWhereNull('logistics_id')))
            ->orderBy('cod_collected_at')->get()->groupBy('cod_collected_by');
    }
}
