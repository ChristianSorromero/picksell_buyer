<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class ProductImage extends Model
{
    protected $fillable = ['product_id', 'image_url', 'display_order', 'is_primary', 'alt_text'];

    protected $casts = ['display_order' => 'integer', 'is_primary' => 'boolean'];

    public function product() { return $this->belongsTo(Product::class); }

    public function getUrlAttribute(): string
    {
        return Storage::disk('public')->url($this->image_url);
    }
}
