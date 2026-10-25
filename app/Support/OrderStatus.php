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
        self::RETURNED          => ['Returned', 'Your return has been processed.'],
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

    public static function of(Order $order): string
    {
        $tracking = (string) $order->tracking_status;

        return match ($order->status) {
            'cancelled'  => self::CANCELLED,
            'completed'  => $order->rating ? self::COMPLETED : self::DELIVERED,
            'processing' => self::PREPARING,
            'shipped'    => match (true) {
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
