<?php

namespace App\Http\Controllers;

use App\Mail\RegistrationApprovedMail;
use App\Mail\RegistrationDisapprovedMail;
use App\Models\Order;
use App\Models\User;
use App\Support\OrderStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class LogisticsController extends Controller
{
    public function dashboard()
    {
        $stats = [
            'pending_couriers' => User::where('role', 'courier')->where('status', 'pending')->count(),
            'approved_couriers' => User::where('role', 'courier')->where('status', 'approved')->count(),
            'to_sort' => Order::where('status', 'shipped')->whereNull('courier_id')->count(),
            'assigned' => Order::where('status', 'shipped')->whereNotNull('courier_id')->count(),
        ];

        $orders = Order::with(['buyer', 'courier'])->where('logistics_id', auth()->id())->whereIn('status', ['shipped', 'completed'])->latest()->take(10)->get();
        return view('logistics.dashboard', compact('stats', 'orders'));
    }

    public function applications(Request $request)
    {
        $status = $request->get('status', 'pending');
        $query = User::where('role', 'courier');
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $users = $query->latest()->paginate(15);
        return view('logistics.applications', compact('users', 'status'));
    }

    public function approveCourier(User $user)
    {
        abort_if($user->role !== 'courier', 404);
        $user->update(['status' => 'approved']);
        Mail::to($user->email)->send(new RegistrationApprovedMail($user));
        return back()->with('success', "Courier {$user->full_name} approved.");
    }

    public function disapproveCourier(Request $request, User $user)
    {
        abort_if($user->role !== 'courier', 404);
        $data = $request->validate(['reason' => 'required|string|max:500']);
        $user->update(['status' => 'disapproved']);

        try {
            Mail::to($user->email)->send(new RegistrationDisapprovedMail($user, $data['reason']));
        } catch (\Throwable $exception) {
            Log::warning('Courier disapproval email could not be sent.', ['user_id' => $user->id, 'error' => $exception->getMessage()]);
        }

        return back()->with('success', "Courier {$user->full_name} disapproved.");
    }

    public function parcels(Request $request)
    {
        $status = $request->get('status', 'all');
        $query = Order::with(['buyer', 'seller', 'courier'])->where('logistics_id', auth()->id())->whereIn('status', ['shipped', 'completed']);
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $orders = $query->latest()->paginate(15);
        $couriers = User::where('role', 'courier')->where('status', 'approved')->orderBy('delivery_area')->orderBy('last_name')->get();
        return view('logistics.parcels', compact('orders', 'couriers', 'status'));
    }

    public function scanParcel(Order $order)
    {
        OrderStatus::ensure($order, 'scan');
        $order->update(['tracking_status' => 'Received and scanned at sorting center']);
        return back()->with('success', "Parcel {$order->order_number} scanned.");
    }

    public function assignCourier(Request $request, Order $order)
    {
        $data = $request->validate(['courier_id' => 'required|exists:users,id']);
        $courier = User::where('id', $data['courier_id'])->where('role', 'courier')->where('status', 'approved')->firstOrFail();
        OrderStatus::ensure($order, 'assign');

        $order->update([
            'courier_id' => $courier->id,
            'tracking_status' => 'Sorted for ' . $order->delivery['area'] . '; assigned to ' . $courier->full_name,
        ]);

        return back()->with('success', "Parcel {$order->order_number} assigned to {$courier->full_name}.");
    }
}
