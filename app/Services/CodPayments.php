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
    public function __construct(private Ledger $ledger) {}

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
                $total += $due;
            }

            return $total;
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
