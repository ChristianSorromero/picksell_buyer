<?php

namespace App\Http\Controllers;

use App\Mail\NewMessageMail;
use App\Models\Message;
use App\Models\Order;
use App\Support\OrderStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

class CourierController extends Controller
{
    private function courier()
    {
        return auth()->user();
    }

    public function dashboard(Request $request)
    {
        $courier = $this->courier();
        $status = $request->get('status', 'all');
        $query = Order::where('courier_id', $courier->id)->with(['buyer', 'seller']);
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $orders = $query->latest()->paginate(15);
        $stats = [
            'assigned' => Order::where('courier_id', $courier->id)->whereIn('status', ['shipped', 'processing'])->count(),
            'in_transit' => Order::where('courier_id', $courier->id)->where('status', 'shipped')->count(),
            'delivered' => Order::where('courier_id', $courier->id)->where('status', 'completed')->count(),
            'earnings' => Order::where('courier_id', $courier->id)->where('status', 'completed')->sum('commission'),
        ];

        return view('courier.dashboard', compact('orders', 'status', 'stats'));
    }

    public function updateStatus(Request $request, Order $order)
    {
        abort_if($order->courier_id !== $this->courier()->id, 403);

        $data = $request->validate([
            'status' => 'required|in:shipped,completed',
        ]);
        OrderStatus::ensure($order, $data['status'] === 'shipped' ? 'out_for_delivery' : 'deliver');

        $updates = ['status' => $data['status']];
        if ($data['status'] === 'shipped') {
            $updates['tracking_status'] = 'Out for delivery';
        } else {
            $updates['tracking_status'] = 'Delivered';
            $updates['delivered_at'] = now();
        }

        $order->update($updates);

        return back()->with('success', $data['status'] === 'completed'
            ? 'Parcel marked as delivered.'
            : 'Parcel marked as out for delivery.');
    }

    public function reports(Request $request)
    {
        $from = $request->get('from', now()->startOfMonth()->format('Y-m-d'));
        $to = $request->get('to', now()->format('Y-m-d'));
        $orders = Order::where('courier_id', $this->courier()->id)
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->latest()
            ->get();

        return view('courier.reports', [
            'from' => $from,
            'to' => $to,
            'orders' => $orders,
            'totalOrders' => $orders->count(),
            'deliveredOrders' => $orders->where('status', 'completed')->count(),
            'earnings' => $orders->where('status', 'completed')->sum('commission'),
        ]);
    }

    public function chat(Request $request)
    {
        $courier = $this->courier();
        $contactIds = Message::where(function ($query) use ($courier) {
            $query->where('sender_id', $courier->id)->orWhere('receiver_id', $courier->id);
        })->get()->map(fn ($message) => $message->sender_id === $courier->id ? $message->receiver_id : $message->sender_id)->unique();

        $contacts = \App\Models\User::whereIn('id', $contactIds)->get();
        $activeUserId = $request->get('user');
        $activeUser = $activeUserId ? \App\Models\User::find($activeUserId) : null;
        $messages = collect();

        if ($activeUser) {
            $messages = Message::where(function ($query) use ($courier, $activeUserId) {
                $query->where('sender_id', $courier->id)->where('receiver_id', $activeUserId);
            })->orWhere(function ($query) use ($courier, $activeUserId) {
                $query->where('sender_id', $activeUserId)->where('receiver_id', $courier->id);
            })->orderBy('created_at')->get();
        }

        return view('courier.chat', compact('contacts', 'activeUser', 'messages'));
    }

    public function sendMessage(Request $request)
    {
        $data = $request->validate([
            'receiver_id' => 'required|exists:users,id',
            'message' => 'required|string|max:2000',
        ]);

        $message = Message::create([
            'sender_id' => $this->courier()->id,
            'receiver_id' => $data['receiver_id'],
            'body' => $data['message'],
            'read' => false,
        ]);

        try {
            Mail::to($message->receiver->email)->send(new NewMessageMail($message));
        } catch (\Throwable $exception) {
            report($exception);
        }

        return back()->with('success', 'Message sent.');
    }

    public function account()
    {
        return view('courier.account', ['courier' => $this->courier()]);
    }

    public function updateAccount(Request $request)
    {
        $data = $request->validate([
            'first_name' => 'required|string|max:100',
            'last_name' => 'required|string|max:100',
            'contact_no' => ['required', 'regex:/^09\d{9}$/'],
            'delivery_area' => 'required|string|max:255',
        ]);

        $this->courier()->update($data);
        return back()->with('success', 'Account details updated.');
    }

    public function updatePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => 'required',
            'password' => 'required|min:8|confirmed',
        ]);

        if (!Hash::check($data['current_password'], $this->courier()->password)) {
            return back()->withErrors(['current_password' => 'Current password is incorrect.']);
        }

        $this->courier()->update(['password' => Hash::make($data['password'])]);
        return back()->with('success', 'Password updated.');
    }
}
