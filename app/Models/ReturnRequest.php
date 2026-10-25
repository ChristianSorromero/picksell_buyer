<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ReturnRequest extends Model
{
    protected $fillable = [
        'order_id', 'buyer_id', 'quantity', 'reason', 'details', 'evidence_paths',
        'refund_amount', 'refund_to', 'status',
        'reviewed_at', 'processing_at', 'refunded_at', 'rejected_at', 'resolution_note',
    ];

    protected $casts = [
        'evidence_paths' => 'array',
        'refund_amount'  => 'float',
        'reviewed_at'    => 'datetime',
        'processing_at'  => 'datetime',
        'refunded_at'    => 'datetime',
        'rejected_at'    => 'datetime',
    ];

    public function order() { return $this->belongsTo(Order::class); }
}
