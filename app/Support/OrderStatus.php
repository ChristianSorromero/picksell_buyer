<?php

namespace App\Support;

use App\Models\Order;

/**
 * How the website's order steps (orders.status, see OrderLifecycleService) appear in the buyer
 * app. Mirrors lib/core/status/order_status.dart.
 */
final class OrderStatus
{
    /** Steps saved by the website before its lifecycle was formalised, shown as their current equivalent. */
    public const LEGACY = ['pending' => 'placed', 'processing' => 'preparing', 'shipped' => 'picked_up'];

    /** Buyer-facing timeline copy per step. */
    public const EVENTS = [
        'placed'            => ['Order placed', 'Your order has been received and sent to the seller.'],
        'confirmed'         => ['Order confirmed', 'The seller confirmed your order.'],
        'preparing'         => ['Seller is preparing your order', 'The seller is packing your item.'],
        'ready_for_pickup'  => ['Ready for pickup', 'Your parcel is packed and waiting for the Pickrush rider.'],
        'picked_up'         => ['Picked up by courier', 'The seller handed your parcel to Pickrush.'],
        'at_sorting_center' => ['Arrived at sorting center', 'Your parcel was received and scanned at the sorting center.'],
        'sorted'            => ['Arrived at your local station', 'Your parcel reached the delivery station for your area.'],
        'assigned_to_rider' => ['Rider assigned', 'A rider has been assigned to deliver your parcel.'],
        'out_for_delivery'  => ['Out for delivery', 'Your parcel is on its way to you.'],
        'delivered'         => ['Delivered', 'Your parcel has been delivered. Enjoy!'],
        'completed'         => ['Order completed', 'The seller confirmed the delivery. Thank you!'],
        'delivery_failed'   => ['Delivery attempt failed', 'We couldn’t deliver your parcel. Pickrush will try again.'],
        'returned'          => ['Returned to seller', 'We couldn’t deliver your parcel, so it went back to the seller.'],
        'cancelled'         => ['Order cancelled', 'This order was cancelled.'],
    ];

    /** Tabs on the app's "My Orders" screen. */
    public const TABS = [
        'to_ship'          => ['placed', 'confirmed', 'preparing', 'ready_for_pickup'],
        'in_transit'       => ['picked_up', 'at_sorting_center', 'sorted', 'assigned_to_rider'],
        'out_for_delivery' => ['out_for_delivery', 'delivery_failed'],
        'to_rate'          => [], // delivered/completed and not yet rated; see tab()
        'completed'        => ['returned'],
        'cancelled'        => ['cancelled'],
    ];

    /** Same steps the website's OrderCancellationService allows a buyer to cancel in. */
    public const CANCELLABLE = ['placed', 'confirmed', 'preparing'];

    public const RATEABLE = ['delivered', 'completed'];

    public static function of(Order $order): string
    {
        return self::LEGACY[$order->status] ?? $order->status;
    }

    public static function tab(Order $order): string
    {
        $status = self::of($order);
        if (in_array($status, self::RATEABLE, true)) {
            return $order->rating ? 'completed' : 'to_rate';
        }
        foreach (self::TABS as $tab => $states) {
            if (in_array($status, $states, true)) {
                return $tab;
            }
        }

        return 'to_ship';
    }

    /** Database statuses that fall in [$tab] (to_rate/completed also need the rating check). */
    public static function statusesFor(string $tab): array
    {
        $statuses = $tab === 'to_rate' ? self::RATEABLE : [...self::TABS[$tab], ...($tab === 'completed' ? self::RATEABLE : [])];

        return [...$statuses, ...array_keys(array_intersect(self::LEGACY, $statuses))];
    }
}
