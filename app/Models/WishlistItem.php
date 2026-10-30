<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Shared with the website's wishlist (table created by the Picksell website migrations). */
class WishlistItem extends Model
{
    protected $fillable = ['user_id', 'product_id'];

    public function user() { return $this->belongsTo(User::class); }
    public function product() { return $this->belongsTo(Product::class); }
}
