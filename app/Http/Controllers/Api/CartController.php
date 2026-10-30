<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Models\WishlistItem;
use App\Services\CartQuote;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * The buyer's cart, the same rows the website's cart shows. Like the website, a line holds a
 * product and at most one variation, and adding the same choice again adds to its quantity.
 */
class CartController extends Controller
{
    public function __construct(private CartQuote $quote) {}

    private function cart(Request $request): Cart
    {
        return Cart::firstOrCreate(['buyer_id' => $request->user()->id]);
    }

    /** GET /buyer/cart — every line, priced, grouped by seller. */
    public function index(Request $request)
    {
        $items = CartItem::where('cart_id', $this->cart($request)->id)->with('product.seller', 'variation')->latest()->get();
        $wishlist = WishlistItem::where('user_id', $request->user()->id)->pluck('product_id')->all();

        return response()->json(['cart' => $this->quote->quote($items, null, $wishlist)]);
    }

    /** POST /buyer/cart {product_id, quantity, variation_ids?: [id] | variation_id?} */
    public function store(Request $request)
    {
        $data = $request->validate([
            'product_id'      => 'required|integer|exists:products,id',
            'quantity'        => 'required|integer|min:1',
            'variation_id'    => 'nullable|integer',
            'variation_ids'   => 'nullable|array|max:1',
            'variation_ids.*' => 'integer',
        ], ['variation_ids.max' => 'Choose one option.']);

        $product = Product::with('variations', 'seller')->findOrFail($data['product_id']);
        abort_unless($product->isPurchasable(), 422, 'This product is no longer available.');
        $variationId = $this->variation($product, $data['variation_id'] ?? ($data['variation_ids'][0] ?? null));
        $cart = $this->cart($request);

        $item = CartItem::firstOrNew(['cart_id' => $cart->id, 'product_id' => $product->id, 'variation_id' => $variationId]);
        $this->assertStock($product, (int) $item->quantity + $data['quantity']);
        $item->quantity = (int) $item->quantity + $data['quantity'];
        $item->save();

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
            'variation_ids'   => 'sometimes|array|max:1',
            'variation_ids.*' => 'integer',
        ], ['variation_ids.max' => 'Choose one option.']);

        $product = $item->product()->with('variations', 'seller')->first();
        if (array_key_exists('variation_ids', $data)) {
            $variationId = $this->variation($product, $data['variation_ids'][0] ?? null);
            $same = CartItem::where('cart_id', $item->cart_id)->where('product_id', $item->product_id)
                ->where('variation_id', $variationId)->whereKeyNot($item->id)->first();
            if ($same) {
                // Switching to a choice already in the cart merges the two lines.
                $same->increment('quantity', $data['quantity'] ?? $item->quantity);
                $item->delete();

                return $this->index($request);
            }
            $item->variation_id = $variationId;
        }
        if (isset($data['quantity'])) {
            $this->assertStock($product, $data['quantity']);
            $item->quantity = $data['quantity'];
        }
        $item->save();

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

    private function variation(Product $product, ?int $id): ?int
    {
        if ($id === null) return null;
        if (! $product->variations->contains('id', $id)) {
            throw ValidationException::withMessages(['variation_ids' => 'That option isn’t available for this product.']);
        }

        return $id;
    }

    private function assertStock(Product $product, int $quantity): void
    {
        if ($product->stock <= 0) {
            throw ValidationException::withMessages(['quantity' => 'This item is out of stock.']);
        }
        if ($quantity > $product->stock) {
            throw ValidationException::withMessages(['quantity' => "Only {$product->stock} left in stock."]);
        }
    }
}
