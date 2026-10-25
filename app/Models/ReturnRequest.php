<?php

namespace App\Models;

use App\Support\Money;
use Illuminate\Database\Eloquent\Model;

/**
 * A return/refund case: admin reviews first, then the seller resolves it
 * with the buyer; disagreements go back to admin. App\Services\ReturnWorkflow
 * is the only place that moves it between states.
 */
class ReturnRequest extends Model
{
    public const REQUESTED      = 'requested';       // waiting for admin review
    public const INFO_REQUESTED = 'info_requested';  // admin asked the buyer for more
    public const WITH_SELLER    = 'with_seller';     // admin approved; seller to propose
    public const PROPOSED       = 'proposed';        // seller proposed; buyer to accept or decline
    public const ESCALATED      = 'escalated';       // no agreement; admin decides
    public const RESOLVED       = 'resolved';        // outcome fixed; refund/return steps pending
    public const COMPLETED      = 'completed';
    public const REJECTED       = 'rejected';

    public const CLOSED = [self::COMPLETED, self::REJECTED];

    /** Resolution types: [label, requires the item back, refund rule]. */
    public const RESOLUTIONS = [
        'return_and_refund' => ['Return item for a refund', true, 'up_to_max'],
        'full_refund'       => ['Full refund (keep the item)', false, 'max'],
        'partial_refund'    => ['Partial refund (keep the item)', false, 'below_max'],
        'replacement'       => ['Replacement', true, 'none'],
    ];

    public const STAGE_LABELS = [
        self::REQUESTED      => 'Waiting for Picksell review',
        self::INFO_REQUESTED => 'More information needed from you',
        self::WITH_SELLER    => 'With the seller',
        self::PROPOSED       => 'Seller proposed a resolution',
        self::ESCALATED      => 'Picksell is deciding',
        self::RESOLVED       => 'Resolution agreed — in progress',
        self::COMPLETED      => 'Completed',
        self::REJECTED       => 'Rejected',
    ];

    protected $fillable = [
        'order_id', 'buyer_id', 'quantity', 'reason', 'details', 'evidence_paths',
        'refund_amount', 'refund_to', 'status', 'resolution_type', 'resolution_amount', 'requires_item_return',
        'reviewed_at', 'processing_at', 'refunded_at', 'rejected_at', 'resolution_note',
        'info_request', 'seller_note', 'refund_courier_id', 'admin_approved_at', 'proposed_at', 'escalated_at',
        'resolved_at', 'refund_released_at', 'item_collected_at', 'item_received_at', 'restocked',
        'replacement_sent_at', 'completed_at',
        'refund_timing', 'expedited_by', 'expedited_reason', 'liable_party', 'refund_funded_by', 'liability_note',
        'liability_set_by', 'pickup_courier_id', 'pickup_assigned_at', 'inspection_passed', 'inspection_note',
    ];

    /** Who caused the problem (admin's determination); see config picksell.returns. */
    public const LIABLE_PARTIES = [
        'seller'       => 'Seller (wrong, defective or not-as-described item)',
        'logistics'    => 'Logistics / courier (damaged or lost in delivery)',
        'buyer'        => 'Buyer (change of mind or misuse)',
        'platform'     => 'Picksell (platform error)',
        'undetermined' => 'Undetermined — under review',
    ];

    /** When the refund cash may go out. */
    public const TIMING_LABELS = [
        'after_inspection' => 'After the seller receives and inspects the item',
        'on_pickup'        => 'On pickup (expedited by admin)',
        'no_return'        => 'Right away (buyer keeps the item)',
    ];

    protected $casts = [
        'evidence_paths'       => 'array',
        'refund_amount'        => 'float',
        'requires_item_return' => 'boolean',
        'restocked'            => 'boolean',
        'reviewed_at'          => 'datetime',
        'processing_at'        => 'datetime',
        'refunded_at'          => 'datetime',
        'rejected_at'          => 'datetime',
        'admin_approved_at'    => 'datetime',
        'proposed_at'          => 'datetime',
        'escalated_at'         => 'datetime',
        'resolved_at'          => 'datetime',
        'refund_released_at'   => 'datetime',
        'item_collected_at'    => 'datetime',
        'item_received_at'     => 'datetime',
        'replacement_sent_at'  => 'datetime',
        'completed_at'         => 'datetime',
        'pickup_assigned_at'   => 'datetime',
        'inspection_passed'    => 'boolean',
    ];

    public function order()         { return $this->belongsTo(Order::class); }
    public function buyer()         { return $this->belongsTo(User::class, 'buyer_id'); }
    public function refundCourier() { return $this->belongsTo(User::class, 'refund_courier_id'); }
    public function pickupCourier() { return $this->belongsTo(User::class, 'pickup_courier_id'); }
    public function auditLogs()     { return $this->morphMany(AuditLog::class, 'subject')->latest('id'); }

    public function isOpen(): bool { return !in_array($this->status, self::CLOSED, true); }

    /** Agreed or proposed refund, in centavos. */
    public function resolutionCents(): int { return Money::cents($this->resolution_amount); }

    public function needsRefundHandover(): bool
    {
        return $this->status === self::RESOLVED && $this->resolutionCents() > 0 && !$this->refunded_at;
    }

    public function needsItemReceipt(): bool
    {
        return $this->status === self::RESOLVED && $this->requires_item_return && !$this->item_received_at;
    }

    /** The item must still be picked up from the buyer by a rider (not on the refund visit). */
    public function needsPickup(): bool
    {
        return $this->status === self::RESOLVED && $this->requires_item_return && !$this->item_collected_at
            && $this->refund_timing !== 'on_pickup';
    }

    /** Why the refund cash can't be released yet, or null when it can. */
    public function refundBlocker(): ?string
    {
        $order = $this->order;
        return match (true) {
            !$this->needsRefundHandover()                   => 'This return has no refund waiting to be paid.',
            $this->refund_released_at !== null              => 'The refund cash was already given to a rider.',
            $this->refund_funded_by === null                => 'Responsibility for this refund has not been decided yet.',
            $order->payment_review === 'unverifiable'       => 'The buyer’s original payment could not be verified; reconcile it first.',
            !in_array($order->payment_status, ['paid', 'partially_refunded'], true)
                                                            => 'The buyer’s cash for this order has not been handed in yet, so it can’t be refunded.',
            $this->refund_timing === 'after_inspection' && !$this->item_received_at
                                                            => 'Waiting for the seller to receive and inspect the returned item.',
            $this->refund_timing === 'after_inspection' && $this->inspection_passed !== true
                                                            => 'The item did not pass inspection; Picksell must decide first.',
            default                                         => null,
        };
    }

    /** Every operational and financial step of the agreed outcome is done. */
    public function stepsComplete(): bool
    {
        return ($this->resolutionCents() === 0 || $this->refunded_at !== null)
            && (!$this->requires_item_return || $this->item_received_at !== null)
            && ($this->resolution_type !== 'replacement' || $this->replacement_sent_at !== null);
    }
}
