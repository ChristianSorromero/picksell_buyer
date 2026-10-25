<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;

/** One side of a ledger transaction, in centavos (debit +, credit −). */
class LedgerEntry extends Model
{
    public $timestamps = false;

    protected $fillable = ['ledger_transaction_id', 'account', 'user_id', 'order_id', 'amount_cents'];

    protected $casts = ['amount_cents' => 'integer'];

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Ledger records are append-only; post a reversal instead.'));
        static::deleting(fn () => throw new LogicException('Ledger records are append-only; post a reversal instead.'));
    }

    public function transaction() { return $this->belongsTo(LedgerTransaction::class, 'ledger_transaction_id'); }
    public function user()        { return $this->belongsTo(User::class); }
    public function payoutItem()  { return $this->hasOne(PayoutItem::class); }
}
