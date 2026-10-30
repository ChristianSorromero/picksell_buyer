<?php

namespace App\Services\Orders;

use App\Models\Order;
use App\Models\Product;

/**
 * The order lifecycle: which status may follow which, the timestamp column each status sets, and
 * the side effects a transition carries. Order::booted() applies timestamps and history for every
 * status change; every portal uses transition() as the guarded state-change authority.
 */
class OrderLifecycleService
{
    /** status => statuses it may move to */
    public const TRANSITIONS = [
        'placed' => ['confirmed', 'preparing', 'cancelled'],
        'confirmed' => ['preparing', 'cancelled'],
        'preparing' => ['ready_for_pickup', 'cancelled'],
        'ready_for_pickup' => ['picked_up', 'cancelled'],
        'picked_up' => ['at_sorting_center'],
        'at_sorting_center' => ['sorted'],
        'sorted' => ['assigned_to_rider'],
        'assigned_to_rider' => ['out_for_delivery', 'at_sorting_center'],
        'out_for_delivery' => ['delivered', 'delivery_failed'],
        'delivery_failed' => ['at_sorting_center', 'returned'],
        'delivered' => ['completed'],
        'completed' => [],
        'returned' => [],
        'cancelled' => [],

        // Legacy statuses from before the lifecycle was formalised: Admin moves them onto the
        // current lifecycle (with a reason) to the step that matches where the parcel really is.
        'pending' => ['placed', 'preparing', 'cancelled'],
        'processing' => ['preparing', 'ready_for_pickup', 'cancelled'],
        'shipped' => ['at_sorting_center', 'out_for_delivery', 'delivered'],
    ];

    public const LEGACY = ['pending', 'processing', 'shipped'];

    /** status => lifecycle timestamp column set the first time the order reaches it */
    public const TIMESTAMPS = [
        'confirmed' => 'confirmed_at',
        'preparing' => 'preparing_at',
        'ready_for_pickup' => 'ready_for_pickup_at',
        'picked_up' => 'picked_up_at',
        'at_sorting_center' => 'sorting_received_at',
        'sorted' => 'sorted_at',
        'assigned_to_rider' => 'assigned_to_rider_at',
        'out_for_delivery' => 'out_for_delivery_at',
        'delivered' => 'delivered_at',
        'completed' => 'completed_at',
    ];

    /** Statuses at which the item never reached the buyer and is back with (or never left) the seller. */
    public const RESTOCK_ON = ['cancelled', 'returned'];

    public const TERMINAL = ['completed', 'returned', 'cancelled'];

    /** The main path, for timelines. */
    public const MAIN_PATH = ['placed', 'confirmed', 'preparing', 'ready_for_pickup', 'picked_up', 'at_sorting_center', 'sorted', 'assigned_to_rider', 'out_for_delivery', 'delivered', 'completed'];

    public static function allowedNext(string $from): array
    {
        return self::TRANSITIONS[$from] ?? [];
    }

    public static function canTransition(string $from, string $to): bool
    {
        return in_array($to, self::allowedNext($from), true);
    }

    public static function label(string $status): string
    {
        return ucfirst(str_replace('_', ' ', $status));
    }

    /**
     * Guarded transition. Caller holds a row lock and runs inside a transaction.
     *
     * @param  array<string, mixed>  $extra  extra column updates (e.g. the waybill number)
     */
    public function transition(Order $order, string $to, ?int $actorId, string $source, ?string $reason, array $extra = []): void
    {
        abort_unless(self::canTransition($order->status, $to), 409, 'An order cannot move from ' . self::label($order->status) . ' to ' . self::label($to) . '.');

        $order->statusChangedBy = $actorId;
        $order->statusChangeSource = $source;
        $order->statusChangeReason = $reason;
        unset($extra['status']);
        $extra['status'] = $to;
        $extra['tracking_status'] ??= self::label($to);
        $order->update($extra);

        if (in_array($to, self::RESTOCK_ON, true) && $order->product_id) {
            Product::whereKey($order->product_id)->increment('stock', (int) $order->quantity);
        }
    }
}
