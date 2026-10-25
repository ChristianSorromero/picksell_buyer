<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BuyerAddress;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Models\User;
use App\Models\Voucher;
use App\Services\CheckoutPricing;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/** COM-C14…C19 + API-C05 Checkout Service. */
class CheckoutController extends Controller
{
    public function __construct(private CheckoutPricing $pricing) {}

    public function shippingOptions()
    {
        return response()->json(['shipping_options' => $this->pricing->shippingOptions()]);
    }

    public function paymentMethods()
    {
        return response()->json(['payment_methods' => config('picksell.payment_methods')]);
    }

    private function selectedItems(Request $request, array $ids): Collection
    {
        $cart = Cart::firstOrCreate(['buyer_id' => $request->user()->id]);
        return CartItem::where('cart_id', $cart->id)->whereIn('id', $ids)->with('product.seller')->get();
    }

    private function baseRules(): array
    {
        return [
            'item_ids'        => 'required|array|min:1',
            'item_ids.*'      => 'integer',
            'shipping_option' => ['nullable', Rule::in(collect(config('picksell.shipping_options'))->pluck('code'))],
            'voucher_code'    => 'nullable|string|max:40',
        ];
    }

    /** POST /buyer/checkout/quote — what the Order Summary screen shows. */
    public function quote(Request $request)
    {
        $data = $request->validate($this->baseRules());
        $items = $this->selectedItems($request, $data['item_ids']);
        abort_if($items->isEmpty(), 422, 'Your selected items are no longer in your cart.');

        return response()->json(['quote' => $this->pricing->quote($items, $data['shipping_option'] ?? 'standard', $data['voucher_code'] ?? null)]);
    }

    /** POST /buyer/checkout — places one order per cart line. */
    public function place(Request $request)
    {
        $available = collect(config('picksell.payment_methods'))->where('available', true)->pluck('code');
        $data = $request->validate($this->baseRules() + [
            'address_id'     => 'required|integer',
            'payment_method' => ['required', Rule::in($available)],
        ], ['payment_method.in' => 'That payment method isn’t available yet. Please choose Cash on Delivery.']);

        $buyer = $request->user();
        $address = BuyerAddress::where('user_id', $buyer->id)->find($data['address_id']);
        if (!$address) {
            return response()->json(['message' => 'Please choose a delivery address.', 'errors' => ['address_id' => ['Please choose a delivery address.']]], 422);
        }

        return DB::transaction(function () use ($request, $data, $buyer, $address) {
            $items = $this->selectedItems($request, $data['item_ids']);
            if ($items->isEmpty()) {
                return response()->json(['message' => 'Your selected items are no longer in your cart.'], 422);
            }

            // Lock stock rows so two checkouts can't oversell the last unit.
            Product::whereIn('id', $items->pluck('product_id'))->lockForUpdate()->get();
            ProductVariation::whereIn('id', $items->flatMap(fn ($i) => $this->pricing->variationIds($i)))->lockForUpdate()->get();
            $items->each(fn ($i) => $i->product->refresh());

            $quote = $this->pricing->quote($items, $data['shipping_option'] ?? 'standard', $data['voucher_code'] ?? null);

            if ($quote['has_issues']) {
                return response()->json([
                    'message' => 'Some items in your order changed (stock or availability). Please review your cart.',
                    'quote'   => $quote,
                ], 409);
            }
            if ($quote['voucher_error']) {
                return response()->json([
                    'message' => $quote['voucher_error'],
                    'errors'  => ['voucher_code' => [$quote['voucher_error']]],
                ], 422);
            }

            $checkoutRef = 'CO-' . strtoupper(Str::random(10));
            $shipping = $quote['shipping_option'];
            $logistics = $this->logisticsFor($address);
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
                        'payment_method'          => $data['payment_method'],
                        'payment_status'          => 'unpaid',
                        'ship_to'                 => $address->snapshot(),
                    ]));

                    $product->decrement('stock', $line['quantity']);
                    if ($line['variation_ids']) {
                        ProductVariation::whereIn('id', $line['variation_ids'])->decrement('stock', $line['quantity']);
                    }
                    $item->delete();
                }
            }

            return response()->json([
                'message'      => 'Order placed! We’ll notify you as it moves.',
                'checkout_ref' => $checkoutRef,
                'totals'       => $quote['totals'],
                'orders'       => $orders->map(fn ($o) => BuyerPresenter::orderCard($o->load('seller', 'product')))->values(),
            ], 201);
        });
    }

    /**
     * GET /buyer/vouchers?item_ids[]= — with items: eligibility for the
     * checkout sheet; without: the Voucher Wallet (available/used/expired).
     */
    public function vouchers(Request $request)
    {
        $data = $request->validate(['item_ids' => 'nullable|array', 'item_ids.*' => 'integer']);
        $buyer = $request->user();

        if (!empty($data['item_ids'])) {
            $quote = $this->pricing->quote($this->selectedItems($request, $data['item_ids']), 'standard');
            $subtotals = collect($quote['groups'])->mapWithKeys(fn ($g) => [$g['seller']['id'] => $g['subtotal']]);
            $total = $quote['totals']['merchandise_subtotal'];

            $live = Voucher::live()->with('seller')
                ->where(fn ($q) => $q->where('scope', 'platform')->orWhereIn('seller_id', $subtotals->keys()))
                ->orderBy('min_spend')->get()->reject(fn ($v) => $v->isExhausted());

            return response()->json([
                'platform' => $live->where('scope', 'platform')->map(fn ($v) => BuyerPresenter::voucher($v, $total))->values(),
                'store'    => $live->where('scope', 'store')->map(fn ($v) => BuyerPresenter::voucher($v, (float) ($subtotals[$v->seller_id] ?? 0)))->values(),
            ]);
        }

        $used = Order::where('buyer_id', $buyer->id)->whereNotNull('voucher_code')->where('status', '!=', 'cancelled')
            ->distinct()->pluck('voucher_code');

        return response()->json([
            'available' => Voucher::live()->with('seller')->whereNotIn('code', $used)->orderBy('expires_at')->get()
                ->reject(fn ($v) => $v->isExhausted())->map(fn ($v) => BuyerPresenter::voucher($v))->values(),
            'used'      => Voucher::with('seller')->whereIn('code', $used)->get()->map(fn ($v) => BuyerPresenter::voucher($v))->values(),
            'expired'   => Voucher::with('seller')->whereNotIn('code', $used)->where('expires_at', '<', now())
                ->where('expires_at', '>', now()->subDays(30))->get()->map(fn ($v) => BuyerPresenter::voucher($v))->values(),
        ]);
    }

    private function orderNumber(): string
    {
        do {
            $number = 'PS-' . random_int(10000000, 99999999);
        } while (Order::where('order_number', $number)->exists());
        return $number;
    }

    /** Prefer an approved logistics partner serving the buyer's province. */
    private function logisticsFor(BuyerAddress $address): ?User
    {
        $approved = User::where('role', 'logistics')->where('status', 'approved');
        return (clone $approved)->where('delivery_area', 'like', '%' . $address->province . '%')->first()
            ?? $approved->orderBy('id')->first();
    }
}
