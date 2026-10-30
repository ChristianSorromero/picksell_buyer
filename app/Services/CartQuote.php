<?php

namespace App\Services;

use App\Models\CartItem;
use App\Support\BuyerPresenter;
use Illuminate\Support\Collection;

/**
 * Prices cart lines for the app with the website's checkout rules (see OrderPlacement): no
 * shipping or service fee, and a voucher is a product's own code. Every number the app shows
 * before placing an order comes from here and equals what the order will store.
 */
class CartQuote
{
    /** @param Collection<int, CartItem> $items lines with product.seller and variation loaded */
    public function quote(Collection $items, ?string $voucherCode = null, array $wishlistIds = []): array
    {
        $voucherCode = $voucherCode !== null ? trim($voucherCode) : null;
        // Several lines (variations) can draw on the same product's stock, as on the website.
        $wanted = $items->groupBy('product_id')->map(fn ($lines) => $lines->sum('quantity'));

        $lines = $items->map(function (CartItem $item) use ($voucherCode, $wanted, $wishlistIds) {
            $product = $item->product;
            $unit = BuyerPresenter::money($product->effective_price);
            $lineTotal = round($unit * $item->quantity, 2);
            $withVoucher = round(OrderPlacement::unitPrice($product, $voucherCode) * $item->quantity, 2);

            return [
                'cart_item_id'    => $item->id,
                'product'         => BuyerPresenter::product($product, $wishlistIds),
                'quantity'        => (int) $item->quantity,
                'unit_price'      => $unit,
                'line_total'      => $lineTotal,
                'discount'        => round($lineTotal - $withVoucher, 2),
                'variation_ids'   => $item->variation_id ? [$item->variation_id] : [],
                'variation_label' => $item->variation ? ucfirst($item->variation->type).': '.$item->variation->value : null,
                'available_stock' => max(0, (int) $product->stock),
                'issue'           => match (true) {
                    ! $product->isPurchasable()                        => 'unavailable',
                    $product->stock <= 0                               => 'out_of_stock',
                    $wanted[$item->product_id] > $product->stock       => 'insufficient_stock',
                    default                                            => null,
                },
                'seller'          => $product->seller,
            ];
        });

        $groups = $lines->groupBy(fn ($line) => $line['seller']?->id)->map(fn (Collection $sellerLines) => [
            'seller'       => $sellerLines->first()['seller'] ? BuyerPresenter::sellerBrief($sellerLines->first()['seller']) : null,
            'items'        => $sellerLines->map(fn ($line) => collect($line)->except('seller')->all())->values(),
            'subtotal'     => round($sellerLines->sum('line_total'), 2),
            'discount'     => round($sellerLines->sum('discount'), 2),
            'shipping_fee' => 0.0,
        ])->values();

        $subtotal = round($lines->sum('line_total'), 2);
        $discount = round($lines->sum('discount'), 2);
        $matched = $discount > 0;

        return [
            'groups'          => $groups,
            'shipping_option' => null,
            'voucher'         => $matched ? ['code' => $voucherCode, 'title' => 'Product voucher', 'discount' => $discount] : null,
            'voucher_error'   => $voucherCode && ! $matched ? 'That voucher doesn’t apply to the selected items. Product vouchers are case-sensitive.' : null,
            'has_issues'      => $lines->contains(fn ($line) => $line['issue'] !== null),
            'item_count'      => (int) $lines->sum('quantity'),
            'totals'          => [
                'merchandise_subtotal' => $subtotal,
                'shipping_total'       => 0.0,
                'discount_total'       => $discount,
                'service_fee'          => 0.0,
                'total'                => round($subtotal - $discount, 2),
            ],
        ];
    }
}
