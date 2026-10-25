<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One payable line in a payout; unique per line, so it can't be paid twice. */
class PayoutItem extends Model
{
    public $timestamps = false;

    protected $fillable = ['payout_id', 'ledger_entry_id', 'amount_cents'];

    protected $casts = ['amount_cents' => 'integer'];

    public function payout() { return $this->belongsTo(Payout::class); }
    public function entry()  { return $this->belongsTo(LedgerEntry::class, 'ledger_entry_id'); }
}
