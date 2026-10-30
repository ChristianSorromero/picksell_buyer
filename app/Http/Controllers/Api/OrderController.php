<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Complaint;
use App\Models\Order;
use App\Models\ProductReview;
use App\Models\ReturnRequest;
use App\Models\ReturnRequestEvent;
use App\Services\AdminNotificationService;
use App\Services\Orders\OrderCancellationService;
use App\Support\BuyerPresenter;
use App\Support\OrderStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** The buyer's orders, read from and written to the website's tables with the website's rules. */
class OrderController extends Controller
{
    private function find(Request $request, Order $order): Order
    {
        abort_if($order->buyer_id !== $request->user()->id, 404, 'Order not found.');

        return $order;
    }

    private function detail(Order $order)
    {
        $order->refresh()->load('seller', 'product', 'buyer', 'returnRequest.refund', 'statusHistories');

        return response()->json(['order' => BuyerPresenter::orderDetail($order)]);
    }

    /** GET /buyer/orders?tab=to_ship|in_transit|out_for_delivery|to_rate|completed|cancelled|all */
    public function index(Request $request)
    {
        $data = $request->validate(['tab' => ['nullable', Rule::in(['all', ...array_keys(OrderStatus::TABS)])]]);
        $orders = Order::where('buyer_id', $request->user()->id)->with('seller', 'product')->latest()->get();

        $counts = collect(array_keys(OrderStatus::TABS))->mapWithKeys(fn ($tab) => [$tab => 0])->all();
        $orders->each(function (Order $o) use (&$counts) { $counts[OrderStatus::tab($o)]++; });

        $tab = $data['tab'] ?? 'all';
        if ($tab !== 'all') {
            $orders = $orders->filter(fn (Order $o) => OrderStatus::tab($o) === $tab);
        }

        return response()->json([
            'orders' => $orders->map(fn ($o) => BuyerPresenter::orderCard($o))->values(),
            'counts' => $counts,
        ]);
    }

    public function show(Request $request, Order $order)
    {
        return $this->detail($this->find($request, $order));
    }

    /** POST /buyer/orders/{id}/cancel {reason?} — website rule: Placed, Confirmed or Preparing only. */
    public function cancel(Request $request, Order $order, OrderCancellationService $cancellations)
    {
        $data = $request->validate(['reason' => ['nullable', 'string', 'max:1000']]);
        $cancellations->cancel($this->find($request, $order), $request->user(), 'buyer', $data['reason'] ?? null);

        return $this->detail($order);
    }

    /**
     * POST /buyer/orders/{id}/rate {rating, feedback?} — the order rating the seller sees. Once the
     * seller has confirmed delivery (completed) it is also the product review, as on the website.
     */
    public function rate(Request $request, Order $order)
    {
        $this->find($request, $order);
        $data = $request->validate([
            'rating'   => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:1000',
        ]);
        abort_unless(in_array(OrderStatus::of($order), OrderStatus::RATEABLE, true), 422, 'You can rate an order once it has been delivered.');
        abort_if($order->rating !== null, 422, 'You already rated this order.');

        $order->update(['rating' => $data['rating'], 'feedback' => $data['feedback'] ?? null]);
        if ($order->status === 'completed' && $order->product_id) {
            ProductReview::updateOrCreate(
                ['product_id' => $order->product_id, 'buyer_id' => $order->buyer_id, 'order_id' => $order->id],
                ['rating' => $data['rating'], 'body' => $data['feedback'] ?? null],
            );
        }

        return $this->detail($order);
    }

