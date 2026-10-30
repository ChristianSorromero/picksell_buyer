<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Models\WishlistItem;
use App\Services\RecentlyViewed;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;

/**
 * Public catalog, showing what the website's shop shows: active products in stock from approved
 * sellers. A bearer token is optional; it adds `wishlisted` and records recently viewed products.
 */
class CatalogController extends Controller
{
    /** Listable products with the numbers product cards show. */
    public static function listable()
    {
        return Product::purchasable()->where('stock', '>', 0)->with('seller')
            ->withAvg('reviews', 'rating')->withCount('reviews')
            ->withSum(['orders as sold_count' => fn ($orders) => $orders->whereIn('status', ['delivered', 'completed'])], 'quantity');
    }

    private function buyer(): ?User
    {
        $user = auth('sanctum')->user();

        return $user && $user->role === 'buyer' && $user->isApproved() ? $user : null;
    }

    private function cards($products)
    {
        $ids = ($buyer = $this->buyer()) ? WishlistItem::where('user_id', $buyer->id)->pluck('product_id')->all() : [];

        return $products->map(fn ($p) => BuyerPresenter::product($p, $ids))->values();
    }

    public function home(RecentlyViewed $recentlyViewed)
    {
        $deals = self::listable()->where('discount', '>', 0)->latest()->take(14)->get();
        $topDiscount = $deals->sortByDesc('discount')->first();

        $banners = collect();
        if ($topDiscount) {
            $banners->push([
                'kind'     => 'deals',
                'title'    => 'Deals of the Day',
                'subtitle' => 'Up to '.(int) round($deals->max('discount')).'% off today',
                'cta'      => 'Shop now',
                'image'    => BuyerPresenter::image($topDiscount->primary_image),
            ]);
        }
        Announcement::where('active', true)->whereIn('audience', ['all', 'buyer'])->latest()->take(3)->get()
            ->each(fn ($a) => $banners->push([
                'kind' => 'announcement', 'title' => $a->title, 'subtitle' => $a->message, 'cta' => null, 'image' => null,
            ]));

        $buyer = $this->buyer();

        return response()->json([
            'banners'         => $banners->values(),
            'categories'      => $this->categoryList(),
            'hot_discounts'   => $this->cards($deals),
            'featured'        => $this->cards(self::listable()->where('is_featured', true)->latest()->take(8)->get()),
            'recommended'     => $this->cards(self::listable()->latest()->take(10)->get()),
            'recently_viewed' => $buyer ? $this->cards($recentlyViewed->products($buyer, 10)->each->loadAvg('reviews', 'rating')->each->loadCount('reviews')) : [],
        ]);
    }

    public function categories()
    {
        return response()->json(['categories' => $this->categoryList()]);
    }

