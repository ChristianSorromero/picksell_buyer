<?php

namespace App\Support;

use App\Models\BuyerAddress;
use App\Models\Order;
use App\Models\Product;
use App\Models\ReturnRequest;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * JSON shapes returned by the mobile buyer API. Keep in sync with the Dart
 * models in lib/models/.
 */
final class BuyerPresenter
{
    public static function image(?string $path): ?string
    {
        if (!$path) return null;
        return str_starts_with($path, 'http') ? $path : url('storage/' . ltrim($path, '/'));
    }

    public static function money(float|string|null $v): float
    {
        return round((float) $v, 2);
    }

    public static function date(?Carbon $d): ?string
    {
        return $d?->toIso8601String();
    }

    /** Card-sized product (lists, grids, cart, wishlist). */
    public static function product(Product $p, array $wishlistIds = []): array
    {
        $price = self::money($p->effective_price);
        $hasDiscount = $p->discount > 0;

        return [
            'id'               => $p->id,
            'name'             => $p->name,
            'category'         => $p->category ?? '',
            'price'            => $price,
            'original_price'   => $hasDiscount ? self::money($p->price) : null,
            'discount_percent' => $hasDiscount ? (int) round($p->discount) : null,
            'stock'            => (int) $p->stock,
            'image'            => self::image($p->image),
            'images'           => array_values(array_filter([self::image($p->image)])),
            'rating'           => $p->reviews_avg_rating !== null ? round((float) $p->reviews_avg_rating, 1) : null,
            'review_count'     => (int) ($p->reviews_count ?? 0),
            'sold_count'       => (int) ($p->sold_count ?? 0),
            'is_featured'      => (bool) $p->is_featured,
            'is_available'     => $p->status === 'active' && $p->stock > 0,
            'wishlisted'       => in_array($p->id, $wishlistIds, true),
            'seller'           => $p->relationLoaded('seller') && $p->seller ? self::sellerBrief($p->seller) : null,
            // Kept for older app builds.
            'seller_name'      => $p->seller?->business_name ?: $p->seller?->full_name ?? '',
            'seller_location'  => self::location($p->seller),
        ];
    }

    public static function sellerBrief(User $s): array
    {
        return [
            'id'       => $s->id,
            'name'     => $s->business_name ?: $s->full_name,
            'location' => self::location($s),
            'verified' => $s->status === 'approved',
        ];
    }

    public static function location(?User $u): string
    {
        return $u ? collect([$u->municipality, $u->province])->filter()->join(', ') : '';
    }

    /** Variations grouped by type: [{name: Color, options: [{id, value, stock}]}]. */
    public static function variationGroups(Product $p): array
    {
        return $p->variations->groupBy('type')->map(fn (Collection $rows, string $type) => [
            'name'    => $type,
            'options' => $rows->map(fn ($v) => ['id' => $v->id, 'value' => $v->value, 'stock' => (int) $v->stock])->values(),
        ])->values()->all();
    }

    public static function review(Order $o): array
    {
        $buyer = $o->buyer;
        $name = $buyer ? trim($buyer->first_name . ' ' . mb_substr((string) $buyer->last_name, 0, 1) . '.') : 'Picksell buyer';

        return [
            'id'              => $o->id,
            'reviewer'        => $name,
            'rating'          => (int) $o->rating,
            'comment'         => $o->feedback,
            'variation_label' => $o->variation_label,
            'created_at'      => self::date($o->rated_at ?? $o->updated_at),
        ];
    }

    public static function address(BuyerAddress $a): array
    {
        return [
            'id'             => $a->id,
            'label'          => $a->label,
            'recipient_name' => $a->recipient_name,
            'phone'          => $a->phone,
            'province'       => $a->province,
            'municipality'   => $a->municipality,
            'barangay'       => $a->barangay,
            'street'         => $a->street,
            'house_no'       => $a->house_no,
            'postal_code'    => $a->postal_code,
            'landmark'       => $a->landmark,
            'full_address'   => $a->full_address,
            'is_default'     => $a->is_default,
        ];
    }

    public static function voucher(Voucher $v, ?float $eligibleSubtotal = null): array
    {
        $discount = $eligibleSubtotal === null ? null : $v->discountFor($eligibleSubtotal);

        return [
            'code'         => $v->code,
            'scope'        => $v->scope,
            'seller'       => $v->seller ? self::sellerBrief($v->seller) : null,
            'title'        => $v->title,
            'type'         => $v->type,
            'value'        => $v->value,
            'min_spend'    => $v->min_spend,
            'max_discount' => $v->max_discount,
            'is_limited'   => $v->is_limited,
            'expires_at'   => self::date($v->expires_at),
            'eligible'     => $discount === null ? null : $discount > 0,
            'discount'     => $discount,
        ];
    }

