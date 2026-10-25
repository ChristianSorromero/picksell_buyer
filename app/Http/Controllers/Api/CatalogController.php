<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Models\Voucher;
use App\Models\WishlistItem;
use App\Services\CheckoutPricing;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;

/** Public catalog. A bearer token is optional and only adds `wishlisted`. */
class CatalogController extends Controller
{
    private function wishlistIds(Request $request): array
    {
        $user = auth('sanctum')->user();
        return $user ? WishlistItem::where('user_id', $user->id)->pluck('product_id')->all() : [];
    }

    private function cards($products, Request $request)
    {
        $ids = $this->wishlistIds($request);
        return $products->map(fn ($p) => BuyerPresenter::product($p, $ids))->values();
    }

    public function home(Request $request)
    {
        $base = fn () => Product::buyable()->withStats()->with('seller');

        $hot = $base()->where('discount', '>', 0)->orderByDesc('discount')->take(8)->get();
        $topDiscount = $hot->first();

        $banners = collect();
        if ($topDiscount) {
            $banners->push([
                'kind'     => 'deals',
                'title'    => 'Flash Picks',
                'subtitle' => 'Up to ' . (int) round($topDiscount->discount) . '% off today',
                'cta'      => 'Shop now',
                'image'    => BuyerPresenter::image($topDiscount->image),
            ]);
        }
        Announcement::where('active', true)->whereIn('audience', ['all', 'buyer'])->latest()->take(3)->get()
            ->each(fn ($a) => $banners->push([
                'kind' => 'announcement', 'title' => $a->title, 'subtitle' => $a->message, 'cta' => null, 'image' => null,
            ]));

        return response()->json([
            'banners'        => $banners->values(),
            'categories'     => $this->categoryList(),
            'hot_discounts'  => $this->cards($hot, $request),
            'featured'       => $this->cards($base()->where('is_featured', true)->latest()->take(8)->get(), $request),
            'recommended'    => $this->cards($base()->latest()->take(10)->get(), $request),
        ]);
    }

    public function categories()
    {
        return response()->json(['categories' => $this->categoryList()]);
    }

    private function categoryList()
    {
        return Product::buyable()->whereNotNull('category')->where('category', '!=', '')
            ->selectRaw('category as name, COUNT(*) as product_count')
            ->groupBy('category')->orderBy('category')->get()
            ->map(fn ($c) => ['name' => $c->name, 'product_count' => (int) $c->product_count]);
    }

    /**
     * GET /products?search=&category=&sort=newest|price_asc|price_desc|popular|rating
     *   &on_sale=1&min_price=&max_price=&seller_id=&page=
     */
    public function index(Request $request)
    {
        $data = $request->validate([
            'search'    => 'nullable|string|max:100',
            'category'  => 'nullable|string|max:100',
            'sort'      => 'nullable|in:newest,price_asc,price_desc,popular,rating',
            'on_sale'   => 'nullable|boolean',
            'min_price' => 'nullable|numeric|min:0',
            'max_price' => 'nullable|numeric|min:0',
            'seller_id' => 'nullable|integer',
            'per_page'  => 'nullable|integer|min:1|max:50',
        ]);

        $priceSql = 'price * (1 - discount / 100)';
        $query = Product::buyable()->withStats()->with('seller');

        if ($s = $data['search'] ?? null) {
            $query->where(fn ($q) => $q->where('name', 'like', "%{$s}%")
                ->orWhere('category', 'like', "%{$s}%")
                ->orWhere('description', 'like', "%{$s}%"));
        }
        if ($c = $data['category'] ?? null) $query->where('category', $c);
        if (!empty($data['on_sale'])) $query->where('discount', '>', 0);
        if (isset($data['min_price'])) $query->whereRaw("{$priceSql} >= ?", [$data['min_price']]);
        if (isset($data['max_price'])) $query->whereRaw("{$priceSql} <= ?", [$data['max_price']]);
        if ($sid = $data['seller_id'] ?? null) $query->where('seller_id', $sid);

        match ($data['sort'] ?? 'newest') {
            'price_asc'  => $query->orderByRaw("{$priceSql} asc"),
            'price_desc' => $query->orderByRaw("{$priceSql} desc"),
            'popular'    => $query->orderByDesc('sold_count'),
            'rating'     => $query->orderByDesc('reviews_avg_rating'),
            default      => $query->latest(),
        };

        $page = $query->paginate($data['per_page'] ?? 20)->withQueryString();

        return response()->json([
            'products' => $this->cards($page->getCollection(), $request),
            'meta'     => [
                'current_page' => $page->currentPage(),
                'last_page'    => $page->lastPage(),
                'total'        => $page->total(),
            ],
        ]);
    }

