<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProductReview extends Model
{
    protected $fillable = ['product_id', 'buyer_id', 'order_id', 'rating', 'body'];

    public function product() { return $this->belongsTo(Product::class); }
    public function buyer() { return $this->belongsTo(User::class, 'buyer_id'); }
    public function order() { return $this->belongsTo(Order::class); }
}
