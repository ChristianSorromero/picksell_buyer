<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;

/** Who did what to a payment, return case or payout, and when. Append-only. */
class AuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['subject_type', 'subject_id', 'actor_id', 'actor_role', 'action', 'from_status', 'to_status', 'amount_cents', 'note'];

    protected $casts = ['created_at' => 'datetime'];

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Audit records are append-only.'));
        static::deleting(fn () => throw new LogicException('Audit records are append-only.'));
    }

    public function subject() { return $this->morphTo(); }
    public function actor()   { return $this->belongsTo(User::class, 'actor_id'); }

    public static function record(Model $subject, string $action, ?string $from = null, ?string $to = null, ?string $note = null, ?int $amountCents = null, ?User $actor = null): self
    {
        $actor ??= auth()->user();

        return self::create([
            'subject_type' => $subject->getMorphClass(),
            'subject_id'   => $subject->getKey(),
            'actor_id'     => $actor?->id,
            'actor_role'   => $actor?->role,
            'action'       => $action,
            'from_status'  => $from,
            'to_status'    => $to,
            'amount_cents' => $amountCents,
            'note'         => $note,
        ]);
    }
}
