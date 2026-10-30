<?php

namespace App\Support;

use App\Models\Order;
use App\Models\Pickrush\Parcel;
use App\Models\Product;
use App\Models\ProductReview;
use App\Models\ReturnRequest;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Storage;

/**
 * JSON shapes returned by the mobile buyer API, built from the shared Picksell tables. Keep in
 * sync with the Dart models in lib/models/.
 */
final class BuyerPresenter
{
    /** Public URL of a file on the website's public storage. */
    public static function image(?string $path): ?string
    {
        if (! $path) return null;

        return str_starts_with($path, 'http') ? $path : Storage::disk('public')->url(ltrim($path, '/'));
    }

    public static function money(float|string|null $v): float
    {
        return round((float) $v, 2);
    }

    public static function date(?Carbon $d): ?string
    {
        return $d?->toIso8601String();
    }

    /** Card-sized product. Load `seller`, and for ratings withAvg('reviews', 'rating') + withCount('reviews'). */
    public static function product(Product $p, array $wishlistIds = []): array
    {
        $hasDiscount = $p->discount > 0;
        $images = $p->images->map(fn ($image) => $image->url)->values()->all();

        return [
            'id'               => $p->id,
            'name'             => $p->name,
            'category'         => $p->category ?? '',
            'price'            => self::money($p->effective_price),
            'original_price'   => $hasDiscount ? self::money($p->price) : null,
            'discount_percent' => $hasDiscount ? (int) round($p->discount) : null,
            'stock'            => (int) $p->stock,
            'image'            => self::image($p->primary_image),
            'images'           => $images,
            'rating'           => $p->reviews_avg_rating !== null ? round((float) $p->reviews_avg_rating, 1) : null,
            'review_count'     => (int) ($p->reviews_count ?? 0),
            'sold_count'       => (int) ($p->sold_count ?? 0),
            'is_featured'      => (bool) $p->is_featured,
            'is_available'     => $p->isPurchasable() && $p->stock > 0,
            'wishlisted'       => in_array($p->id, $wishlistIds, true),
            'voucher_code'     => $p->voucher_code,
            'voucher_discount' => $p->voucher_code ? (float) $p->voucher_discount : null,
            'seller'           => $p->relationLoaded('seller') && $p->seller ? self::sellerBrief($p->seller) : null,
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

    public static function review(ProductReview $r): array
    {
        $buyer = $r->buyer;

        return [
            'id'         => $r->id,
            'reviewer'   => $buyer ? trim($buyer->first_name.' '.mb_substr((string) $buyer->last_name, 0, 1).'.') : 'PickSell buyer',
            'rating'     => (int) $r->rating,
            'comment'    => $r->body,
            'created_at' => self::date($r->created_at),
        ];
    }

    /** The buyer's profile address, where the website books every parcel. */
    public static function deliveryAddress(User $u): array
    {
        return [
            'recipient_name' => $u->full_name,
            'phone'          => $u->contact_no,
            'province'       => $u->province,
            'municipality'   => $u->municipality,
            'barangay'       => $u->barangay,
            'street'         => $u->street,
            'house_no'       => $u->house_no,
            'full_address'   => collect([$u->house_no, $u->street, $u->barangay, $u->municipality, $u->province])->filter(fn ($part) => filled($part))->join(', '),
            'complete'       => filled($u->province) && filled($u->municipality) && filled($u->barangay),
        ];
    }

    public static function orderCard(Order $o): array
    {
        $quantity = max((int) $o->quantity, 1);

        return [
            'id'              => $o->id,
            'order_number'    => $o->order_number,
            'status'          => OrderStatus::of($o),
            'tab'             => OrderStatus::tab($o),
            'seller'          => $o->seller ? self::sellerBrief($o->seller) : null,
            'product_id'      => $o->product_id,
            'product_name'    => $o->product_name,
            'image'           => self::image($o->product?->primary_image),
            'quantity'        => (int) $o->quantity,
            'unit_price'      => self::money($o->amount / $quantity),
            'total'           => self::money($o->amount),
            'rating'          => $o->rating,
            'created_at'      => self::date($o->created_at),
        ];
    }

    public static function orderDetail(Order $o): array
    {
        $status = OrderStatus::of($o);
        $return = $o->returnRequest;
        $parcel = Parcel::forOrder($o);
        $cancellation = $status === 'cancelled' ? $o->statusHistories->last(fn ($h) => $h->to_status === 'cancelled') : null;

        return self::orderCard($o) + [
            'subtotal'          => self::money($o->amount),
            'discount'          => 0.0,
            'shipping_fee'      => 0.0,
            'service_fee'       => 0.0,
            'payment_method'    => 'Cash on Delivery',
            'cod_amount'        => self::money($o->amount),
            'ship_to'           => $o->buyer ? self::deliveryAddress($o->buyer) : null,
            'waybill_number'    => $parcel?->tracking_no ?? $o->waybill_number,
            'logistics'         => $parcel ? ['name' => 'Pickrush'] : null,
            'tracking_status'   => $o->tracking_status,
            'events'            => self::timeline($o),
            'tracking'          => $parcel ? self::tracking($parcel) : null,
            'feedback'          => $o->feedback,
            'cancel_reason'     => $cancellation?->reason,
            'cancelled_at'      => self::date($cancellation?->created_at),
            'delivered_at'      => self::date($o->delivered_at),
            'return_request'    => $return ? self::returnRequest($return) : null,
            'actions'           => [
                'can_cancel'  => in_array($status, OrderStatus::CANCELLABLE, true),
                'can_rate'    => in_array($status, OrderStatus::RATEABLE, true) && ! $o->rating,
                'can_return'  => in_array($status, OrderStatus::RATEABLE, true) && ! $return,
                'can_report'  => ! in_array($status, ['placed', 'cancelled'], true),
                'can_reorder' => in_array($status, ['delivered', 'completed', 'cancelled', 'returned'], true),
                'can_track'   => $status !== 'cancelled',
            ],
        ];
    }

    /** Order steps from the status history (or, for older orders, the step timestamps). */
    public static function timeline(Order $o): array
    {
        $steps = $o->statusHistories->map(fn ($h) => [OrderStatus::LEGACY[$h->to_status] ?? $h->to_status, $h->created_at, $h->reason]);
        if ($steps->isEmpty()) {
            $steps = collect(\App\Services\Orders\OrderLifecycleService::TIMESTAMPS)
                ->map(fn ($column, $status) => [$status, $o->{$column}, null])
                ->filter(fn ($step) => $step[1] !== null)
                ->prepend(['placed', $o->created_at, null])
                ->values();
        }

        return $steps->map(fn ($step) => [
            'status'      => $step[0],
            'title'       => OrderStatus::EVENTS[$step[0]][0] ?? ucfirst(str_replace('_', ' ', $step[0])),
            'description' => $step[0] === 'cancelled' && $step[2] ? "Reason: {$step[2]}" : (OrderStatus::EVENTS[$step[0]][1] ?? null),
            'location'    => null,
            'occurred_at' => self::date($step[1]),
        ])->values()->all();
    }

    /** Pickrush scans for the parcel, newest first (what the website's tracking page shows). */
    public static function tracking(Parcel $parcel): array
    {
        $parcel->load('events.hub', 'events.toHub');

        return [
            'tracking_no' => $parcel->tracking_no,
            'status'      => ucfirst(str_replace('_', ' ', (string) $parcel->current_status)),
            'events'      => $parcel->events->reverse()->values()->map(fn ($event) => [
                'headline' => $event->headline(),
                'location' => $event->hub?->name,
                'at'       => self::date($event->occurred_at),
            ])->all(),
        ];
    }

    /** A website return request in the app's five-stage shape; `stage` keeps the website step. */
    public static function returnRequest(ReturnRequest $r): array
    {
        $stage = match ($r->status) {
            'requested' => 'requested',
            'awaiting_item', 'received', 'inspected' => 'under_review',
            'approved_for_refund', 'refund_due' => 'processing',
            'completed' => 'refunded',
            'rejected' => 'rejected',
            default => 'under_review',
        };

        return [
            'id'            => $r->id,
            'status'        => $stage,
            'stage'         => $r->status,
            'stage_label'   => self::returnStageLabel($r),
            'quantity'      => (int) $r->quantity,
            'reason'        => ReturnRequest::REASONS[$r->reason] ?? $r->reason,
            'details'       => $r->details,
            'refund_amount' => self::money($r->refund?->amount ?? $r->refund_amount),
            'refund_to'     => 'Handled by PickSell support',
            'seller_note'   => $r->seller_note,
            'tracking'      => $r->status === 'awaiting_item' && $r->tracking_number
                ? ['carrier' => $r->carrier, 'number' => $r->tracking_number, 'status' => $r->tracking_status]
                : null,
            'requested_at'  => self::date($r->created_at),
            'reviewed_at'   => self::date($r->approved_at ?? $r->reviewed_at),
            'processing_at' => self::date($r->refund_due_at ?? $r->admin_resolved_at),
            'refunded_at'   => self::date($r->status === 'completed' ? $r->completed_at : null),
            'rejected_at'   => self::date($r->rejected_at),
            'completed_at'  => self::date($r->completed_at),
            'resolution_note' => $r->admin_decision ?: $r->admin_notes,
        ];
    }

    public static function returnStageLabel(ReturnRequest $r): string
    {
        return match ($r->status) {
            'requested' => 'Waiting for the seller to review your request',
            'awaiting_item' => 'Approved: send the item back to the seller',
            'received' => 'The seller received the item; PickSell is inspecting it',
            'inspected' => 'Inspected; waiting for refund approval',
            'approved_for_refund' => 'Refund approved',
            'refund_due' => 'Refund on its way',
            'completed' => 'Refund completed',
            'rejected' => $r->dispute_status === 'open'
                ? 'The seller declined; PickSell support is reviewing it'
                : 'Request declined',
            default => ucfirst(str_replace('_', ' ', $r->status)),
        };
    }
}
