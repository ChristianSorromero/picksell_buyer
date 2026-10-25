<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;

/** One delivery attempt: proof of delivery, or why it failed. Append-only. */
class DeliveryAttempt extends Model
{
    public $timestamps = false;

    protected $fillable = ['order_id', 'courier_id', 'outcome', 'reason', 'recipient_name', 'proof_photo_path', 'note', 'attempted_at'];

    protected $casts = ['attempted_at' => 'datetime'];

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Delivery attempts are append-only.'));
        static::deleting(fn () => throw new LogicException('Delivery attempts are append-only.'));
    }

    public function order()   { return $this->belongsTo(Order::class); }
    public function courier() { return $this->belongsTo(User::class, 'courier_id'); }
}
