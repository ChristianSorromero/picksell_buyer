<?php

namespace App\Http\Controllers;

use App\Mail\NewMessageMail;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Message;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class BuyerController extends Controller
{
    private function buyer() { return auth()->user(); }

    private function getCart()
    {
        return Cart::firstOrCreate(['buyer_id' => $this->buyer()->id]);
    }

    // Home / Shop
    public function home(Request $request)
    {
        $search   = $request->get('search');
        $category = $request->get('category');

        $query = Product::where('status', 'active')->where('stock', '>', 0)->with('seller');

        if ($search)   $query->where('name', 'like', "%$search%");
        if ($category) $query->where('category', $category);

        $products   = $query->latest()->paginate(12);
        $recommendedProducts = Product::where('status', 'active')
            ->where('stock', '>', 0)
            ->with('seller')
            ->latest()
            ->take(8)
            ->get();
        $categories = Product::where('status', 'active')->whereNotNull('category')->distinct()->pluck('category');
        $cartCount  = CartItem::whereHas('cart', fn($q) => $q->where('buyer_id', $this->buyer()->id))->count();

        return view('buyer.home', compact('products', 'recommendedProducts', 'categories', 'search', 'category', 'cartCount'));
    }

    // Product Detail
    public function productDetail(Product $product)
    {
        abort_if($product->status !== 'active', 404);
        $product->load('seller', 'variations');
        $cartCount = CartItem::whereHas('cart', fn($q) => $q->where('buyer_id', $this->buyer()->id))->count();
        return view('buyer.product-detail', compact('product', 'cartCount'));
    }

    // Add to Cart
    public function addToCart(Request $request, Product $product)
    {
        $data = $request->validate([
            'quantity'     => 'required|integer|min:1',
            'variation_id' => 'nullable|exists:product_variations,id',
        ]);

        $cart = $this->getCart();

        $existing = CartItem::where('cart_id', $cart->id)
            ->where('product_id', $product->id)
            ->where('variation_id', $data['variation_id'] ?? null)
            ->first();

        if ($existing) {
            $existing->increment('quantity', $data['quantity']);
        } else {
            CartItem::create([
                'cart_id'      => $cart->id,
                'product_id'   => $product->id,
                'variation_id' => $data['variation_id'] ?? null,
                'quantity'     => $data['quantity'],
            ]);
        }

        return redirect()->route('buyer.cart')->with('success', 'Item added to cart.');
    }

    // Cart
    public function cart()
    {
        $cart  = $this->getCart();
        $items = CartItem::where('cart_id', $cart->id)->with('product.seller', 'variation')->get();
        $cartCount = $items->count();
        $logisticsProviders = User::where('role', 'logistics')
            ->where('status', 'approved')
            ->orderBy('business_name')
            ->orderBy('last_name')
            ->get();
        return view('buyer.cart', compact('items', 'cartCount', 'logisticsProviders'));
    }

    public function updateCart(Request $request, CartItem $item)
    {
        abort_if($item->cart->buyer_id !== $this->buyer()->id, 403);
        $request->validate(['quantity' => 'required|integer|min:1']);
        $item->update(['quantity' => $request->quantity]);
        return back();
    }

    public function removeFromCart(CartItem $item)
    {
        abort_if($item->cart->buyer_id !== $this->buyer()->id, 403);
        $item->delete();
        return back()->with('success', 'Item removed from cart.');
    }

    // Place Order
    public function placeOrder(Request $request)
    {
        $request->validate([
            'item_ids'       => 'required|array',
            'item_ids.*'     => 'exists:cart_items,id',
            'payment_method' => 'required|in:cod,gcash,bank_transfer',
            'logistics_id'   => 'required|exists:users,id',
            'voucher_code'   => 'nullable|string',
        ]);

        $logisticsProvider = User::where('id', $request->logistics_id)
            ->where('role', 'logistics')
            ->where('status', 'approved')
            ->firstOrFail();

        $cart  = $this->getCart();
        $items = CartItem::whereIn('id', $request->item_ids)
            ->where('cart_id', $cart->id)
            ->with('product')
            ->get();

        if ($items->isEmpty()) return back()->withErrors(['item_ids' => 'No items selected.']);

        foreach ($items as $item) {
            $product = $item->product;
            $price   = $product->effective_price;

            // Apply voucher if valid
            if ($request->voucher_code && $product->voucher_code === $request->voucher_code) {
                $price = $price * (1 - $product->voucher_discount / 100);
            }

            $amount     = $price * $item->quantity;
            $commission = $amount * 0.10;

            Order::create([
                'order_number'   => 'ORD-' . strtoupper(Str::random(8)),
                'product_id'     => $product->id,
                'buyer_id'       => $this->buyer()->id,
                'seller_id'      => $product->seller_id,
                'logistics_id'   => $logisticsProvider->id,
                'product_name'   => $product->name,
                'quantity'       => $item->quantity,
                'amount'         => $amount,
                'commission'     => $commission,
                'status'         => 'pending',
            ]);

            // Deduct stock
            $product->decrement('stock', $item->quantity);
            $item->delete();
        }

        return redirect()->route('buyer.orders')->with('success', 'Order placed successfully!');
    }

    // Orders
    public function orders(Request $request)
    {
        $status = $request->get('status', 'all');
        $query  = Order::where('buyer_id', $this->buyer()->id)->with('product', 'seller');
        if ($status !== 'all') $query->where('status', $status);
        $orders    = $query->latest()->paginate(10);
        $cartCount = CartItem::whereHas('cart', fn($q) => $q->where('buyer_id', $this->buyer()->id))->count();
        return view('buyer.orders', compact('orders', 'status', 'cartCount'));
    }

    public function submitFeedback(Request $request, Order $order)
    {
        abort_if($order->buyer_id !== $this->buyer()->id, 403);
        $request->validate([
            'rating'   => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:1000',
        ]);
        $order->update(['rating' => $request->rating, 'feedback' => $request->feedback]);
        return back()->with('success', 'Feedback submitted. Thank you!');
    }

    // Chat
    public function chat(Request $request)
    {
        $buyer = $this->buyer();

        // Show only sellers the buyer has messaged or ordered from.
        $chattedUserIds = Message::where(function ($q) use ($buyer) {
            $q->where('sender_id', $buyer->id)->orWhere('receiver_id', $buyer->id);
        })->get()->map(fn($m) => $m->sender_id === $buyer->id ? $m->receiver_id : $m->sender_id)
          ->unique()->values();

        $orderedSellerIds = Order::where('buyer_id', $buyer->id)
            ->pluck('seller_id');

        $contactIds = $chattedUserIds->merge($orderedSellerIds)->unique()->values();

        $contacts = User::whereIn('id', $contactIds)
            ->where('role', 'seller')->where('status', 'approved')->get();

        // Include admin only if buyer has already messaged them
        $admin = User::where('role', 'admin')->first();
        if ($admin && $chattedUserIds->contains($admin->id)) {
            $contacts->prepend($admin);
        }

        $activeUserId = $request->get('user');
        // If coming from product page with seller_id, auto-open that seller
        if (!$activeUserId && $request->get('seller')) {
            $activeUserId = $request->get('seller');
        }
        $activeUser = $activeUserId ? User::find($activeUserId) : null;
        $messages   = collect();
        $product    = null;

        if ($activeUser) {
            Message::where('sender_id', $activeUserId)->where('receiver_id', $buyer->id)->update(['read' => true]);
            $messages = Message::where(function ($q) use ($buyer, $activeUserId) {
                $q->where('sender_id', $buyer->id)->where('receiver_id', $activeUserId);
            })->orWhere(function ($q) use ($buyer, $activeUserId) {
                $q->where('sender_id', $activeUserId)->where('receiver_id', $buyer->id);
            })->with('product')->orderBy('created_at')->get();

            // If seller not yet in contacts, add them
            if ($activeUser->role === 'seller' && !$contacts->contains('id', $activeUser->id)) {
                $contacts->push($activeUser);
            }
        }

        // Product context: from URL param first, fallback to last message with product
        if ($request->get('product')) {
            $product = \App\Models\Product::find($request->get('product'));
        } elseif ($messages->isNotEmpty()) {
            $product = $messages->whereNotNull('product_id')->last()?->product;
        }

        $contacts = $contacts->map(function ($u) use ($buyer) {
            $u->unread = Message::where('sender_id', $u->id)->where('receiver_id', $buyer->id)->where('read', false)->count();
            return $u;
        });

        $cartCount = CartItem::whereHas('cart', fn($q) => $q->where('buyer_id', $buyer->id))->count();

        return view('buyer.chat', compact('contacts', 'activeUser', 'messages', 'cartCount', 'product'));
    }

    public function sendMessage(Request $request)
    {
        $request->validate([
            'receiver_id' => 'required|exists:users,id',
            'body'        => 'required|string|max:2000',
            'product_id'  => 'nullable|exists:products,id',
        ]);
        $msg = Message::create([
            'sender_id'   => auth()->id(),
            'receiver_id' => $request->receiver_id,
            'body'        => $request->body,
            'product_id'  => $request->product_id,
            'read'        => false,
        ]);
        $msg->load('sender', 'receiver', 'product');
        \Illuminate\Support\Facades\Mail::to($msg->receiver->email)->send(new NewMessageMail($msg));
        $redirect = '/buyer/chat?user=' . $request->receiver_id;
        if ($request->product_id) $redirect .= '&product=' . $request->product_id;
        return redirect($redirect);
    }

    // Account
    public function account()
    {
        $cartCount = CartItem::whereHas('cart', fn($q) => $q->where('buyer_id', $this->buyer()->id))->count();
        return view('buyer.account', compact('cartCount'));
    }

    public function updateAccount(Request $request)
    {
        $request->validate([
            'first_name'     => 'required|string|max:100',
            'last_name'      => 'required|string|max:100',
            'middle_initial' => 'nullable|string|max:5',
            'sex'            => 'required|in:Male,Female',
            'email'          => 'required|email|unique:users,email,' . auth()->id(),
            'contact_no'     => ['required', 'regex:/^09\d{9}$/'],
            'birthday'       => 'required|date|before:-18 years',
            'province'       => 'nullable|string|max:120',
            'municipality'   => 'nullable|string|max:120',
            'barangay'       => 'nullable|string|max:120',
            'street'         => 'nullable|string|max:255',
            'house_no'       => 'nullable|string|max:100',
        ]);

        auth()->user()->update($request->only([
            'first_name',
            'last_name',
            'middle_initial',
            'sex',
            'email',
            'contact_no',
            'birthday',
            'province',
            'municipality',
            'barangay',
            'street',
            'house_no',
        ]));

        if ($request->expectsJson()) {
            return response()->json([
                'success' => true,
                'message' => 'Account updated successfully.',
                'user' => auth()->user()->fresh(),
            ]);
        }

        return back()->with('success', 'Account updated successfully.');
    }

    public function updatePassword(Request $request)
    {
        $request->validate(['current_password' => 'required', 'password' => 'required|min:8|confirmed']);
        if (!Hash::check($request->current_password, auth()->user()->password)) {
            return back()->withErrors(['current_password' => 'Current password is incorrect.']);
        }
        auth()->user()->update(['password' => Hash::make($request->password)]);
        return back()->with('success', 'Password changed successfully.');
    }
}
