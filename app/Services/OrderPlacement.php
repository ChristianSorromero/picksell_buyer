<?php

namespace App\Services;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Notifications\NewSellerOrder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Places the buyer's selected cart lines as orders exactly like the website's checkout
 * (BuyerController::placeOrder): one order per cart line, price = product price minus its
 * discount and, if the code matches, the product's own voucher; Cash on Delivery to the buyer's
 * profile address. Keep the two in step.
 */
class OrderPlacement
{
    public function __construct(private CommissionService $commission) {}

    /** The buyer's own cart lines among [$ids]. */
    public function items(User $buyer, array $ids): Collection
    {
        $cart = Cart::firstOrCreate(['buyer_id' => $buyer->id]);

        return CartItem::where('cart_id', $cart->id)->whereIn('id', $ids)->with('product.seller', 'variation')->get();
    }

    /** What one cart line costs per unit, with the product voucher applied when [$voucherCode] matches. */
    public static function unitPrice(Product $product, ?string $voucherCode): float
    {
        $price = $product->effective_price;
        if (! empty($voucherCode) && $product->voucher_code === $voucherCode) {
            $price = $price * (1 - $product->voucher_discount / 100);
        }

        return $price;
    }

    /**
     * @return Collection<int, Order>
     *
     * @throws ValidationException (field item_ids) when a line is unavailable or short of stock
     */
    public function place(User $buyer, array $itemIds, ?string $voucherCode): Collection
    {
        $items = $this->items($buyer, $itemIds);
        if ($items->isEmpty()) {
            throw ValidationException::withMessages(['item_ids' => 'No items selected.']);
        }

        $placed = DB::transaction(function () use ($buyer, $items, $voucherCode) {
            // Lock the products so moderation, other buyers and stock changes cannot interleave.
            $products = Product::whereIn('id', $items->pluck('product_id'))->with('seller')->lockForUpdate()->get()->keyBy('id');
            $unavailable = $items->filter(fn ($item) => ! $products->get($item->product_id)?->isPurchasable());
            if ($unavailable->isNotEmpty()) {
                throw ValidationException::withMessages(['item_ids' => self::unavailableMessage($unavailable)]);
            }
            // Several cart lines (e.g. variations) can draw on the same product's stock.
            $shortStock = $items->groupBy('product_id')
                ->filter(fn ($lines, $productId) => $products[$productId]->stock < $lines->sum('quantity'));
            if ($shortStock->isNotEmpty()) {
                throw ValidationException::withMessages(['item_ids' => 'Not enough stock for: '.$shortStock->keys()->map(fn ($productId) => $products[$productId]->name)->join(', ').'.']);
            }

            return $items->map(function (CartItem $item) use ($buyer, $products, $voucherCode) {
                $product = $products[$item->product_id];
                $amount = self::unitPrice($product, $voucherCode) * $item->quantity;
                $commission = $this->commission->calculate((string) round($amount, 2));

                $order = Order::create([
                    'order_number' => 'ORD-'.strtoupper(Str::random(8)),
                    'product_id' => $product->id,
                    'buyer_id' => $buyer->id,
                    'seller_id' => $product->seller_id,
                    'product_name' => $product->name,
                    'quantity' => $item->quantity,
                    'amount' => $amount,
                    'commission' => $commission['commission'],
                    'commission_rate' => $commission['rate'],
                    'status' => 'placed',
                    'tracking_status' => 'Order placed and awaiting seller preparation',
                ]);

                $product->decrement('stock', $item->quantity);
                $item->delete();

                return $order;
            });
        });

        foreach ($placed as $order) {
            $order->seller?->notify(new NewSellerOrder($order));
        }

        return $placed;
    }

    public static function unavailableMessage(Collection $items): string
    {
        return 'No longer available: '.$items->map(fn ($item) => $item->product?->name ?? 'a removed product')->join(', ')
            .'. Remove '.($items->count() === 1 ? 'it' : 'them').' from your cart to continue.';
    }
}
