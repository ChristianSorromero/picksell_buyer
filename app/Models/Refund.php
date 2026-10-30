<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Refund decisions made by admins on the website; read-only for the app. */
class Refund extends Model
{
    protected $casts = [
        'amount' => 'decimal:2',
        'approved_at' => 'datetime',
        'processed_at' => 'datetime',
    ];

    public function order() { return $this->belongsTo(Order::class); }
    public function returnRequest() { return $this->belongsTo(ReturnRequest::class); }
}
