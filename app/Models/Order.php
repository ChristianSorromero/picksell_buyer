<?php

namespace App\Models;

use App\Support\Money;
use App\Support\OrderStatus;
use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    protected $fillable = [
        'order_number', 'checkout_ref', 'product_id', 'buyer_id', 'seller_id', 'logistics_id', 'courier_id',
        'product_name', 'quantity', 'variation_label', 'variation_ids',
        'unit_price', 'subtotal', 'discount', 'voucher_code', 'shipping_fee', 'service_fee', 'total',
        'amount', 'commission', 'status',
        'shipping_option', 'estimated_delivery_from', 'estimated_delivery_to',
        'payment_method', 'payment_status', 'ship_to',
        'cod_collected_at', 'cod_collected_by', 'paid_at', 'payment_confirmed_by', 'settled_at',
        'waybill_number', 'tracking_status',
        'packed_at', 'handed_over_at', 'delivered_at', 'cancelled_at', 'cancel_reason',
        'rating', 'feedback', 'rated_at',
    ];

    protected $casts = [
        'packed_at'               => 'datetime',
        'handed_over_at'          => 'datetime',
        'delivered_at'            => 'datetime',
        'cancelled_at'            => 'datetime',
        'rated_at'                => 'datetime',
        'estimated_delivery_from' => 'date',
        'estimated_delivery_to'   => 'date',
        'variation_ids'           => 'array',
        'ship_to'                 => 'array',
        'cod_collected_at'        => 'datetime',
        'paid_at'                 => 'datetime',
        'settled_at'              => 'datetime',
    ];

    /** unpaid → collected (rider has the cash) → paid (cash handed in) → partially_/refunded */
    public const PAYMENT_STATUSES = ['unpaid', 'collected', 'paid', 'partially_refunded', 'refunded'];

    protected static function booted(): void
    {
        // Every status change made anywhere (mobile API, seller, logistics,
        // courier or admin dashboards) lands in the tracking history.
        static::created(fn (Order $order) => $order->recordEvent());

        static::updated(function (Order $order) {
            if ($order->wasChanged(['status', 'tracking_status', 'courier_id', 'rating'])) {
                $order->recordEvent();
            }
        });
    }

    public function buyer()         { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller()        { return $this->belongsTo(User::class, 'seller_id'); }
    public function logistics()     { return $this->belongsTo(User::class, 'logistics_id'); }
    public function courier()       { return $this->belongsTo(User::class, 'courier_id'); }
    public function product()       { return $this->belongsTo(Product::class); }
    public function events()        { return $this->hasMany(OrderEvent::class)->orderBy('occurred_at')->orderBy('id'); }
    public function returnRequest() { return $this->hasOne(ReturnRequest::class); }
    public function auditLogs()     { return $this->morphMany(AuditLog::class, 'subject')->latest('id'); }
    public function collectedBy()   { return $this->belongsTo(User::class, 'cod_collected_by'); }

    /** What the buyer pays in cash for this order, in centavos. */
    public function totalCents(): int
    {
        return $this->total !== null
            ? Money::cents($this->total)
            : Money::cents($this->amount) + Money::cents($this->shipping_fee) + Money::cents($this->service_fee);
    }

    public function isCod(): bool
    {
        return in_array($this->payment_method, [null, 'cod'], true);
    }

    public function getCanonicalStatusAttribute(): string
    {
        return OrderStatus::of($this);
    }

    /**
     * Where the parcel goes: the address chosen at checkout (ship_to), or
     * the buyer's profile address for older web orders without one.
     */
    public function getDeliveryAttribute(): array
    {
        if ($ship = $this->ship_to) {
            return [
                'name'     => $ship['recipient_name'] ?? null,
                'phone'    => $ship['phone'] ?? null,
                'address'  => $ship['full_address'] ?? null,
                'landmark' => $ship['landmark'] ?? null,
                'barangay' => $ship['barangay'] ?? null,
                'area'     => collect([$ship['municipality'] ?? null, $ship['province'] ?? null])->filter()->join(', ') ?: 'Unspecified area',
            ];
        }

        $buyer = $this->buyer;
        return [
            'name'     => $buyer?->full_name,
            'phone'    => $buyer?->contact_no,
            'address'  => collect([$buyer?->house_no, $buyer?->street, $buyer?->barangay, $buyer?->municipality, $buyer?->province])->filter()->join(', ') ?: null,
            'landmark' => null,
            'barangay' => $buyer?->barangay,
            'area'     => collect([$buyer?->municipality, $buyer?->province])->filter()->join(', ') ?: 'Unspecified area',
        ];
    }

    /** Appends a tracking event unless the canonical state didn't move. */
    public function recordEvent(?string $status = null, ?string $description = null): void
    {
        $status ??= $this->canonical_status;
        $last = $this->events()->reorder()->latest('occurred_at')->latest('id')->first();
        if ($last && $last->status === $status) return;

        [$title, $defaultDescription] = OrderStatus::EVENTS[$status] ?? [ucfirst(str_replace('_', ' ', $status)), null];

        $location = null;
        if ($status === OrderStatus::ASSIGNED_TO_RIDER && $this->tracking_status) {
            // "Sorted for {area}; assigned to {rider}"
            $location = trim((string) str($this->tracking_status)->after('Sorted for')->before(';')) ?: null;
        }

        $this->events()->create([
            'status'      => $status,
            'title'       => $title,
            'description' => $description ?? ($status === OrderStatus::CANCELLED && $this->cancel_reason
                ? 'Cancelled: ' . $this->cancel_reason . '.'
                : $defaultDescription),
            'location'    => $location,
            'occurred_at' => now(),
        ]);
    }
}
