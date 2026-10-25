<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;

/** One money movement; its entries sum to zero. Append-only. */
class LedgerTransaction extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['type', 'idempotency_key', 'order_id', 'return_request_id', 'payout_id', 'actor_id', 'memo'];

    protected $casts = ['created_at' => 'datetime'];

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Ledger records are append-only; post a reversal instead.'));
        static::deleting(fn () => throw new LogicException('Ledger records are append-only; post a reversal instead.'));
    }

    public function entries()       { return $this->hasMany(LedgerEntry::class); }
    public function order()         { return $this->belongsTo(Order::class); }
    public function returnRequest() { return $this->belongsTo(ReturnRequest::class); }
    public function actor()         { return $this->belongsTo(User::class, 'actor_id'); }
}
