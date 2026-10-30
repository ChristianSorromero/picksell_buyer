<?php

namespace App\Models;

use App\Services\AdminNotificationService;
use App\Services\Orders\OrderLifecycleService;
use Illuminate\Database\Eloquent\Model;

/**
 * A row of the shared Picksell `orders` table. `status` is the website's lifecycle step (see
 * OrderLifecycleService). Status changes are recorded exactly as the website records them.
 */
class Order extends Model
{
    protected $fillable = [
        'order_number', 'product_id', 'buyer_id', 'seller_id',
        'product_name', 'quantity', 'amount', 'commission', 'commission_rate', 'status',
        'waybill_number', 'tracking_status',
        'packed_at', 'handed_over_at', 'delivered_at', 'confirmed_by_seller_at',
        'confirmed_at', 'preparing_at', 'ready_for_pickup_at', 'picked_up_at', 'sorting_received_at',
        'sorted_at', 'assigned_to_rider_at', 'out_for_delivery_at', 'completed_at',
        'rating', 'feedback',
    ];

    protected $casts = [
        'commission_rate' => 'decimal:2',
        'packed_at' => 'datetime',
        'handed_over_at' => 'datetime',
        'delivered_at' => 'datetime',
        'confirmed_by_seller_at' => 'datetime',
        'confirmed_at' => 'datetime',
        'preparing_at' => 'datetime',
        'ready_for_pickup_at' => 'datetime',
        'picked_up_at' => 'datetime',
        'sorting_received_at' => 'datetime',
        'sorted_at' => 'datetime',
        'assigned_to_rider_at' => 'datetime',
        'out_for_delivery_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    /** Context for the next status change (not persisted on orders); see OrderLifecycleService. */
    public ?int $statusChangedBy = null;
    public ?string $statusChangeSource = null;
    public ?string $statusChangeReason = null;

    /**
     * Mirrors the website's Order::booted(): every status change stamps its lifecycle timestamp
     * (first time only) and writes an order_status_histories row.
     */
    protected static function booted(): void
    {
        static::saving(function (Order $order): void {
            $column = OrderLifecycleService::TIMESTAMPS[$order->status] ?? null;
            if ($order->isDirty('status') && $column && $order->{$column} === null) {
                $order->{$column} = now();
            }
        });

        static::created(fn (Order $order) => $order->recordStatusChange(null));

        static::updated(function (Order $order): void {
            if ($order->wasChanged('status')) {
                $order->recordStatusChange($order->getOriginal('status'));
                if ($order->status === 'delivery_failed') {
                    app(AdminNotificationService::class)->notifyAdmins(
                        'delivery.failed',
                        'Delivery failed',
                        "Delivery failed for order {$order->order_number}.",
                        "/admin/orders/{$order->id}",
                        priority: 'critical',
                    );
                }
            }
        });
    }

    private function recordStatusChange(?string $from): void
    {
        $actor = auth()->user();
        OrderStatusHistory::create([
            'order_id' => $this->id,
            'changed_by' => $this->statusChangedBy ?? $actor?->id,
            'source' => $this->statusChangeSource ?? ($actor?->role ?? 'system'),
            'from_status' => $from,
            'to_status' => $this->status,
            'reason' => $this->statusChangeReason,
        ]);
        $this->statusChangedBy = $this->statusChangeSource = $this->statusChangeReason = null;
    }

    public function buyer()   { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller()  { return $this->belongsTo(User::class, 'seller_id'); }
    public function product() { return $this->belongsTo(Product::class); }

    public function returnRequest()
    {
        return $this->hasOne(ReturnRequest::class);
    }

    public function review()
    {
        return $this->hasOne(ProductReview::class);
    }

    public function statusHistories()
    {
        return $this->hasMany(OrderStatusHistory::class)->oldest()->oldest('id');
    }
}
