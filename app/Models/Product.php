<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A row of the shared Picksell `products` table (sellers manage it on the website). */
class Product extends Model
{
    protected $fillable = [
        'seller_id', 'name', 'description', 'category',
        'price', 'discount', 'voucher_code', 'voucher_discount',
        'stock', 'is_featured', 'status',
    ];

    protected $casts = ['is_featured' => 'boolean'];

    protected $with = ['images'];

    public function seller()     { return $this->belongsTo(User::class, 'seller_id'); }
    public function orders()     { return $this->hasMany(Order::class); }
    public function variations() { return $this->hasMany(ProductVariation::class); }
    public function reviews()    { return $this->hasMany(ProductReview::class); }
    public function images()     { return $this->hasMany(ProductImage::class)->orderBy('display_order')->orderBy('id'); }

    /** Products that may enter new orders: active, and sold by an approved seller (website rule). */
    public function scopePurchasable($query)
    {
        return $query->where('status', 'active')->whereHas('seller', fn ($seller) => $seller->where('status', 'approved'));
    }

    public function isPurchasable(): bool
    {
        return $this->status === 'active' && $this->seller?->status === 'approved';
    }

    public function getEffectivePriceAttribute(): float
    {
        return $this->price * (1 - $this->discount / 100);
    }

    /** Storage path of the primary image (falls back to the first image), or null. */
    public function getPrimaryImageAttribute(): ?string
    {
        $image = $this->images->firstWhere('is_primary', true) ?? $this->images->first();

        return $image?->image_url;
    }
}
