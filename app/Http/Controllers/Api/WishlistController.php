<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\WishlistItem;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;

/** COM-C07 / BUY-A05 — "My Picks". */
class WishlistController extends Controller
{
    public function index(Request $request)
    {
        $ids = WishlistItem::where('user_id', $request->user()->id)->latest()->pluck('product_id');
        $products = Product::whereIn('id', $ids)->withStats()->with('seller')->get()
            ->sortBy(fn ($p) => $ids->search($p->id))->values();

        return response()->json([
            'products' => $products->map(fn ($p) => BuyerPresenter::product($p, $ids->all()))->values(),
        ]);
    }

    public function store(Request $request, Product $product)
    {
        WishlistItem::firstOrCreate(['user_id' => $request->user()->id, 'product_id' => $product->id]);
        return response()->json(['message' => 'Saved to My Picks.', 'wishlisted' => true], 201);
    }

    public function destroy(Request $request, Product $product)
    {
        WishlistItem::where('user_id', $request->user()->id)->where('product_id', $product->id)->delete();
        return response()->json(['message' => 'Removed from My Picks.', 'wishlisted' => false]);
    }
}
