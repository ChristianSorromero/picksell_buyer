<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Complaint;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Services\ReturnWorkflow;
use App\Support\BuyerPresenter;
use App\Support\OrderStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** COM-C20 Order Card, BUY-C01…C14, API-C06 Order Service. */
class OrderController extends Controller
{
    public const REPORT_CATEGORIES = ['Damaged Item', 'Missing Item', 'Wrong Item', 'Quality Issue', 'Delivery Delay', 'Other'];
    public const RETURN_REASONS = [
        'Damaged or defective item', 'Wrong item received', 'Item not as described',
        'Missing parts or accessories', 'Changed my mind',
    ];

    public function __construct(private ReturnWorkflow $returns) {}

    private function find(Request $request, Order $order): Order
    {
        abort_if($order->buyer_id !== $request->user()->id, 404, 'Order not found.');
        return $order;
    }

    /** GET /buyer/orders?tab=to_ship|in_transit|out_for_delivery|to_rate|completed|cancelled|all */
    public function index(Request $request)
    {
        $data = $request->validate(['tab' => ['nullable', Rule::in([...array_keys(OrderStatus::TABS), 'all'])]]);
        $tab = $data['tab'] ?? 'all';

        $orders = Order::where('buyer_id', $request->user()->id)->with('seller', 'product')->latest()->get();
        if ($tab !== 'all') {
            $orders = $orders->filter(fn ($o) => OrderStatus::tab($o->canonical_status) === $tab);
        }

        $counts = collect(array_keys(OrderStatus::TABS))->mapWithKeys(fn ($t) => [$t => 0])->all();
        Order::where('buyer_id', $request->user()->id)->get(['id', 'status', 'tracking_status', 'rating'])
            ->each(function ($o) use (&$counts) { $counts[OrderStatus::tab($o->canonical_status)]++; });

        return response()->json([
            'orders' => $orders->map(fn ($o) => BuyerPresenter::orderCard($o))->values(),
            'counts' => $counts,
        ]);
    }

    public function show(Request $request, Order $order)
    {
        $order = $this->find($request, $order)->load('seller', 'product', 'logistics', 'courier', 'events', 'returnRequest');
        return response()->json(['order' => BuyerPresenter::orderDetail($order)]);
    }

    /** BUY-C09 — only before the seller hands the parcel over. */
    public function cancel(Request $request, Order $order)
    {
        $order = $this->find($request, $order);
        $data = $request->validate(['reason' => 'required|string|max:200']);

        if (!in_array($order->canonical_status, [OrderStatus::PLACED, OrderStatus::PREPARING], true)) {
            return response()->json(['message' => 'This order can no longer be cancelled because it has already shipped.'], 422);
        }

        DB::transaction(function () use ($order, $data) {
            $order->forceFill(['cancel_reason' => $data['reason'], 'cancelled_at' => now()]);
            $order->update(['status' => 'cancelled']);

            // Put the stock back.
            Product::whereKey($order->product_id)->increment('stock', $order->quantity);
            if ($order->variation_ids) {
                ProductVariation::whereIn('id', $order->variation_ids)->increment('stock', $order->quantity);
            }
        });

        return $this->show($request, $order->fresh());
    }

    /** Rate a delivered order (doubles as the product review). */
    public function rate(Request $request, Order $order)
    {
        $order = $this->find($request, $order);
        $data = $request->validate([
            'rating'   => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:1000',
        ]);

        if ($order->canonical_status !== OrderStatus::DELIVERED) {
            return response()->json(['message' => 'You can rate an order once it has been delivered.'], 422);
        }

        $order->update($data + ['rated_at' => now()]);

        return $this->show($request, $order->fresh());
    }

