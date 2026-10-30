<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\WishlistItem;
use App\Services\RecentlyViewed;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;

/** Wishlist ("My Picks") and recently viewed, shared with the website's buyer pages. */
class WishlistController extends Controller
{
    public function index(Request $request)
    {
        $ids = WishlistItem::where('user_id', $request->user()->id)->latest()->latest('id')->pluck('product_id');
        // Same as the website's wishlist page: products that can still be bought.
        $products = CatalogController::listable()->whereIn('id', $ids)->get()
            ->sortBy(fn ($p) => $ids->search($p->id))->values();

        return response()->json([
            'products' => $products->map(fn ($p) => BuyerPresenter::product($p, $ids->all()))->values(),
        ]);
    }

    public function store(Request $request, Product $product)
    {
        abort_unless($product->isPurchasable(), 404, 'This product is no longer available.');
        WishlistItem::firstOrCreate(['user_id' => $request->user()->id, 'product_id' => $product->id]);

        return response()->json(['message' => 'Saved to My Picks.', 'wishlisted' => true], 201);
    }

    public function destroy(Request $request, Product $product)
    {
        WishlistItem::where('user_id', $request->user()->id)->where('product_id', $product->id)->delete();

        return response()->json(['message' => 'Removed from My Picks.', 'wishlisted' => false]);
    }

    /** GET /buyer/recently-viewed — newest first, as on the website's shop home. */
    public function recentlyViewed(Request $request, RecentlyViewed $recentlyViewed)
    {
        $buyer = $request->user();
        $ids = $recentlyViewed->products($buyer, RecentlyViewed::KEEP)->pluck('id');
        $products = CatalogController::listable()->whereIn('id', $ids)->get()->sortBy(fn ($p) => $ids->search($p->id))->values();
        $wishlist = WishlistItem::where('user_id', $buyer->id)->pluck('product_id')->all();

        return response()->json(['products' => $products->map(fn ($p) => BuyerPresenter::product($p, $wishlist))->values()]);
    }

    /** DELETE /buyer/recently-viewed — clears the history on the website too. */
    public function clearRecentlyViewed(Request $request)
    {
        $request->user()->recentlyViewedProducts()->delete();

        return response()->json(['message' => 'Recently viewed cleared.']);
    }
}
