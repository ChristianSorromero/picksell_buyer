<?php

namespace App\Services;

use App\Models\CartItem;
use App\Models\ProductVariation;
use App\Models\Voucher;
use App\Support\BuyerPresenter;
use Illuminate\Support\Collection;

/**
 * Prices a set of cart lines exactly the way checkout will charge them:
 * merchandise per seller → shipping per seller parcel → one voucher →
 * service fee. Used by the cart, the voucher sheet, the checkout quote and
 * order placement so the buyer never sees a number that changes on submit.
 */
class CheckoutPricing
{
    /**
     * @param  Collection<int, CartItem>  $items  with product.seller loaded
     */
    public function quote(Collection $items, ?string $shippingCode = 'standard', ?string $voucherCode = null): array
    {
        $shipping = $this->shippingOption($shippingCode) ?? $this->shippingOption('standard');
        $variations = ProductVariation::whereIn('id', $items->flatMap(fn ($i) => $this->variationIds($i))->unique())
            ->get()->keyBy('id');

        $lines = $items->map(function (CartItem $item) use ($variations) {
            $product = $item->product;
            $chosen = collect($this->variationIds($item))->map(fn ($id) => $variations->get($id))->filter();
            $available = min([(int) $product->stock, ...$chosen->map(fn ($v) => (int) $v->stock)->all()]);
            $unit = BuyerPresenter::money($product->effective_price);

            $issue = match (true) {
                $product->status !== 'active' => 'unavailable',
                $available <= 0               => 'out_of_stock',
                $item->quantity > $available  => 'insufficient_stock',
                default                       => null,
            };

            return [
                'cart_item_id'    => $item->id,
                'product'         => BuyerPresenter::product($product),
                'seller_id'       => $product->seller_id,
                'variation_ids'   => $chosen->keys()->isEmpty() ? [] : $chosen->pluck('id')->values()->all(),
                'variation_label' => $chosen->isEmpty() ? null : $chosen->map(fn ($v) => $v->value)->join(', '),
                'quantity'        => (int) $item->quantity,
                'available_stock' => max(0, $available),
                'unit_price'      => $unit,
                'line_total'      => BuyerPresenter::money($unit * $item->quantity),
                'discount'        => 0.0,
                'issue'           => $issue,
                '_voucher_code'   => $product->voucher_code,
                '_voucher_pct'    => (float) $product->voucher_discount,
            ];
        })->values();

        [$voucher, $voucherError, $lines] = $this->applyVoucher($lines, $voucherCode);

        $groups = $lines->groupBy('seller_id')->map(function (Collection $sellerLines) use ($items, $shipping) {
            $seller = $items->firstWhere('product.seller_id', $sellerLines->first()['seller_id'])->product->seller;
            $subtotal = $sellerLines->sum('line_total');

            return [
                'seller'       => $seller ? BuyerPresenter::sellerBrief($seller) : null,
                'items'        => $sellerLines->map(fn ($l) => collect($l)->except(['_voucher_code', '_voucher_pct', 'seller_id'])->all())->values(),
                'subtotal'     => BuyerPresenter::money($subtotal),
                'discount'     => BuyerPresenter::money($sellerLines->sum('discount')),
                'shipping_fee' => BuyerPresenter::money($shipping['fee']),
            ];
        })->values();

        $merchandise = $lines->sum('line_total');
        $discount = $lines->sum('discount');
        $shippingTotal = $shipping['fee'] * $groups->count();
        $serviceFee = $lines->isEmpty() ? 0 : (float) config('picksell.service_fee');

        return [
            'groups'          => $groups,
            'shipping_option' => $shipping,
            'voucher'         => $voucher,
            'voucher_error'   => $voucherError,
            'has_issues'      => $lines->contains(fn ($l) => $l['issue'] !== null),
            'item_count'      => (int) $lines->sum('quantity'),
            'totals'          => [
                'merchandise_subtotal' => BuyerPresenter::money($merchandise),
                'shipping_total'       => BuyerPresenter::money($shippingTotal),
                'discount_total'       => BuyerPresenter::money($discount),
                'service_fee'          => BuyerPresenter::money($serviceFee),
                'total'                => BuyerPresenter::money(max(0, $merchandise - $discount) + $shippingTotal + $serviceFee),
            ],
        ];
    }

    public function variationIds(CartItem $item): array
    {
        $ids = $item->variation_ids ?: ($item->variation_id ? [$item->variation_id] : []);
        return array_values(array_map('intval', $ids));
    }

    public function shippingOptions(): array
    {
        return collect(config('picksell.shipping_options'))->map(fn ($o) => $this->withEta($o))->all();
    }

    public function shippingOption(?string $code): ?array
    {
        $o = collect(config('picksell.shipping_options'))->firstWhere('code', $code);
        return $o ? $this->withEta($o) : null;
    }

    private function withEta(array $o): array
    {
        return $o + [
            'estimated_from' => now()->addDays($o['min_days'])->toDateString(),
            'estimated_to'   => now()->addDays($o['max_days'])->toDateString(),
        ];
    }

    /**
     * Resolves one voucher code against the lines and spreads its discount
     * across the eligible lines (proportionally, remainder on the last).
     *
     * @return array{0: ?array, 1: ?string, 2: Collection}
     */
    private function applyVoucher(Collection $lines, ?string $code): array
    {
        $code = $code ? strtoupper(trim($code)) : null;
        if (!$code || $lines->isEmpty()) return [null, null, $lines];

        $voucher = Voucher::with('seller')->whereRaw('UPPER(code) = ?', [$code])->first();

        if ($voucher) {
            if (!$voucher->active || ($voucher->expires_at && $voucher->expires_at->isPast())
                || ($voucher->starts_at && $voucher->starts_at->isFuture())) {
                return [null, 'This voucher has expired.', $lines];
            }
            if ($voucher->isExhausted()) {
                return [null, 'This voucher has been fully redeemed.', $lines];
            }
            $eligible = $lines->filter(fn ($l) => $voucher->scope === 'platform' || $l['seller_id'] === $voucher->seller_id);
            if ($eligible->isEmpty()) {
                return [null, 'This store voucher doesn’t apply to the selected items.', $lines];
            }
            $base = $eligible->sum('line_total');
            if ($base < $voucher->min_spend) {
                $short = number_format($voucher->min_spend - $base, 2);
                return [null, "Spend ₱{$short} more to use this voucher.", $lines];
            }
            $discount = $voucher->discountFor($base);
            $title = $voucher->title;
        } else {
            // Legacy per-product codes set by sellers on the product form.
            $eligible = $lines->filter(fn ($l) => $l['_voucher_code'] && strtoupper($l['_voucher_code']) === $code && $l['_voucher_pct'] > 0);
            if ($eligible->isEmpty()) {
                return [null, 'We couldn’t find that voucher code.', $lines];
            }
            $discount = round($eligible->sum(fn ($l) => $l['line_total'] * $l['_voucher_pct'] / 100), 2);
            $base = $eligible->sum('line_total');
            $title = rtrim(rtrim(number_format($eligible->first()['_voucher_pct'], 2), '0'), '.') . '% Off';
        }

        $keys = $eligible->keys()->values();
        $remaining = $discount;
        foreach ($keys as $i => $key) {
            $line = $lines[$key];
            $share = $i === $keys->count() - 1 ? $remaining : round($discount * $line['line_total'] / $base, 2);
            $line['discount'] = BuyerPresenter::money($share);
            $remaining -= $share;
            $lines[$key] = $line;
        }

        return [['code' => $code, 'title' => $title, 'discount' => BuyerPresenter::money($discount)], null, $lines];
    }
}
