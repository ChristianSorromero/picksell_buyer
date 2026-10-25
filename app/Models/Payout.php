<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A manual disbursement to a seller or rider, made by an admin outside the
 * system (bank or e-wallet transfer) and recorded here with its reference.
 */
class Payout extends Model
{
    public const STATUSES = ['pending', 'approved', 'processing', 'completed', 'failed', 'cancelled'];
    public const ACTIVE = ['pending', 'approved', 'processing'];

    protected $fillable = [
        'payee_id', 'payee_role', 'period_start', 'period_end', 'amount_cents', 'status', 'method', 'reference',
        'failure_reason', 'created_by', 'approved_by', 'approved_at', 'processing_at', 'completed_by', 'completed_at',
        'failed_at', 'cancelled_at',
    ];

    protected $casts = [
        'amount_cents'  => 'integer',
        'period_start'  => 'date',
        'period_end'    => 'date',
        'approved_at'   => 'datetime',
        'processing_at' => 'datetime',
        'completed_at'  => 'datetime',
        'failed_at'     => 'datetime',
        'cancelled_at'  => 'datetime',
    ];

    public function payee()     { return $this->belongsTo(User::class, 'payee_id'); }
    public function items()     { return $this->hasMany(PayoutItem::class); }
    public function auditLogs() { return $this->morphMany(AuditLog::class, 'subject')->latest('id'); }
}
