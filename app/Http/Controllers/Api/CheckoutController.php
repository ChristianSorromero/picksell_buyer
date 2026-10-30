<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CartQuote;
use App\Services\OrderPlacement;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Checkout with the website's rules: Cash on Delivery to the buyer's profile address, priced by
 * the product's discount and its own voucher code. No delivery or service fee.
 */
class CheckoutController extends Controller
{
    public function __construct(private CartQuote $quote, private OrderPlacement $placement) {}

    public function paymentMethods()
    {
        return response()->json(['payment_methods' => config('picksell.payment_methods')]);
    }

    /** POST /buyer/checkout/quote {item_ids[], voucher_code?} */
    public function quote(Request $request)
    {
        $data = $request->validate($this->rules());
        $buyer = $request->user();

        return response()->json([
            'quote'            => $this->quote->quote($this->placement->items($buyer, $data['item_ids']), $data['voucher_code'] ?? null),
            'delivery_address' => BuyerPresenter::deliveryAddress($buyer),
        ]);
    }

    /** POST /buyer/checkout {item_ids[], voucher_code?, payment_method?: cod} — one order per cart line. */
    public function place(Request $request)
    {
        $data = $request->validate($this->rules() + [
            'payment_method' => ['nullable', Rule::in(collect(config('picksell.payment_methods'))->pluck('code'))],
        ], ['payment_method.in' => 'Only Cash on Delivery is available.']);
        $buyer = $request->user();

        if (! BuyerPresenter::deliveryAddress($buyer)['complete']) {
            $message = 'Add your province, city and barangay in your profile before placing an order.';

            return response()->json(['message' => $message, 'errors' => ['address' => [$message]]], 422);
        }

        $orders = $this->placement->place($buyer, $data['item_ids'], $data['voucher_code'] ?? null);
        $orders->load('seller', 'product');

        return response()->json([
            'message'      => 'Order placed! We’ll notify you as it moves.',
            'checkout_ref' => $orders->first()->order_number,
            'total'        => BuyerPresenter::money($orders->sum('amount')),
            'orders'       => $orders->map(fn ($o) => BuyerPresenter::orderCard($o))->values(),
        ], 201);
    }

    private function rules(): array
    {
        return [
            'item_ids'     => 'required|array|min:1',
            'item_ids.*'   => 'integer',
            'voucher_code' => 'nullable|string|max:50',
        ];
    }
}
