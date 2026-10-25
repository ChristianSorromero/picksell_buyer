<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BuyerAddress;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\Voucher;
use App\Services\CheckoutPricing;
use App\Services\OrderPlacement;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;

/** COM-C14…C19 + API-C05 Checkout Service. */
class CheckoutController extends Controller
{
    public function __construct(private CheckoutPricing $pricing, private OrderPlacement $placement) {}

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

        $placed = $this->placement->place(
            $buyer, $data['item_ids'], $address->snapshot(), $data['payment_method'],
            $data['shipping_option'] ?? 'standard', $data['voucher_code'] ?? null,
        );

        return match ($placed['result']) {
            'empty'   => response()->json(['message' => 'Your selected items are no longer in your cart.'], 422),
            'changed' => response()->json([
                'message' => 'Some items in your order changed (stock or availability). Please review your cart.',
                'quote'   => $placed['quote'],
            ], 409),
            'voucher' => response()->json([
                'message' => $placed['message'],
                'errors'  => ['voucher_code' => [$placed['message']]],
            ], 422),
            'placed'  => response()->json([
                'message'      => 'Order placed! We’ll notify you as it moves.',
                'checkout_ref' => $placed['checkout_ref'],
                'totals'       => $placed['totals'],
                'orders'       => $placed['orders']->map(fn ($o) => BuyerPresenter::orderCard($o->load('seller', 'product')))->values(),
            ], 201),
        };
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
}
