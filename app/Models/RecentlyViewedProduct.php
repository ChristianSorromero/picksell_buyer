<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Shared with the website's "Recently Viewed" row; see App\Services\RecentlyViewed. */
class RecentlyViewedProduct extends Model
{
    protected $fillable = ['user_id', 'product_id', 'viewed_at'];

    protected $casts = ['viewed_at' => 'datetime'];

    public function user() { return $this->belongsTo(User::class); }
    public function product() { return $this->belongsTo(Product::class); }
}
