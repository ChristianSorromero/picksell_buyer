<?php

namespace App\Support;

use App\Models\Order;

/**
 * LOG-C01 Canonical Status — the single mapping from the stored order
 * columns (status + tracking_status, written by the seller, logistics and
 * courier dashboards) to the shared lifecycle the mobile apps display.
 * Mirrors lib/core/status/order_status.dart.
 */
final class OrderStatus
{
    public const PLACED            = 'placed';
    public const PREPARING         = 'preparing';
    public const PICKED_UP         = 'picked_up';
    public const AT_SORTING_CENTER = 'at_sorting_center';
    public const ASSIGNED_TO_RIDER = 'assigned_to_rider';
    public const OUT_FOR_DELIVERY  = 'out_for_delivery';
    public const DELIVERED         = 'delivered';
    public const COMPLETED         = 'completed';
    public const DELIVERY_FAILED   = 'delivery_failed';
    public const RETURNED          = 'returned';
    public const CANCELLED         = 'cancelled';

    /** Buyer-facing timeline copy per canonical state. */
    public const EVENTS = [
        self::PLACED            => ['Order placed', 'Your order has been received and sent to the seller.'],
        self::PREPARING         => ['Seller is preparing your order', 'The seller is packing your item for pickup.'],
        self::PICKED_UP         => ['Picked up by courier', 'The seller handed your parcel to our logistics partner.'],
        self::AT_SORTING_CENTER => ['Arrived at sorting center', 'Your parcel was received and scanned at the sorting center.'],
        self::ASSIGNED_TO_RIDER => ['Rider assigned', 'A rider has been assigned to deliver your parcel.'],
        self::OUT_FOR_DELIVERY  => ['Out for delivery', 'Your parcel is on its way to you.'],
        self::DELIVERED         => ['Delivered', 'Your parcel has been delivered. Enjoy!'],
        self::COMPLETED         => ['Order completed', 'Thanks for rating your order.'],
        self::DELIVERY_FAILED   => ['Delivery attempt failed', 'We couldn’t deliver your parcel. We’ll try again.'],
        self::RETURNED          => ['Returned to seller', 'We couldn’t deliver your parcel, so it is going back to the seller. You were not charged.'],
        self::CANCELLED         => ['Order cancelled', 'This order was cancelled.'],
    ];

    /** Tabs on the buyer "My Orders" screen → canonical states. */
    public const TABS = [
        'to_ship'          => [self::PLACED, self::PREPARING],
        'in_transit'       => [self::PICKED_UP, self::AT_SORTING_CENTER, self::ASSIGNED_TO_RIDER],
        'out_for_delivery' => [self::OUT_FOR_DELIVERY, self::DELIVERY_FAILED],
        'to_rate'          => [self::DELIVERED],
        'completed'        => [self::COMPLETED, self::RETURNED],
        'cancelled'        => [self::CANCELLED],
    ];

    /**
     * Role actions on the web dashboards → the canonical states each may
     * start from, plus the refusal shown otherwise. Keeps stale pages or
     * crafted requests from reviving cancelled orders or skipping steps.
     */
    public const ACTIONS = [
        'pack'             => [[self::PLACED], 'Only new orders can be packed.'],
        'handover'         => [[self::PREPARING], 'Pack the order before handing it over.'],
        'scan'             => [[self::PICKED_UP], 'Only parcels handed over by the seller can be scanned.'],
        'assign'           => [[self::AT_SORTING_CENTER, self::ASSIGNED_TO_RIDER, self::DELIVERY_FAILED], 'Scan the parcel at the sorting center before assigning a rider.'],
        'out_for_delivery' => [[self::ASSIGNED_TO_RIDER, self::DELIVERY_FAILED], 'Only parcels assigned to you and not yet on the way can be set out for delivery.'],
        'deliver'          => [[self::OUT_FOR_DELIVERY], 'Set the parcel out for delivery before marking it delivered.'],
        'fail_delivery'    => [[self::OUT_FOR_DELIVERY], 'Only a parcel that is out for delivery can be marked as a failed attempt.'],
        'return_to_sender' => [[self::DELIVERY_FAILED], 'Only a parcel with a failed delivery can be sent back to the seller.'],
        'receive_returned' => [[self::RETURNED], 'This parcel is not on its way back to you.'],
    ];

    public static function can(Order $order, string $action): bool
    {
        return in_array(self::of($order), self::ACTIONS[$action][0], true);
    }

    /** Aborts with 422 when [$action] isn't allowed from the order's current state. */
    public static function ensure(Order $order, string $action): void
    {
        abort_unless(self::can($order, $action), 422, self::ACTIONS[$action][1]);
    }

    public static function of(Order $order): string
    {
        $tracking = (string) $order->tracking_status;

        return match ($order->status) {
            // A parcel sent back after failed deliveries stays "returned", not "cancelled".
            'cancelled'  => $tracking === 'Returned to seller' ? self::RETURNED : self::CANCELLED,
            'completed'  => $order->rating ? self::COMPLETED : self::DELIVERED,
            'processing' => self::PREPARING,
            'shipped'    => match (true) {
                $tracking === 'Returning to seller'                   => self::RETURNED,
                str_starts_with($tracking, 'Delivery failed')         => self::DELIVERY_FAILED,
                $tracking === 'Out for delivery'                      => self::OUT_FOR_DELIVERY,
                str_starts_with($tracking, 'Sorted for')              => self::ASSIGNED_TO_RIDER,
                $tracking === 'Received and scanned at sorting center' => self::AT_SORTING_CENTER,
                default                                               => self::PICKED_UP,
            },
            default => self::PLACED,
        };
    }

    public static function tab(string $canonical): string
    {
        foreach (self::TABS as $tab => $states) {
            if (in_array($canonical, $states, true)) return $tab;
        }
        return 'to_ship';
    }
}