    /** POST /buyer/orders/{id}/report {category, details, evidence[]?} — becomes a complaint for admins. */
    public function report(Request $request, Order $order)
    {
        $this->find($request, $order);
        $data = $request->validate([
            'category'   => ['required', Rule::in(config('picksell.report_categories'))],
            'details'    => 'required|string|min:10|max:2000',
            'evidence'   => 'nullable|array|max:5',
            'evidence.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);
        abort_if(in_array(OrderStatus::of($order), ['placed', 'cancelled'], true), 422, 'You can report a problem once the seller is handling your order.');

        // The website's complaint page shows one evidence file.
        $evidence = $request->file('evidence', [])[0] ?? null;
        $complaint = Complaint::create([
            'filed_by'        => $request->user()->id,
            'against_user_id' => $order->seller_id,
            'order_id'        => $order->id,
            'subject'         => "{$data['category']} — order {$order->order_number}",
            'details'         => $data['details'],
            'evidence_path'   => $evidence?->store('complaints', 'public'),
            'status'          => 'open',
        ]);

        return response()->json([
            'message' => 'Thanks, we received your report. PickSell support will review it.',
            'ticket'  => $this->ticket($complaint->load('order')),
        ], 201);
    }

    /**
     * POST /buyer/orders/{id}/return {reason, details, quantity?, evidence[]?} — the website's
     * return request (BuyerReturnRequestController): the seller reviews it first.
     */
    public function requestReturn(Request $request, Order $order, AdminNotificationService $notifications)
    {
        $this->find($request, $order);
        abort_unless(in_array($order->status, ['delivered', 'completed'], true), 422, 'Returns can only be requested for delivered orders.');
        abort_if($order->returnRequest()->exists(), 409, 'A return request already exists for this order.');

        // The app may send the label it showed; store the website's code.
        $request->merge(['reason' => array_search($request->input('reason'), ReturnRequest::REASONS, true) ?: $request->input('reason')]);
        // Same limits as the website: up to 5 photos or videos, 10 MB each ("evidence" from the app).
        $fileRules = ['nullable', 'array', 'max:5'];
        $eachFile = 'file|mimes:jpg,jpeg,png,webp,mp4,webm|max:10240';
        $data = $request->validate([
            'reason'        => ['required', Rule::in(array_keys(ReturnRequest::REASONS))],
            'details'       => 'required|string|max:2000',
            'quantity'      => 'sometimes|integer|min:1|max:'.$order->quantity,
            'evidence'      => $fileRules,
            'evidence.*'    => $eachFile,
            'attachments'   => $fileRules,
            'attachments.*' => $eachFile,
        ]);
        $files = [...$request->file('evidence', []), ...$request->file('attachments', [])];
        abort_if(count($files) > 5, 422, 'Attach up to 5 photos or videos.');

        $quantity = (int) ($data['quantity'] ?? $order->quantity);
        $returnRequest = DB::transaction(function () use ($order, $data, $quantity, $files) {
            $returnRequest = ReturnRequest::create([
                'order_id' => $order->id,
                'buyer_id' => $order->buyer_id,
                'seller_id' => $order->seller_id,
                'reason' => $data['reason'],
                'details' => $data['details'],
                'quantity' => $quantity,
                'refund_amount' => round(((float) $order->amount / max((int) $order->quantity, 1)) * $quantity, 2),
                'attachments' => collect($files)->map(fn ($file) => $file->store('return-requests', 'public'))->all(),
                'status' => 'requested',
            ]);
            ReturnRequestEvent::create([
                'return_request_id' => $returnRequest->id,
                'actor_user_id' => $order->buyer_id,
                'event_type' => 'request_submitted',
                'from_status' => null,
                'to_status' => 'requested',
                'notes' => $data['details'],
                'metadata' => ['reason' => $data['reason'], 'quantity' => $quantity],
            ]);

            return $returnRequest;
        });
        $notifications->notifyAdmins(
            'return.requested',
            'Return/refund requested',
            "A buyer requested a return for order {$order->order_number}.",
            "/admin/returns/{$returnRequest->id}",
        );

        return response()->json([
            'message'        => 'Return/refund request sent to the seller.',
            'return_request' => BuyerPresenter::returnRequest($returnRequest),
        ], 201);
    }

    /** POST /buyer/orders/{id}/reorder — puts the product back in the cart. */
    public function reorder(Request $request, Order $order)
    {
        $this->find($request, $order);
        $product = $order->product()->with('seller')->first();
        abort_unless($product && $product->isPurchasable() && $product->stock > 0, 422, 'This product is no longer available.');

        $cart = Cart::firstOrCreate(['buyer_id' => $request->user()->id]);
        $item = CartItem::firstOrNew(['cart_id' => $cart->id, 'product_id' => $product->id, 'variation_id' => null]);
        $item->quantity = min((int) $item->quantity + (int) $order->quantity, (int) $product->stock);
        $item->save();

        return response()->json([
            'message'      => "{$product->name} is back in your cart.",
            'cart_item_id' => $item->id,
            'cart_count'   => (int) CartItem::where('cart_id', $cart->id)->sum('quantity'),
        ]);
    }

    /** GET /buyer/reorder — products from past orders, one entry each. */
    public function reorderCandidates(Request $request)
    {
        $orders = Order::where('buyer_id', $request->user()->id)->whereNotNull('product_id')
            ->whereIn('status', ['delivered', 'completed', 'cancelled', 'returned'])
            ->with('product.seller', 'seller')->latest()->get()->unique('product_id')->take(20);

        return response()->json(['items' => $orders->map(function (Order $o) {
            $product = $o->product;
            $last = round($o->amount / max((int) $o->quantity, 1), 2);
            $current = $product ? BuyerPresenter::money($product->effective_price) : null;

            return [
                'order_id'      => $o->id,
                'product'       => $product ? BuyerPresenter::product($product) : null,
                'product_name'  => $o->product_name,
                'seller_name'   => $o->seller?->business_name ?: $o->seller?->full_name,
                'last_price'    => $last,
                'current_price' => $current,
                'price_changed' => $current !== null && abs($current - $last) >= 0.01,
                'available'     => $product && $product->isPurchasable() && $product->stock > 0,
            ];
        })->values()]);
    }

    /** GET /buyer/support/tickets — the buyer's complaints and their status on the website. */
    public function tickets(Request $request)
    {
        $tickets = Complaint::where('filed_by', $request->user()->id)->with('order')->latest()->get();

        return response()->json(['tickets' => $tickets->map(fn ($c) => $this->ticket($c))->values()]);
    }

    public function options()
    {
        return response()->json([
            'cancel_reasons'     => config('picksell.cancel_reasons'),
            'report_categories'  => config('picksell.report_categories'),
            'return_reasons'     => array_values(ReturnRequest::REASONS),
            'refund_methods'     => [],
        ]);
    }

    private function ticket(Complaint $c): array
    {
        return [
            'id'           => $c->id,
            'reference'    => 'PS-C'.str_pad((string) $c->id, 5, '0', STR_PAD_LEFT),
            'subject'      => $c->subject,
            'status'       => $c->status,
            'order_number' => $c->order?->order_number,
            'order_id'     => $c->order_id,
            'admin_notes'  => $c->admin_notes,
            'created_at'   => BuyerPresenter::date($c->created_at),
            'updated_at'   => BuyerPresenter::date($c->updated_at),
        ];
    }
}