    public static function orderCard(Order $o): array
    {
        $status = $o->canonical_status;

        return [
            'id'              => $o->id,
            'order_number'    => $o->order_number,
            'checkout_ref'    => $o->checkout_ref,
            'status'          => $status,
            'tab'             => OrderStatus::tab($status),
            'seller'          => $o->seller ? self::sellerBrief($o->seller) : null,
            'product_id'      => $o->product_id,
            'product_name'    => $o->product_name,
            'image'           => self::image($o->product?->image),
            'variation_label' => $o->variation_label,
            'quantity'        => (int) $o->quantity,
            'unit_price'      => self::money($o->unit_price ?? ($o->quantity ? $o->amount / $o->quantity : $o->amount)),
            'total'           => self::money($o->total ?? $o->amount),
            'rating'          => $o->rating,
            'created_at'      => self::date($o->created_at),
        ];
    }

    public static function orderDetail(Order $o): array
    {
        $status = $o->canonical_status;
        $return = $o->returnRequest;
        $returnDays = (int) config('picksell.return_window_days');

        $canReturn = $status === OrderStatus::DELIVERED || $status === OrderStatus::COMPLETED;
        $canReturn = $canReturn && !$return && $o->delivered_at && $o->delivered_at->gt(now()->subDays($returnDays));

        return self::orderCard($o) + [
            'subtotal'          => self::money($o->subtotal ?? $o->amount),
            'discount'          => self::money($o->discount),
            'voucher_code'      => $o->voucher_code,
            'shipping_fee'      => self::money($o->shipping_fee),
            'service_fee'       => self::money($o->service_fee),
            'shipping_option'   => self::shippingOptionName($o->shipping_option),
            'estimated_delivery' => $o->estimated_delivery_from ? [
                'from' => $o->estimated_delivery_from->toDateString(),
                'to'   => $o->estimated_delivery_to?->toDateString(),
            ] : null,
            'payment_method'    => self::paymentMethodName($o->payment_method),
            'payment_status'    => $o->payment_status,
            'ship_to'           => $o->ship_to,
            'waybill_number'    => $o->waybill_number,
            'logistics'         => $o->logistics ? ['name' => $o->logistics->business_name ?: $o->logistics->full_name] : null,
            'courier'           => $o->courier ? [
                'name'         => $o->courier->full_name,
                'vehicle'      => trim(($o->courier->vehicle_type ?? '') . ($o->courier->plate_number ? ' · ' . $o->courier->plate_number : '')) ?: null,
                'phone'        => in_array($status, [OrderStatus::ASSIGNED_TO_RIDER, OrderStatus::OUT_FOR_DELIVERY, OrderStatus::DELIVERY_FAILED], true)
                    ? $o->courier->contact_no : null, // only while the rider is active on this order
            ] : null,
            'events'            => $o->events->map(fn ($e) => [
                'status'      => $e->status,
                'title'       => $e->title,
                'description' => $e->description,
                'location'    => $e->location,
                'occurred_at' => self::date($e->occurred_at),
            ])->values(),
            'feedback'          => $o->feedback,
            'cancel_reason'     => $o->cancel_reason,
            'cancelled_at'      => self::date($o->cancelled_at),
            'delivered_at'      => self::date($o->delivered_at),
            'return_request'    => $return ? self::returnRequest($return) : null,
            'actions'           => [
                'can_cancel'  => in_array($status, [OrderStatus::PLACED, OrderStatus::PREPARING], true),
                'can_rate'    => $status === OrderStatus::DELIVERED,
                'can_return'  => $canReturn,
                'can_report'  => $status !== OrderStatus::PLACED && $status !== OrderStatus::CANCELLED,
                'can_reorder' => in_array($status, [OrderStatus::DELIVERED, OrderStatus::COMPLETED, OrderStatus::CANCELLED, OrderStatus::RETURNED], true),
                'can_track'   => !in_array($status, [OrderStatus::CANCELLED], true),
            ],
        ];
    }

    public static function returnRequest(ReturnRequest $r): array
    {
        return [
            'id'            => $r->id,
            'status'        => $r->status,
            'quantity'      => $r->quantity,
            'reason'        => $r->reason,
            'details'       => $r->details,
            'refund_amount' => self::money($r->refund_amount),
            'refund_to'     => self::paymentMethodName($r->refund_to) ?? $r->refund_to,
            // Evidence lives on the private disk; only admins can open it.
            'evidence_count' => count($r->evidence_paths ?? []),
            'requested_at'  => self::date($r->created_at),
            'reviewed_at'   => self::date($r->reviewed_at),
            'processing_at' => self::date($r->processing_at),
            'refunded_at'   => self::date($r->refunded_at),
            'rejected_at'   => self::date($r->rejected_at),
            'resolution_note' => $r->resolution_note,
        ];
    }

    public static function shippingOptionName(?string $code): ?string
    {
        if (!$code) return null;
        return collect(config('picksell.shipping_options'))->firstWhere('code', $code)['name'] ?? $code;
    }

    public static function paymentMethodName(?string $code): ?string
    {
        if (!$code) return null;
        $legacy = ['bank_transfer' => 'Bank Transfer'];
        return collect(config('picksell.payment_methods'))->firstWhere('code', $code)['name'] ?? $legacy[$code] ?? $code;
    }
}
