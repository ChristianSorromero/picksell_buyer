<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Voucher extends Model
{
    protected $fillable = [
        'code', 'scope', 'seller_id', 'type', 'value', 'min_spend', 'max_discount',
        'usage_limit', 'is_limited', 'starts_at', 'expires_at', 'active',
    ];

    protected $casts = [
        'value'        => 'float',
        'min_spend'    => 'float',
        'max_discount' => 'float',
        'is_limited'   => 'boolean',
        'active'       => 'boolean',
        'starts_at'    => 'datetime',
        'expires_at'   => 'datetime',
    ];

    public function seller() { return $this->belongsTo(User::class, 'seller_id'); }

    public function scopeLive($query)
    {
        return $query->where('active', true)
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>=', now()));
    }

    public function timesUsed(): int
    {
        return Order::where('voucher_code', $this->code)->where('status', '!=', 'cancelled')
            ->distinct('checkout_ref')->count('checkout_ref');
    }

    public function isExhausted(): bool
    {
        return $this->usage_limit !== null && $this->timesUsed() >= $this->usage_limit;
    }

    /** Discount for an eligible [subtotal]; 0 when min spend isn't met. */
    public function discountFor(float $subtotal): float
    {
        if ($subtotal <= 0 || $subtotal < $this->min_spend) return 0;
        $discount = $this->type === 'percent' ? $subtotal * $this->value / 100 : $this->value;
        if ($this->max_discount) $discount = min($discount, $this->max_discount);
        return round(min($discount, $subtotal), 2);
    }

    /** "₱50 Off" / "5% Off" */
    public function getTitleAttribute(): string
    {
        return $this->type === 'percent'
            ? rtrim(rtrim(number_format($this->value, 2), '0'), '.') . '% Off'
            : '₱' . number_format($this->value, $this->value == floor($this->value) ? 0 : 2) . ' Off';
    }
}
