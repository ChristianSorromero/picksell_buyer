<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\DeliveryAttempt;
use App\Models\Order;
use App\Models\ProductVariation;
use App\Models\User;
use App\Support\OrderStatus;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Delivery attempts, recorded separately from the COD cash events:
 *
 *   out for delivery ─▶ delivered (proof of delivery + COD collected)
 *          │
 *          └─▶ failed (reason) ─▶ out for delivery again (up to max_attempts)
 *                     └─▶ returned to seller ─▶ seller receives it (order closed, nothing charged)
 */
class Deliveries
{
    public function __construct(private CodPayments $cod, private RiderPay $riderPay) {}

    public function setOut(Order $order, User $courier): void
    {
        DB::transaction(function () use ($order, $courier) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_if($order->courier_id !== $courier->id, 403);
            OrderStatus::ensure($order, 'out_for_delivery');
            $max = (int) config('picksell.delivery.max_attempts');
            abort_if($order->delivery_attempts >= $max, 422, "This parcel already had {$max} failed attempts; the sorting center will return it to the seller.");
            $order->update(['status' => 'shipped', 'tracking_status' => 'Out for delivery']);
        });
    }

    /** Proof of delivery and the COD cash, recorded together or not at all. */
    public function deliver(Order $order, User $courier, string $cashCollected, string $recipient, ?UploadedFile $photo, ?string $note): void
    {
        DB::transaction(function () use ($order, $courier, $cashCollected, $recipient, $photo, $note) {
            $order = $this->cod->deliverAndCollect($order, $courier, $cashCollected);
            $attempt = DeliveryAttempt::create([
                'order_id'         => $order->id,
                'courier_id'       => $courier->id,
                'outcome'          => 'delivered',
                'recipient_name'   => $recipient,
                'proof_photo_path' => $photo?->store('uploads/proof-of-delivery', 'local'),
                'note'             => $note,
                'attempted_at'     => now(),
            ]);
            $order->increment('delivery_attempts');
            AuditLog::record($order, 'delivered', 'out_for_delivery', 'delivered', "Received by {$recipient}" . ($attempt->proof_photo_path ? ' (photo)' : ''), null, $courier);
        });
    }

    public function fail(Order $order, User $courier, string $reason, ?string $note, ?UploadedFile $photo): DeliveryAttempt
    {
        if (!in_array($reason, config('picksell.delivery.failed_reasons'), true)) {
            throw ValidationException::withMessages(['reason' => 'Choose why the delivery failed.']);
        }

        return DB::transaction(function () use ($order, $courier, $reason, $note, $photo) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_if($order->courier_id !== $courier->id, 403);
            OrderStatus::ensure($order, 'fail_delivery');

            $attempt = DeliveryAttempt::create([
                'order_id'         => $order->id,
                'courier_id'       => $courier->id,
                'outcome'          => 'failed',
                'reason'           => $reason,
                'proof_photo_path' => $photo?->store('uploads/proof-of-delivery', 'local'),
                'note'             => $note,
                'attempted_at'     => now(),
            ]);
            $order->update(['tracking_status' => "Delivery failed: {$reason}", 'delivery_attempts' => $order->delivery_attempts + 1]);
            AuditLog::record($order, 'delivery_failed', 'out_for_delivery', 'delivery_failed', trim("{$reason}. {$note}"), null, $courier);
            $this->riderPay->accrueFailedAttempt($attempt, $courier);

            return $attempt;
        });
    }

    /** Sorting center or admin sends an undeliverable parcel back to the seller. */
    public function returnToSender(Order $order, User $staff, string $reason): void
    {
        DB::transaction(function () use ($order, $staff, $reason) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            OrderStatus::ensure($order, 'return_to_sender');
            $order->update(['tracking_status' => 'Returning to seller']);
            AuditLog::record($order, 'returning_to_seller', 'delivery_failed', 'returned', $reason, null, $staff);
        });
    }

    /** The seller has the parcel back; the order closes with nothing charged. Restock only if sellable. */
    public function receiveReturned(Order $order, User $seller, bool $restock): void
    {
        DB::transaction(function () use ($order, $seller, $restock) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_if($order->seller_id !== $seller->id, 403);
            OrderStatus::ensure($order, 'receive_returned');
            abort_if($order->status !== 'shipped', 422, 'This parcel was already received back.');

            $order->update([
                'status'          => 'cancelled',
                'tracking_status' => 'Returned to seller',
                'cancelled_at'    => now(),
                'cancel_reason'   => 'Returned to seller after failed delivery',
            ]);
            if ($restock) {
                $order->product?->increment('stock', $order->quantity);
                if ($order->variation_ids) ProductVariation::whereIn('id', $order->variation_ids)->increment('stock', $order->quantity);
            }
            AuditLog::record($order, $restock ? 'returned_parcel_restocked' : 'returned_parcel_not_restocked', 'returned', 'returned', null, null, $seller);
        });
    }
}
