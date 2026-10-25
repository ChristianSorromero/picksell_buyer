<?php

namespace App\Services;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Turns a buyer's selected cart lines into orders — one order per line,
 * one shipping fee per seller parcel — for both the mobile API and the
 * web shop, charging exactly what CheckoutPricing quoted.
 */
class OrderPlacement
{
    public function __construct(private CheckoutPricing $pricing) {}

    /** The buyer's own cart lines among [$ids]. */
    public function items(User $buyer, array $ids): Collection
    {
        $cart = Cart::firstOrCreate(['buyer_id' => $buyer->id]);
        return CartItem::where('cart_id', $cart->id)->whereIn('id', $ids)->with('product.seller')->get();
    }

    /**
     * @param  array  $shipTo  delivery snapshot, shaped like BuyerAddress::snapshot()
     * @return array  ['result' => 'placed', 'checkout_ref', 'totals', 'orders']
     *                | ['result' => 'empty'] | ['result' => 'changed', 'quote'] | ['result' => 'voucher', 'message']
     */
    public function place(
        User $buyer,
        array $itemIds,
        array $shipTo,
        string $paymentMethod,
        ?string $shippingCode = 'standard',
        ?string $voucherCode = null,
        ?User $logistics = null,
    ): array {
        return DB::transaction(function () use ($buyer, $itemIds, $shipTo, $paymentMethod, $shippingCode, $voucherCode, $logistics) {
            $items = $this->items($buyer, $itemIds);
            if ($items->isEmpty()) return ['result' => 'empty'];

            // Lock stock rows so two checkouts can't oversell the last unit.
            Product::whereIn('id', $items->pluck('product_id'))->lockForUpdate()->get();
            ProductVariation::whereIn('id', $items->flatMap(fn ($i) => $this->pricing->variationIds($i)))->lockForUpdate()->get();
            $items->each(fn ($i) => $i->product->refresh());

            $quote = $this->pricing->quote($items, $shippingCode ?? 'standard', $voucherCode);
            if ($quote['has_issues']) return ['result' => 'changed', 'quote' => $quote];
            if ($quote['voucher_error']) return ['result' => 'voucher', 'message' => $quote['voucher_error']];

            $checkoutRef = 'CO-' . strtoupper(Str::random(10));
            $shipping = $quote['shipping_option'];
            $logistics ??= $this->logisticsFor($shipTo['province'] ?? null);
            $rate = (float) config('picksell.commission_rate');
            $serviceFeeLeft = $quote['totals']['service_fee'];
            $orders = collect();

            foreach ($quote['groups'] as $group) {
                foreach ($group['items'] as $index => $line) {
                    $item = $items->firstWhere('id', $line['cart_item_id']);
                    $product = $item->product;
                    $shippingFee = $index === 0 ? $group['shipping_fee'] : 0;  // one parcel fee per seller
                    $serviceFee = $serviceFeeLeft;
                    $serviceFeeLeft = 0;
                    $amount = round($line['line_total'] - $line['discount'], 2);

                    $orders->push(Order::create([
                        'order_number'            => $this->orderNumber(),
                        'checkout_ref'            => $checkoutRef,
                        'product_id'              => $product->id,
                        'buyer_id'                => $buyer->id,
                        'seller_id'               => $product->seller_id,
                        'logistics_id'            => $logistics?->id,
                        'product_name'            => $product->name,
                        'quantity'                => $line['quantity'],
                        'variation_label'         => $line['variation_label'],
                        'variation_ids'           => $line['variation_ids'] ?: null,
                        'unit_price'              => $line['unit_price'],
                        'subtotal'                => $line['line_total'],
                        'discount'                => $line['discount'],
                        'voucher_code'            => $line['discount'] > 0 ? $quote['voucher']['code'] : null,
                        'shipping_fee'            => $shippingFee,
                        'service_fee'             => $serviceFee,
                        'amount'                  => $amount,
                        'total'                   => round($amount + $shippingFee + $serviceFee, 2),
                        'commission'              => round($amount * $rate, 2),
                        'status'                  => 'pending',
                        'shipping_option'         => $shipping['code'],
                        'estimated_delivery_from' => $shipping['estimated_from'],
                        'estimated_delivery_to'   => $shipping['estimated_to'],
                        'payment_method'          => $paymentMethod,
                        'payment_status'          => 'unpaid',
                        'ship_to'                 => $shipTo,
                    ]));

                    $product->decrement('stock', $line['quantity']);
                    if ($line['variation_ids']) {
                        ProductVariation::whereIn('id', $line['variation_ids'])->decrement('stock', $line['quantity']);
                    }
                    $item->delete();
                }
            }

            return ['result' => 'placed', 'checkout_ref' => $checkoutRef, 'totals' => $quote['totals'], 'orders' => $orders];
        });
    }

    /** The approved logistics provider serving [$province], else the first approved one. */
    public function logisticsFor(?string $province): ?User
    {
        $approved = User::where('role', 'logistics')->where('status', 'approved');
        return ($province ? (clone $approved)->where('delivery_area', 'like', '%' . $province . '%')->first() : null)
            ?? $approved->orderBy('id')->first();
    }

    private function orderNumber(): string
    {
        do {
            $number = 'PS-' . random_int(10000000, 99999999);
        } while (Order::where('order_number', $number)->exists());

        return $number;
    }
}
