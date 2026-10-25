<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Services\CheckoutPricing;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/** COM-C10/C12/C13 — the buyer's server-side cart. */
class CartController extends Controller
{
    public function __construct(private CheckoutPricing $pricing) {}

    private function cart(Request $request): Cart
    {
        return Cart::firstOrCreate(['buyer_id' => $request->user()->id]);
    }

    private function items(Cart $cart)
    {
        return CartItem::where('cart_id', $cart->id)->with('product.seller')->latest()->get();
    }

    /** GET /buyer/cart?voucher_code= */
    public function index(Request $request)
    {
        $quote = $this->pricing->quote($this->items($this->cart($request)), 'standard', $request->query('voucher_code'));
        return response()->json(['cart' => $quote]);
    }

    /** POST /buyer/cart {product_id, quantity, variation_ids[]} */
    public function store(Request $request)
    {
        $data = $request->validate([
            'product_id'      => 'required|integer|exists:products,id',
            'quantity'        => 'required|integer|min:1',
            'variation_ids'   => 'nullable|array',
            'variation_ids.*' => 'integer',
        ]);

        $product = Product::with('variations')->findOrFail($data['product_id']);
        $variationIds = $this->validateVariations($product, $data['variation_ids'] ?? []);
        $cart = $this->cart($request);

        $existing = CartItem::where('cart_id', $cart->id)->where('product_id', $product->id)->get()
            ->first(fn ($i) => $this->pricing->variationIds($i) == $variationIds);

        $quantity = ($existing?->quantity ?? 0) + $data['quantity'];
        $this->assertQuantity($product, $variationIds, $quantity);

        if ($existing) {
            $existing->update(['quantity' => $quantity]);
            $item = $existing;
        } else {
            $item = CartItem::create([
                'cart_id'       => $cart->id,
                'product_id'    => $product->id,
                'variation_id'  => $variationIds[0] ?? null,
                'variation_ids' => $variationIds ?: null,
                'quantity'      => $quantity,
            ]);
        }

        return response()->json([
            'message'      => "{$product->name} added to cart.",
            'cart_item_id' => $item->id,
            'cart_count'   => $this->count($cart),
        ], 201);
    }

    /** PATCH /buyer/cart/{item} {quantity?, variation_ids?} */
    public function update(Request $request, CartItem $item)
    {
        $this->authorizeItem($request, $item);
        $data = $request->validate([
            'quantity'        => 'sometimes|integer|min:1',
            'variation_ids'   => 'sometimes|array',
            'variation_ids.*' => 'integer',
        ]);

        $product = $item->product()->with('variations')->first();
        $variationIds = array_key_exists('variation_ids', $data)
            ? $this->validateVariations($product, $data['variation_ids'])
            : $this->pricing->variationIds($item);
        $quantity = $data['quantity'] ?? $item->quantity;
        $this->assertQuantity($product, $variationIds, $quantity);

        $item->update([
            'quantity'      => $quantity,
            'variation_id'  => $variationIds[0] ?? null,
            'variation_ids' => $variationIds ?: null,
        ]);

        return $this->index($request);
    }

    public function destroy(Request $request, CartItem $item)
    {
        $this->authorizeItem($request, $item);
        $item->delete();
        return $this->index($request);
    }

    /** DELETE /buyer/cart {item_ids[]} — "Edit" mode bulk remove. */
    public function destroyMany(Request $request)
    {
        $data = $request->validate(['item_ids' => 'required|array|min:1', 'item_ids.*' => 'integer']);
        CartItem::where('cart_id', $this->cart($request)->id)->whereIn('id', $data['item_ids'])->delete();
        return $this->index($request);
    }

    public function count(Cart $cart): int
    {
        return (int) CartItem::where('cart_id', $cart->id)->sum('quantity');
    }

    public function summary(Request $request)
    {
        return response()->json(['cart_count' => $this->count($this->cart($request))]);
    }

    private function authorizeItem(Request $request, CartItem $item): void
    {
        abort_if($item->cart->buyer_id !== $request->user()->id, 404);
    }

    /** One option per variation type is required when the product has variations. */
    private function validateVariations(Product $product, array $ids): array
    {
        $ids = array_values(array_unique(array_map('intval', $ids)));
        $types = $product->variations->pluck('type')->unique();
        $chosen = $product->variations->whereIn('id', $ids);

        if ($chosen->count() !== count($ids) || $chosen->pluck('type')->unique()->count() !== $chosen->count()) {
            throw ValidationException::withMessages(['variation_ids' => 'Choose one option for each variation.']);
        }
        $missing = $types->diff($chosen->pluck('type'));
        if ($missing->isNotEmpty()) {
            throw ValidationException::withMessages(['variation_ids' => 'Please select a ' . strtolower($missing->first()) . '.']);
        }

        // Stable order (by type) so the same choice always matches the same cart line.
        return $chosen->sortBy('type')->pluck('id')->values()->all();
    }

    private function assertQuantity(Product $product, array $variationIds, int $quantity): void
    {
        abort_if($product->status !== 'active', 422, 'This product is no longer available.');

        $stock = min([(int) $product->stock, ...ProductVariation::whereIn('id', $variationIds)->pluck('stock')->map(fn ($s) => (int) $s)->all()]);
        $max = min($stock, (int) config('picksell.max_quantity_per_item'));

        if ($stock <= 0) {
            throw ValidationException::withMessages(['quantity' => 'This item is out of stock.']);
        }
        if ($quantity > $max) {
            throw ValidationException::withMessages([
                'quantity' => $max < (int) config('picksell.max_quantity_per_item')
                    ? "Only {$max} left in stock."
                    : "Maximum {$max} per order for this item.",
            ]);
        }
    }
}
