<?php

namespace App\Services;

use App\Models\Product;
use App\Models\RecentlyViewedProduct;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * A buyer's recently opened products, shared by the website and the buyer mobile app: one row per
 * product, newest first, capped at KEEP rows per buyer.
 */
class RecentlyViewed
{
    public const KEEP = 30;

    public function record(User $buyer, Product $product): void
    {
        RecentlyViewedProduct::updateOrCreate(
            ['user_id' => $buyer->id, 'product_id' => $product->id],
            ['viewed_at' => now()],
        );

        $stale = RecentlyViewedProduct::where('user_id', $buyer->id)
            ->orderByDesc('viewed_at')->orderByDesc('id')
            ->skip(self::KEEP)->take(PHP_INT_MAX)->pluck('id');
        if ($stale->isNotEmpty()) {
            RecentlyViewedProduct::whereIn('id', $stale)->delete();
        }
    }

    /** @return Collection<int, Product> purchasable products, most recently viewed first */
    public function products(User $buyer, int $limit = 10, ?int $exceptProductId = null): Collection
    {
        return RecentlyViewedProduct::where('user_id', $buyer->id)
            ->when($exceptProductId, fn ($query) => $query->where('product_id', '!=', $exceptProductId))
            ->whereHas('product', fn ($product) => $product->purchasable()->where('stock', '>', 0))
            ->with('product.seller', 'product.images')
            ->orderByDesc('viewed_at')->orderByDesc('id')
            ->take($limit)
            ->get()
            ->pluck('product');
    }
}