    public function show(Request $request, Product $product, CheckoutPricing $pricing)
    {
        abort_if($product->status !== 'active', 404, 'This product is no longer available.');

        $product->load(['seller', 'variations'])->loadAvg('reviews', 'rating')->loadCount('reviews');
        $product->sold_count = (int) $product->orders()->where('status', '!=', 'cancelled')->sum('quantity');

        $distribution = $product->reviews()->selectRaw('rating, COUNT(*) as n')->groupBy('rating')->pluck('n', 'rating');
        $vouchers = Voucher::live()->with('seller')
            ->where(fn ($q) => $q->where('scope', 'platform')->orWhere('seller_id', $product->seller_id))
            ->orderBy('min_spend')->take(5)->get()
            ->reject(fn ($v) => $v->isExhausted())
            ->map(fn ($v) => BuyerPresenter::voucher($v))->values();
        if ($product->voucher_code && $product->voucher_discount > 0) {
            $vouchers->push([
                'code' => strtoupper($product->voucher_code), 'scope' => 'store', 'seller' => null,
                'title' => rtrim(rtrim(number_format($product->voucher_discount, 2), '0'), '.') . '% Off',
                'type' => 'percent', 'value' => (float) $product->voucher_discount, 'min_spend' => 0,
                'max_discount' => null, 'is_limited' => false, 'expires_at' => null, 'eligible' => null, 'discount' => null,
            ]);
        }

        return response()->json([
            'product' => BuyerPresenter::product($product, $this->wishlistIds($request)) + [
                'description'      => $product->description ?? '',
                'variation_groups' => BuyerPresenter::variationGroups($product),
                'max_quantity'     => min((int) $product->stock, (int) config('picksell.max_quantity_per_item')),
                'seller'           => $this->sellerSummary($product->seller),
                'rating_summary'   => [
                    'average'      => $product->reviews_avg_rating !== null ? round((float) $product->reviews_avg_rating, 1) : null,
                    'count'        => (int) $product->reviews_count,
                    'distribution' => collect([5, 4, 3, 2, 1])->mapWithKeys(fn ($r) => [$r => (int) ($distribution[$r] ?? 0)]),
                ],
                'top_reviews'      => $product->reviews()->with('buyer')->latest('rated_at')->latest('updated_at')->take(2)->get()
                    ->map(fn ($o) => BuyerPresenter::review($o))->values(),
                'shipping'         => $pricing->shippingOption('standard'),
                'vouchers'         => $vouchers,
            ],
        ]);
    }

    /** GET /products/{id}/reviews?rating=5&with_comments=1 */
    public function reviews(Request $request, Product $product)
    {
        $data = $request->validate([
            'rating'        => 'nullable|integer|min:1|max:5',
            'with_comments' => 'nullable|boolean',
        ]);

        $distribution = $product->reviews()->selectRaw('rating, COUNT(*) as n')->groupBy('rating')->pluck('n', 'rating');
        $query = $product->reviews()->with('buyer')->latest('rated_at')->latest('updated_at');
        if ($r = $data['rating'] ?? null) $query->where('rating', $r);
        if (!empty($data['with_comments'])) $query->whereNotNull('feedback')->where('feedback', '!=', '');

        $page = $query->paginate(20);

        return response()->json([
            'summary' => [
                'average'      => ($avg = $product->reviews()->avg('rating')) ? round((float) $avg, 1) : null,
                'count'        => (int) $distribution->sum(),
                'distribution' => collect([5, 4, 3, 2, 1])->mapWithKeys(fn ($r) => [$r => (int) ($distribution[$r] ?? 0)]),
            ],
            'reviews' => $page->getCollection()->map(fn ($o) => BuyerPresenter::review($o))->values(),
            'meta'    => ['current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total()],
        ]);
    }

    public function seller(Request $request, User $seller)
    {
        abort_if($seller->role !== 'seller' || $seller->status !== 'approved', 404, 'Store not found.');

        $products = Product::buyable()->withStats()->with('seller')->where('seller_id', $seller->id)->latest()->get();

        return response()->json([
            'seller'     => $this->sellerSummary($seller),
            'categories' => $products->pluck('category')->filter()->unique()->values(),
            'products'   => $this->cards($products, $request),
        ]);
    }

    private function sellerSummary(?User $seller): ?array
    {
        if (!$seller) return null;

        $rated = Order::where('seller_id', $seller->id)->whereNotNull('rating');

        return BuyerPresenter::sellerBrief($seller) + [
            'rating'        => ($avg = (clone $rated)->avg('rating')) ? round((float) $avg, 1) : null,
            'review_count'  => (clone $rated)->count(),
            'positive_rate' => ($n = (clone $rated)->count()) ? (int) round((clone $rated)->where('rating', '>=', 4)->count() * 100 / $n) : null,
            'product_count' => Product::buyable()->where('seller_id', $seller->id)->count(),
            'joined_at'     => BuyerPresenter::date($seller->created_at),
        ];
    }
}