    /** The website's fixed category list plus any category in use, with how many products each has. */
    private function categoryList()
    {
        $counts = Product::purchasable()->where('stock', '>', 0)->whereNotNull('category')->where('category', '!=', '')
            ->selectRaw('category, COUNT(*) as product_count')->groupBy('category')->pluck('product_count', 'category');

        return collect(config('picksell.home_categories'))->merge($counts->keys())->unique()->sort()->values()
            ->map(fn ($name) => ['name' => $name, 'product_count' => (int) ($counts[$name] ?? 0)]);
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
        $query = self::listable();

        if ($s = $data['search'] ?? null) {
            $query->where(fn ($q) => $q->where('name', 'like', "%{$s}%")->orWhere('category', 'like', "%{$s}%"));
        }
        if ($c = $data['category'] ?? null) $query->where('category', $c);
        if (! empty($data['on_sale'])) $query->where('discount', '>', 0);
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
            'products' => $this->cards($page->getCollection()),
            'meta'     => ['current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total()],
        ]);
    }

    public function show(Product $product, RecentlyViewed $recentlyViewed)
    {
        abort_if($product->status !== 'active', 404, 'This product is no longer available.');

        $product->load(['seller', 'variations'])->loadAvg('reviews', 'rating')->loadCount('reviews');
        $product->sold_count = (int) $product->orders()->whereIn('status', ['delivered', 'completed'])->sum('quantity');
        if ($buyer = $this->buyer()) {
            $recentlyViewed->record($buyer, $product);
        }

        $distribution = $product->reviews()->selectRaw('rating, COUNT(*) as n')->groupBy('rating')->pluck('n', 'rating');
        $vouchers = $product->voucher_code && $product->voucher_discount > 0 ? [[
            'code' => $product->voucher_code, 'scope' => 'store', 'seller' => null,
            'title' => rtrim(rtrim(number_format($product->voucher_discount, 2), '0'), '.').'% Off',
            'type' => 'percent', 'value' => (float) $product->voucher_discount, 'min_spend' => 0,
            'max_discount' => null, 'is_limited' => false, 'expires_at' => null, 'eligible' => null, 'discount' => null,
        ]] : [];

        return response()->json([
            'product' => $this->cards(collect([$product]))->first() + [
                'description'      => $product->description ?? '',
                'variation_groups' => BuyerPresenter::variationGroups($product),
                'max_quantity'     => (int) $product->stock,
                'seller'           => $this->sellerSummary($product->seller),
                'rating_summary'   => [
                    'average'      => $product->reviews_avg_rating !== null ? round((float) $product->reviews_avg_rating, 1) : null,
                    'count'        => (int) $product->reviews_count,
                    'distribution' => collect([5, 4, 3, 2, 1])->mapWithKeys(fn ($r) => [$r => (int) ($distribution[$r] ?? 0)]),
                ],
                'top_reviews'      => $product->reviews()->with('buyer')->latest()->take(2)->get()
                    ->map(fn ($r) => BuyerPresenter::review($r))->values(),
                'shipping'         => null,
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
        $query = $product->reviews()->with('buyer')->latest();
        if ($r = $data['rating'] ?? null) $query->where('rating', $r);
        if (! empty($data['with_comments'])) $query->whereNotNull('body')->where('body', '!=', '');

        $page = $query->paginate(20);

        return response()->json([
            'summary' => [
                'average'      => ($avg = $product->reviews()->avg('rating')) ? round((float) $avg, 1) : null,
                'count'        => (int) $distribution->sum(),
                'distribution' => collect([5, 4, 3, 2, 1])->mapWithKeys(fn ($r) => [$r => (int) ($distribution[$r] ?? 0)]),
            ],
            'reviews' => $page->getCollection()->map(fn ($r) => BuyerPresenter::review($r))->values(),
            'meta'    => ['current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total()],
        ]);
    }

    public function seller(User $seller)
    {
        abort_if($seller->role !== 'seller' || $seller->status !== 'approved', 404, 'Store not found.');

        $products = self::listable()->where('seller_id', $seller->id)->latest()->get();

        return response()->json([
            'seller'     => $this->sellerSummary($seller),
            'categories' => $products->pluck('category')->filter()->unique()->values(),
            'products'   => $this->cards($products),
        ]);
    }

    private function sellerSummary(?User $seller): ?array
    {
        if (! $seller) return null;

        $rated = Order::where('seller_id', $seller->id)->whereNotNull('rating');
        $count = (clone $rated)->count();

        return BuyerPresenter::sellerBrief($seller) + [
            'rating'        => ($avg = (clone $rated)->avg('rating')) ? round((float) $avg, 1) : null,
            'review_count'  => $count,
            'positive_rate' => $count ? (int) round((clone $rated)->where('rating', '>=', 4)->count() * 100 / $count) : null,
            'product_count' => Product::purchasable()->where('stock', '>', 0)->where('seller_id', $seller->id)->count(),
            'joined_at'     => BuyerPresenter::date($seller->created_at),
        ];
    }
}
