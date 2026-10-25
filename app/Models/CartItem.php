<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CartItem extends Model
{
    protected $fillable = ['cart_id', 'product_id', 'variation_id', 'variation_ids', 'quantity'];

    protected $casts = ['variation_ids' => 'array'];

    public function cart()      { return $this->belongsTo(Cart::class); }
    public function product()   { return $this->belongsTo(Product::class); }
    public function variation() { return $this->belongsTo(ProductVariation::class, 'variation_id'); }

    public function getSubtotalAttribute(): float
    {
        return $this->product->effective_price * $this->quantity;
    }
}