    /** BUY-C10 — files a complaint into the admin disputes queue. */
    public function report(Request $request, Order $order)
    {
        $order = $this->find($request, $order);
        $data = $request->validate([
            'category'   => ['required', Rule::in(self::REPORT_CATEGORIES)],
            'details'    => 'required|string|min:10|max:2000',
            'evidence'   => 'nullable|array|max:3',
            'evidence.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ], ['details.min' => 'Please describe the issue in at least 10 characters.']);

        $paths = collect($request->file('evidence', []))->map(fn ($f) => $f->store('uploads/complaints', 'local'))->all();

        $complaint = Complaint::create([
            'filed_by'        => $request->user()->id,
            'against_user_id' => $order->seller_id,
            'order_id'        => $order->id,
            'category'        => $data['category'],
            'subject'         => "[{$order->order_number}] {$data['category']}",
            'details'         => $data['details'],
            'evidence_path'   => $paths[0] ?? null,
            'evidence_paths'  => $paths ?: null,
            'status'          => 'open',
        ]);

        return response()->json([
            'message' => 'Report submitted. Our support team will get back to you within 24–48 hours.',
            'ticket'  => ['id' => $complaint->id, 'reference' => 'TKT-' . str_pad($complaint->id, 6, '0', STR_PAD_LEFT), 'status' => 'open'],
        ], 201);
    }

    /** GET /buyer/support/tickets — BUY-A09 Support Ticket list. */
    public function tickets(Request $request)
    {
        $tickets = Complaint::where('filed_by', $request->user()->id)->with('order')->latest()->get()
            ->map(fn ($c) => [
                'id'           => $c->id,
                'reference'    => 'TKT-' . str_pad($c->id, 6, '0', STR_PAD_LEFT),
                'subject'      => $c->subject,
                'category'     => $c->category,
                'status'       => $c->status,
                'order_number' => $c->order?->order_number,
                'order_id'     => $c->order_id,
                'admin_notes'  => $c->status === 'resolved' || $c->status === 'dismissed' ? $c->admin_notes : null,
                'created_at'   => BuyerPresenter::date($c->created_at),
                'updated_at'   => BuyerPresenter::date($c->updated_at),
            ]);

        return response()->json(['tickets' => $tickets, 'categories' => self::REPORT_CATEGORIES]);
    }

    /** BUY-C11 — within the return window after delivery. */
    public function requestReturn(Request $request, Order $order)
    {
        $order = $this->find($request, $order)->load('returnRequest');
        $data = $request->validate([
            'quantity'   => "required|integer|min:1|max:{$order->quantity}",
            'reason'     => ['required', Rule::in(self::RETURN_REASONS)],
            'details'    => 'nullable|string|max:2000',
            // COD only: refunds are paid in cash by a rider. Older app builds sent wallets.
            'refund_to'  => 'nullable|in:cash',
            'evidence'   => 'nullable|array|max:4',
            'evidence.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ], ['refund_to.in' => 'Refunds are paid in cash by a Picksell rider.']);

        if (!BuyerPresenter::orderDetail($order->load('events'))['actions']['can_return']) {
            $days = config('picksell.return_window_days');
            return response()->json(['message' => "Returns can be requested within {$days} days of delivery, once per order."], 422);
        }

        $paths = collect($request->file('evidence', []))->map(fn ($f) => $f->store('uploads/returns', 'local'))->all();
        $return = $this->returns->open($order, $request->user(), $data, $paths);

        return response()->json([
            'message'        => 'Return request submitted.',
            'return_request' => BuyerPresenter::returnRequest($return),
        ], 201);
    }

    /** POST /buyer/orders/{order}/reorder — BUY-C13, current price & stock. */
    public function reorder(Request $request, Order $order)
    {
        $order = $this->find($request, $order);
        $product = Product::find($order->product_id);

        if (!$product || $product->status !== 'active' || $product->stock <= 0) {
            return response()->json(['message' => 'This item is currently unavailable.'], 422);
        }

        $variationIds = collect($order->variation_ids ?? [])
            ->filter(fn ($id) => ProductVariation::whereKey($id)->where('stock', '>', 0)->exists())->values()->all();
        $quantity = min($order->quantity, (int) $product->stock, (int) config('picksell.max_quantity_per_item'));
        $cart = Cart::firstOrCreate(['buyer_id' => $request->user()->id]);

        $item = CartItem::where('cart_id', $cart->id)->where('product_id', $product->id)->get()
            ->first(fn ($i) => ($i->variation_ids ?: []) == $variationIds);
        if ($item) {
            $item->update(['quantity' => min($item->quantity + $quantity, (int) $product->stock)]);
        } else {
            $item = CartItem::create([
                'cart_id' => $cart->id, 'product_id' => $product->id, 'quantity' => $quantity,
                'variation_id' => $variationIds[0] ?? null, 'variation_ids' => $variationIds ?: null,
            ]);
        }

        return response()->json([
            'message'      => "{$product->name} added to cart.",
            'cart_item_id' => $item->id,
            'price_changed' => $order->unit_price !== null && round($product->effective_price, 2) != round($order->unit_price, 2),
        ], 201);
    }

    /** GET /buyer/reorder — recently ordered products with current availability. */
    public function reorderCandidates(Request $request)
    {
        $orders = Order::where('buyer_id', $request->user()->id)->whereNotNull('product_id')
            ->with('product.seller', 'seller')->latest()->get()->unique('product_id')->take(20);

        return response()->json(['items' => $orders->map(function ($o) {
            $p = $o->product;
            $current = $p ? round($p->effective_price, 2) : null;
            return [
                'order_id'       => $o->id,
                'product'        => $p ? BuyerPresenter::product($p) : null,
                'product_name'   => $o->product_name,
                'seller_name'    => $o->seller?->business_name ?: $o->seller?->full_name,
                'last_price'     => BuyerPresenter::money($o->unit_price ?? $o->amount / max(1, $o->quantity)),
                'current_price'  => $current,
                'price_changed'  => $current !== null && $o->unit_price !== null && $current != round($o->unit_price, 2),
                'available'      => $p && $p->status === 'active' && $p->stock > 0,
                'last_ordered_at' => BuyerPresenter::date($o->created_at),
            ];
        })->values()]);
    }

    public function options()
    {
        return response()->json([
            'cancel_reasons' => [
                'Need to change delivery address', 'Need to change the variation or quantity',
                'Found a better price elsewhere', 'Ordered by mistake', 'Other',
            ],
            'report_categories' => self::REPORT_CATEGORIES,
            'return_reasons'    => self::RETURN_REASONS,
            'refund_methods'    => config('picksell.refund_methods'),
            'return_window_days' => (int) config('picksell.return_window_days'),
        ]);
    }
}
