<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = [
        'seller_id', 'name', 'description', 'category',
        'price', 'discount', 'voucher_code', 'voucher_discount',
        'stock', 'image', 'is_featured', 'status',
    ];

    protected $casts = ['is_featured' => 'boolean'];

    public function seller()     { return $this->belongsTo(User::class, 'seller_id'); }
    public function orders()     { return $this->hasMany(Order::class); }
    public function variations() { return $this->hasMany(ProductVariation::class); }
    public function cartItems()  { return $this->hasMany(CartItem::class); }
    public function wishlistedBy() { return $this->hasMany(WishlistItem::class); }

    /** Rated, non-cancelled orders double as product reviews. */
    public function reviews()
    {
        return $this->hasMany(Order::class)->whereNotNull('rating')->where('status', '!=', 'cancelled');
    }

    /** Adds reviews_avg_rating, reviews_count and sold_count for the API. */
    public function scopeWithStats($query)
    {
        return $query
            ->withAvg('reviews', 'rating')
            ->withCount('reviews')
            ->withSum(['orders as sold_count' => fn ($q) => $q->where('status', '!=', 'cancelled')], 'quantity');
    }

    public function scopeBuyable($query)
    {
        return $query->where('status', 'active')->where('stock', '>', 0);
    }

    public function getEffectivePriceAttribute(): float
    {
        return $this->price * (1 - $this->discount / 100);
    }
}
