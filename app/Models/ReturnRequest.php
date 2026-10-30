<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A buyer's return/refund request, decided on the website: the seller approves or rejects it,
 * a rejection opens an admin dispute, and admins inspect and approve the refund.
 */
class ReturnRequest extends Model
{
    public const STATUSES = [
        'requested',
        'awaiting_item',
        'received',
        'inspected',
        'approved_for_refund',
        'refund_due',
        'completed',
        'rejected',
    ];

    /** The website's reasons (stored value => label). */
    public const REASONS = [
        'damaged' => 'Damaged item',
        'wrong_item' => 'Wrong item received',
        'wrong_size' => 'Wrong size',
        'not_as_described' => 'Not as described',
        'other' => 'Other',
    ];

    protected $fillable = [
        'order_id', 'buyer_id', 'seller_id', 'reason', 'details', 'status',
        'quantity', 'refund_amount', 'attachments',
    ];

    protected $casts = [
        'approved_at' => 'datetime',
        'rejected_at' => 'datetime',
        'received_at' => 'datetime',
        'refund_due_at' => 'datetime',
        'completed_at' => 'datetime',
        'admin_resolved_at' => 'datetime',
        'refund_amount' => 'decimal:2',
        'attachments' => 'array',
        'tracking_updated_at' => 'datetime',
        'reviewed_at' => 'datetime',
    ];

    public function order()  { return $this->belongsTo(Order::class); }
    public function buyer()  { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller() { return $this->belongsTo(User::class, 'seller_id'); }

    public function events()
    {
        return $this->hasMany(ReturnRequestEvent::class)->oldest()->oldest('id');
    }

    public function refund()
    {
        return $this->hasOne(Refund::class)->latestOfMany();
    }
}
