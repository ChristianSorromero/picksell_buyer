<?php

namespace App\Http\Controllers;

use App\Mail\NewMessageMail;
use App\Models\Message;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Services\Deliveries;
use App\Support\OrderStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

class SellerController extends Controller
{
    private function seller() { return auth()->user(); }

    // Dashboard
    public function dashboard()
    {
        $seller = $this->seller();
        $stats = [
            'total_orders'     => Order::where('seller_id', $seller->id)->count(),
            'pending_orders'   => Order::where('seller_id', $seller->id)->where('status', 'pending')->count(),
            'completed_orders' => Order::where('seller_id', $seller->id)->where('status', 'completed')->count(),
            'total_sales'      => Order::where('seller_id', $seller->id)->where('status', 'completed')->sum('amount'),
            'total_products'   => Product::where('seller_id', $seller->id)->where('status', 'active')->count(),
            'low_stock'        => Product::where('seller_id', $seller->id)->where('status', 'active')->where('stock', '<=', 5)->count(),
        ];

        // Monthly sales for chart (last 6 months)
        $months = [];
        $sales  = [];
        for ($i = 5; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $months[] = $date->format('M Y');
            $sales[]  = Order::where('seller_id', $seller->id)
                ->where('status', 'completed')
                ->whereYear('created_at', $date->year)
                ->whereMonth('created_at', $date->month)
                ->sum('amount');
        }

        $recentOrders = Order::where('seller_id', $seller->id)->with('buyer')->latest()->take(5)->get();

        return view('seller.dashboard', compact('stats', 'months', 'sales', 'recentOrders'));
    }

    // Inventory
    public function inventory(Request $request)
    {
        $status = $request->get('status', 'active');
        $search = $request->get('search');
        $query  = Product::where('seller_id', $this->seller()->id);
        if ($status !== 'all') $query->where('status', $status);
        if ($search) $query->where('name', 'like', "%$search%");
        $products = $query->latest()->paginate(15);
        return view('seller.inventory', compact('products', 'status', 'search'));
    }

    public function storeProduct(Request $request)
    {
        $data = $request->validate([
            'name'             => 'required|string|max:255',
            'description'      => 'nullable|string',
            'category'         => 'nullable|string|max:100',
            'price'            => 'required|numeric|min:0',
            'discount'         => 'nullable|numeric|min:0|max:100',
            'voucher_code'     => 'nullable|string|max:50',
            'voucher_discount' => 'nullable|numeric|min:0|max:100',
            'stock'            => 'required|integer|min:0',
            'image'            => 'nullable|image|max:2048',
        ]);
        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store('products', 'public');
        }

        $data['seller_id'] = $this->seller()->id;
        Product::create($data);

