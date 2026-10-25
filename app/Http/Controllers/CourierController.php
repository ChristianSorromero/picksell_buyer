<?php

namespace App\Http\Controllers;

use App\Mail\NewMessageMail;
use App\Models\Message;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Payout;
use App\Models\ReturnRequest;
use App\Services\CodPayments;
use App\Services\Ledger;
use App\Services\ReturnWorkflow;
use App\Support\Money;
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

    public function dashboard(Request $request, Ledger $ledger)
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
            // Rider pay accrued at settlement (see config picksell.finance).
            'earnings' => -$ledger->balance(Ledger::RIDER_PAYABLE, $courier->id) + (int) Payout::where('payee_id', $courier->id)->where('status', 'completed')->sum('amount_cents'),
            'cash_on_hand' => $ledger->balance(Ledger::RIDER_CASH, $courier->id),
        ];
        $refunds = ReturnRequest::with('order')->where('refund_courier_id', $courier->id)
            ->whereNotNull('refund_released_at')->whereNull('refunded_at')->get();

        return view('courier.dashboard', compact('orders', 'status', 'stats', 'refunds'));
    }

    public function updateStatus(Request $request, Order $order, CodPayments $cod)
    {
        abort_if($order->courier_id !== $this->courier()->id, 403);

        $data = $request->validate([
            'status'         => 'required|in:shipped,completed',
            'cash_collected' => 'required_if:status,completed|nullable|numeric|min:0',
        ]);

        if ($data['status'] === 'completed') {
            // Delivery and the COD cash are recorded together, or not at all.
            $cod->deliverAndCollect($order, $this->courier(), (string) $data['cash_collected']);
            return back()->with('success', 'Parcel delivered and ' . Money::format($order->totalCents()) . ' cash collected. Hand it in at the sorting center.');
        }

        OrderStatus::ensure($order, 'out_for_delivery');
        $order->update(['status' => 'shipped', 'tracking_status' => 'Out for delivery']);

        return back()->with('success', 'Parcel marked as out for delivery.');
    }

    /** The rider hands an approved refund to the buyer, collecting the item when it must come back. */
    public function handOverRefund(Request $request, ReturnRequest $returnRequest, ReturnWorkflow $workflow)
    {
        $data = $request->validate(['amount' => 'required|numeric|min:0', 'item_collected' => 'nullable|boolean']);
        $workflow->handOverRefund($returnRequest, $this->courier(), (string) $data['amount'], (bool) ($data['item_collected'] ?? false));
        return back()->with('success', "Refund for return #{$returnRequest->id} recorded as handed over.");
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
            // Settled rider pay for these orders; 0 until a rider fee policy is configured.
            'earningsCents' => -(int) LedgerEntry::where('account', Ledger::RIDER_PAYABLE)->where('user_id', $this->courier()->id)
                ->where('amount_cents', '<', 0)->whereIn('order_id', $orders->pluck('id'))->sum('amount_cents'),
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