        return back()->with('success', 'Product added successfully.');
    }

    public function updateProduct(Request $request, Product $product)
    {
        abort_if($product->seller_id !== $this->seller()->id, 403);

        $data = $request->validate([
            'name'             => 'required|string|max:255',
            'description'      => 'nullable|string',
            'category'         => 'nullable|string|max:100',
            'price'            => 'required|numeric|min:0',
            'discount'         => 'nullable|numeric|min:0|max:100',
            'voucher_code'     => 'nullable|string|max:50',
            'voucher_discount' => 'nullable|numeric|min:0|max:100',
            'stock'            => 'required|integer|min:0',
            'image'            => 'nullable|image|max:2048',
        ]);
        if ($request->hasFile('image')) {
            if ($product->image) Storage::disk('public')->delete($product->image);
            $data['image'] = $request->file('image')->store('products', 'public');
        }

        $product->update($data);
        return back()->with('success', 'Product updated.');
    }

    public function archiveProduct(Product $product)
    {
        abort_if($product->seller_id !== $this->seller()->id, 403);
        $product->update(['status' => $product->status === 'archived' ? 'active' : 'archived']);
        return back()->with('success', 'Product status updated.');
    }

    // Orders
    public function orders(Request $request)
    {
        $status = $request->get('status', 'all');
        $query  = Order::where('seller_id', $this->seller()->id)->with('buyer');
        if ($status !== 'all') $query->where('status', $status);
        $orders = $query->latest()->paginate(15);
        return view('seller.orders', compact('orders', 'status'));
    }

    public function showOrder(Order $order)
    {
        abort_if($order->seller_id !== $this->seller()->id, 403);
        $order->load('buyer', 'courier');
        return view('seller.order-detail', compact('order'));
    }

    /** A parcel returned after failed deliveries is back with the seller. */
    public function receiveReturnedParcel(Request $request, Order $order, Deliveries $deliveries)
    {
        abort_if($order->seller_id !== $this->seller()->id, 403);
        $data = $request->validate(['restock' => 'required|boolean']);
        $deliveries->receiveReturned($order, $this->seller(), (bool) $data['restock']);
        return back()->with('success', 'Returned parcel received' . ($data['restock'] ? ' and put back in stock.' : '.'));
    }

    public function packOrder(Order $order)
    {
        abort_if($order->seller_id !== $this->seller()->id, 403);
        OrderStatus::ensure($order, 'pack');
        $order->update(['status' => 'processing', 'packed_at' => now()]);
        return back()->with('success', 'Order marked as packed.');
    }

    public function handoverOrder(Request $request, Order $order)
    {
        abort_if($order->seller_id !== $this->seller()->id, 403);
        OrderStatus::ensure($order, 'handover');
        $data = $request->validate(['waybill_number' => 'required|string|max:100']);
        $order->update([
            'status'         => 'shipped',
            'waybill_number' => $data['waybill_number'],
            'handed_over_at' => now(),
            'tracking_status' => 'Handed over to courier',
        ]);
        return back()->with('success', 'Order handed over to courier.');
    }

    // Reports
    public function reports(Request $request)
    {
        $seller = $this->seller();
        $from   = $request->get('from', now()->startOfMonth()->format('Y-m-d'));
        $to     = $request->get('to', now()->format('Y-m-d'));

        $orders = Order::where('seller_id', $seller->id)
            ->where('status', 'completed')
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->get();

        $totalSales  = $orders->sum('amount');
        $totalOrders = $orders->count();
        $totalProfit = $orders->sum(fn($o) => $o->amount - $o->commission);

        // Daily breakdown
        $days   = [];
        $dailySales = [];
        $start  = \Carbon\Carbon::parse($from);
        $end    = \Carbon\Carbon::parse($to);
        while ($start->lte($end)) {
            $day = $start->format('Y-m-d');
            $days[] = $start->format('M d');
            $dailySales[] = $orders->filter(fn($o) => $o->created_at->format('Y-m-d') === $day)->sum('amount');
            $start->addDay();
        }

        // Top products
        $topProducts = $orders->groupBy('product_name')
            ->map(fn($g) => ['name' => $g->first()->product_name, 'sales' => $g->sum('amount'), 'count' => $g->count()])
            ->sortByDesc('sales')->take(5)->values();

        return view('seller.reports', compact('from', 'to', 'totalSales', 'totalOrders', 'totalProfit', 'days', 'dailySales', 'topProducts'));
    }

    // Chat
    public function chat(Request $request)
    {
        $seller = $this->seller();

        // Show only buyers who have messaged the seller or placed an order.
        $chattedBuyerIds = Message::where(function ($q) use ($seller) {
            $q->where('sender_id', $seller->id)->orWhere('receiver_id', $seller->id);
        })->get()->map(fn($m) => $m->sender_id === $seller->id ? $m->receiver_id : $m->sender_id)
          ->unique()->values();

        $orderedBuyerIds = Order::where('seller_id', $seller->id)
            ->pluck('buyer_id');

        $contactIds = $chattedBuyerIds->merge($orderedBuyerIds)->unique()->values();

        $users = User::whereIn('id', $contactIds)
            ->where('role', 'buyer')->where('status', 'approved')->get();

        // Include admin only if seller has already messaged them
        $admin = User::where('role', 'admin')->first();
        if ($admin && $chattedBuyerIds->contains($admin->id)) {
            $users->prepend($admin);
        }

        $activeUserId = $request->get('user');
        $activeUser   = $activeUserId ? User::find($activeUserId) : null;
        $messages     = collect();

        if ($activeUser) {
            Message::where('sender_id', $activeUserId)->where('receiver_id', $seller->id)->update(['read' => true]);
            $messages = Message::where(function ($q) use ($seller, $activeUserId) {
                $q->where('sender_id', $seller->id)->where('receiver_id', $activeUserId);
            })->orWhere(function ($q) use ($seller, $activeUserId) {
                $q->where('sender_id', $activeUserId)->where('receiver_id', $seller->id);
            })->with('product')->orderBy('created_at')->get();
        }

        // Product context: from last message with product in this conversation
        $product = $messages->isNotEmpty() ? $messages->whereNotNull('product_id')->last()?->product : null;

        $users = $users->map(function ($u) use ($seller) {
            $u->unread = Message::where('sender_id', $u->id)->where('receiver_id', $seller->id)->where('read', false)->count();
            return $u;
        });

        return view('seller.chat', compact('users', 'activeUser', 'messages', 'product'));
    }

    public function sendMessage(Request $request)
    {
        $request->validate(['receiver_id' => 'required|exists:users,id', 'body' => 'required|string|max:2000']);
        $msg = Message::create(['sender_id' => auth()->id(), 'receiver_id' => $request->receiver_id, 'body' => $request->body, 'read' => false]);
        $msg->load('sender', 'receiver', 'product');
        \Illuminate\Support\Facades\Mail::to($msg->receiver->email)->send(new NewMessageMail($msg));
        return back();
    }

    // Account
    public function account()
    {
        return view('seller.account');
    }

    public function updateAccount(Request $request)
    {
        $request->validate([
            'first_name'    => 'required|string|max:100',
            'last_name'     => 'required|string|max:100',
            'middle_initial' => 'nullable|string|max:5',
            'sex'           => 'required|in:Male,Female',
            'birthday'      => 'required|date|before:-18 years',
            'email'         => 'required|email|unique:users,email,' . auth()->id(),
            'contact_no'    => 'required|string|max:20',
            'business_name' => 'nullable|string|max:255',
            'line_of_business' => 'nullable|string|max:255',
        ]);
        auth()->user()->update($request->only('first_name', 'last_name', 'middle_initial', 'sex', 'birthday', 'email', 'contact_no', 'business_name', 'line_of_business'));
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
