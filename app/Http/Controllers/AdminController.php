<?php

namespace App\Http\Controllers;

use App\Mail\AccountStatusChangedMail;
use App\Mail\RegistrationApprovedMail;
use App\Mail\RegistrationDisapprovedMail;
use App\Mail\SellerWarningMail;
use App\Models\Announcement;
use App\Models\Complaint;
use App\Models\PlatformSetting;
use App\Models\Message;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Support\OrderStatus;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class AdminController extends Controller
{
    // Dashboard
    public function dashboard()
    {
        $stats = [
            'pending'   => User::where('status', 'pending')->count(),
            'buyers'    => User::where('role', 'buyer')->where('status', 'approved')->count(),
            'sellers'   => User::where('role', 'seller')->where('status', 'approved')->count(),
            'couriers'  => User::where('role', 'courier')->where('status', 'approved')->count(),
            'total'     => User::whereIn('role', ['buyer', 'seller', 'courier'])->count(),
            'suspended' => User::where('status', 'suspended')->count(),
        ];
        $recentApps = User::whereIn('role', ['buyer', 'seller', 'courier'])
            ->where('status', 'pending')->latest()->take(5)->get();
        return view('admin.dashboard', compact('stats', 'recentApps'));
    }

    public function products(Request $request)
    {
        $search = $request->get('search');
        $query = Product::with('seller')->latest();
        if ($search) $query->where('name', 'like', "%{$search}%");
        $products = $query->paginate(15);
        return view('admin.products', compact('products', 'search'));
    }

    public function toggleFeatured(Product $product)
    {
        $product->update(['is_featured' => !$product->is_featured]);
        return back()->with('success', $product->is_featured
            ? 'Product added to Featured Products.'
            : 'Product removed from Featured Products.');
    }

    // Registrations
    public function registrations(Request $request)
    {
        $role   = $request->get('role', 'all');
        $status = $request->get('status', 'pending');
        $query  = User::whereIn('role', ['buyer', 'seller', 'courier', 'logistics']);
        if ($role !== 'all') $query->where('role', $role);
        if ($status !== 'all') $query->where('status', $status);
        $users = $query->latest()->paginate(15);
        return view('admin.registrations', compact('users', 'role', 'status'));
    }

    public function showApplication(User $user)
    {
        return view('admin.application-detail', compact('user'));
    }

    public function approveUser(User $user)
    {
        abort_if($user->role === 'courier', 403, 'Courier applications must be reviewed by Logistics.');
        $user->update(['status' => 'approved']);
        Mail::to($user->email)->send(new RegistrationApprovedMail($user));
        $this->notifyAdmin("Registration approved for {$user->full_name} ({$user->email})");
        return back()->with('success', "Account of {$user->full_name} approved. Notification sent to {$user->email}.");
    }

    public function disapproveUser(Request $request, User $user)
    {
        abort_if($user->role === 'courier', 403, 'Courier applications must be reviewed by Logistics.');
        $request->validate(['reason' => 'required|string|max:500']);
        $user->update(['status' => 'disapproved']);
        $emailSent = true;
        try {
            Mail::to($user->email)->send(new RegistrationDisapprovedMail($user, $request->reason));
        } catch (\Throwable $exception) {
            $emailSent = false;
            Log::warning('Registration disapproval email could not be sent.', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $exception->getMessage(),
            ]);
        }
        $this->notifyAdmin("Registration disapproved for {$user->full_name} ({$user->email})");
        $response = back()->with('success', "Account of {$user->full_name} disapproved.");
        return $emailSent
            ? $response->with('success', "Account of {$user->full_name} disapproved. Notification sent.")
            : $response->with('warning', 'The account was disapproved, but the notification email could not be sent. Check the mail settings.');
    }

    // User Accounts
    public function users(Request $request)
    {
        $role   = $request->get('role', 'all');
        $status = $request->get('status', 'all');
        $search = $request->get('search');
        $query  = User::whereIn('role', ['buyer', 'seller', 'courier', 'logistics']);
        if ($role !== 'all') $query->where('role', $role);
        if ($status !== 'all') $query->where('status', $status);
        if ($search) $query->where(function ($q) use ($search) {
            $q->where('first_name', 'like', "%$search%")
              ->orWhere('last_name', 'like', "%$search%")
              ->orWhere('email', 'like', "%$search%");
        });
        $users = $query->latest()->paginate(15);
        return view('admin.users', compact('users', 'role', 'status', 'search'));
    }

    public function updateUserStatus(Request $request, User $user)
    {
        $request->validate(['status' => 'required|in:approved,suspended,deactivated']);
        if ($user->isAnonymized()) {
            return back()->withErrors(['status' => 'This account was deleted by its owner and can’t be reactivated.']);
        }
        $user->update(['status' => $request->status]);
        $emailSent = true;
        try {
            Mail::to($user->email)->send(new AccountStatusChangedMail($user, $request->status));
        } catch (\Throwable $exception) {
            $emailSent = false;
            Log::warning('Account status email could not be sent.', [
                'user_id' => $user->id,
                'status' => $request->status,
                'email' => $user->email,
                'error' => $exception->getMessage(),
            ]);
        }
        $this->notifyAdmin("Account of {$user->full_name} set to {$request->status}");
        $response = back()->with('success', "Account status updated to {$request->status}.");
        return $emailSent
            ? $response
            : $response->with('warning', 'The account status was updated, but the notification email could not be sent. Check the mail settings.');
    }

    // Seller Compliance
    public function compliance(Request $request)
    {
        $sellers = User::where('role', 'seller')->where('status', 'approved')->latest()->paginate(15);
        return view('admin.compliance', compact('sellers'));
    }

    public function warnSeller(Request $request, User $user)
    {
        $request->validate(['warning' => 'required|string|max:500']);
        Mail::to($user->email)->send(new SellerWarningMail($user, $request->warning));
        $this->notifyAdmin("Warning issued to seller {$user->full_name}");
        return back()->with('success', "Warning issued to {$user->full_name} and email sent.");
    }

    // Complaints
    public function complaints(Request $request)
    {
        $status = $request->get('status', 'all');
        $query  = Complaint::with(['filer', 'against']);
        if ($status !== 'all') $query->where('status', $status);
        $complaints = $query->latest()->paginate(15);
        $users = User::whereIn('role', ['buyer', 'seller', 'courier'])->where('status', 'approved')->get();
        return view('admin.complaints', compact('complaints', 'status', 'users'));
    }

    public function showComplaint(Complaint $complaint)
    {
        $complaint->load(['filer', 'against']);
        return view('admin.complaint-detail', compact('complaint'));
    }

    public function updateComplaint(Request $request, Complaint $complaint)
    {
        $request->validate([
            'status'      => 'required|in:open,under_review,resolved,dismissed',
            'admin_notes' => 'nullable|string|max:2000',
        ]);
        $complaint->update($request->only('status', 'admin_notes'));
        return back()->with('success', 'Complaint updated successfully.');
    }

    // Commission
    public function commission(Request $request)
    {
        $rate = (string) \Brick\Math\BigDecimal::of((string) config('picksell.commission_rate'))->multipliedBy(100)->strippedOfTrailingZeros(); // percent, for display
        $from = $request->get('from', now()->startOfMonth()->format('Y-m-d'));
        $to   = $request->get('to', now()->format('Y-m-d'));

        $orders = Order::with('seller')
            ->where('status', 'completed')
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->latest()->get();

        $totalSales      = $orders->sum('amount');
        $totalCommission = $orders->sum('commission');

        return view('admin.commission', compact('orders', 'rate', 'totalSales', 'totalCommission', 'from', 'to'));
    }

    // Reports
    public function reports(Request $request)
    {
        $from = $request->get('from', now()->startOfMonth()->format('Y-m-d'));
        $to   = $request->get('to', now()->format('Y-m-d'));
        $data = $this->getReportData($from, $to);
        return view('admin.reports', compact('data', 'from', 'to'));
    }

    public function exportPdf(Request $request)
    {
        $from = $request->get('from', now()->startOfMonth()->format('Y-m-d'));
        $to   = $request->get('to', now()->format('Y-m-d'));
        $type = $request->get('type', 'sales');
        $data = $this->getReportData($from, $to);
        $pdf  = Pdf::loadView('admin.pdf.report', compact('data', 'from', 'to', 'type'))
                   ->setPaper('a4', 'portrait');
        return $pdf->download("picksell-{$type}-report-{$from}-to-{$to}.pdf");
    }

    private function getReportData($from, $to): array
    {
        $orders = Order::where('status', 'completed')
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->with('seller')->get();

        $topSellers = Order::where('status', 'completed')
            ->whereBetween('created_at', [$from, $to . ' 23:59:59'])
            ->with('seller')
            ->get()
            ->groupBy('seller_id')
            ->map(fn($g) => [
                'name'       => $g->first()->seller->full_name ?? '—',
                'sales'      => $g->sum('amount'),
                'orders'     => $g->count(),
                'commission' => $g->sum('commission'),
            ])->sortByDesc('sales')->take(5)->values()->toArray();

        // Weekly breakdown for current period
        $weeklySales = [];
        $weekLabels  = [];
        $start = \Carbon\Carbon::parse($from);
        $end   = \Carbon\Carbon::parse($to);
        $week  = 1;
        while ($start->lte($end)) {
            $weekEnd = $start->copy()->addDays(6)->min($end);
            $weeklySales[] = Order::where('status', 'completed')
                ->whereBetween('created_at', [$start->format('Y-m-d'), $weekEnd->format('Y-m-d') . ' 23:59:59'])
                ->sum('amount');
            $weekLabels[] = 'Week ' . $week++;
            $start->addDays(7);
        }

        return [
            'total_sales'      => $orders->sum('amount'),
            'total_orders'     => $orders->count(),
            'total_commission' => $orders->sum('commission'),
            'new_buyers'       => User::where('role', 'buyer')->whereBetween('created_at', [$from, $to . ' 23:59:59'])->count(),
            'new_sellers'      => User::where('role', 'seller')->whereBetween('created_at', [$from, $to . ' 23:59:59'])->count(),
            'monthly_sales'    => $weeklySales ?: [0],
            'months'           => $weekLabels ?: ['No Data'],
            'top_sellers'      => $topSellers,
        ];
    }

    // Sorting Center / Logistics
    public function logistics(Request $request)
    {
        $status = $request->get('status', 'all');
        $query = Order::with(['buyer', 'seller', 'courier'])
            ->whereIn('status', ['shipped', 'completed']);
        if ($status !== 'all') {
            $query->where('status', $status);
        }

        $orders = $query->latest()->paginate(15);
        $couriers = User::where('role', 'courier')
            ->where('status', 'approved')
            ->orderBy('delivery_area')
            ->orderBy('last_name')
            ->get();

        return view('admin.logistics', compact('orders', 'couriers', 'status'));
    }

    public function assignCourier(Request $request, Order $order)
    {
        $data = $request->validate([
            'courier_id' => 'required|exists:users,id',
        ]);

        $courier = User::where('id', $data['courier_id'])
            ->where('role', 'courier')
            ->where('status', 'approved')
            ->firstOrFail();

        OrderStatus::ensure($order, 'assign');

        $order->update([
            'courier_id' => $courier->id,
            'tracking_status' => 'Sorted for ' . $order->delivery['area'] . '; assigned to ' . $courier->full_name,
        ]);

        return back()->with('success', "Parcel {$order->order_number} assigned to {$courier->full_name}.");
    }

    public function returnToSender(Request $request, Order $order, \App\Services\Deliveries $deliveries)
    {
        $data = $request->validate(['reason' => 'required|string|max:300']);
        $deliveries->returnToSender($order, $request->user(), $data['reason']);
        return back()->with('success', "Parcel {$order->order_number} is being returned to the seller.");
    }

    public function scanParcel(Order $order)
    {
        OrderStatus::ensure($order, 'scan');

        $order->update([
            'tracking_status' => 'Received and scanned at sorting center',
        ]);

        return back()->with('success', "Parcel {$order->order_number} received and scanned.");
    }

    // Settings
    public function settings()
    {
        $announcements = Announcement::latest()->get();
        $tos     = PlatformSetting::get('terms_of_service');
        $privacy = PlatformSetting::get('privacy_policy');
        return view('admin.settings', compact('announcements', 'tos', 'privacy'));
    }

    public function saveSettings(Request $request)
    {
        if ($request->has('announcement_title')) {
            $request->validate([
                'announcement_title' => 'required|string|max:255',
                'announcement'       => 'required|string|max:1000',
                'audience'           => 'required|in:all,buyer,seller,courier',
            ]);
            Announcement::create([
                'title'    => $request->announcement_title,
                'message'  => $request->announcement,
                'audience' => $request->audience,
                'active'   => true,
            ]);
            return back()->with('success', 'Announcement posted successfully.');
        }

        // Save policies
        $request->validate([
            'policy'  => 'nullable|string',
            'privacy' => 'nullable|string',
        ]);
        PlatformSetting::set('terms_of_service', $request->policy ?? '');
        PlatformSetting::set('privacy_policy', $request->privacy ?? '');
        return back()->with('success', 'Policies saved successfully.');
    }

    public function toggleAnnouncement(Announcement $announcement)
    {
        $announcement->update(['active' => !$announcement->active]);
        return back()->with('success', 'Announcement updated.');
    }

    public function deleteAnnouncement(Announcement $announcement)
    {
        $announcement->delete();
        return back()->with('success', 'Announcement deleted.');
    }

    // Chat
    public function chat(Request $request)
    {
        $admin = auth()->user();

        // Support mode: only show users who have messaged the admin
        $userIds = Message::where('receiver_id', $admin->id)
            ->pluck('sender_id')->unique()->values();

        $users = User::whereIn('id', $userIds)
            ->whereIn('role', ['buyer', 'seller', 'courier'])
            ->where('status', 'approved')->get();

        $activeUserId = $request->get('user');
        $activeUser   = $activeUserId ? User::find($activeUserId) : null;
        $messages     = [];

        if ($activeUser) {
            Message::where('sender_id', $activeUserId)
                ->where('receiver_id', $admin->id)
                ->update(['read' => true]);

            $messages = Message::where(function ($q) use ($admin, $activeUserId) {
                $q->where('sender_id', $admin->id)->where('receiver_id', $activeUserId);
            })->orWhere(function ($q) use ($admin, $activeUserId) {
                $q->where('sender_id', $activeUserId)->where('receiver_id', $admin->id);
            })->orderBy('created_at')->get();
        }

        $users = $users->map(function ($u) use ($admin) {
            $u->unread = Message::where('sender_id', $u->id)
                ->where('receiver_id', $admin->id)
                ->where('read', false)->count();
            return $u;
        });

        return view('admin.chat', compact('users', 'activeUser', 'messages'));
    }

    public function sendMessage(Request $request)
    {
        $request->validate([
            'receiver_id' => 'required|exists:users,id',
            'body'        => 'required|string|max:2000',
        ]);
        Message::create([
            'sender_id'   => auth()->id(),
            'receiver_id' => $request->receiver_id,
            'body'        => $request->body,
            'read'        => false,
        ]);
        return back();
    }

    // Notifications
    public function notifications()
    {
        $notifications = auth()->user()->notifications()->latest()->take(20)->get();
        auth()->user()->unreadNotifications->markAsRead();
        return response()->json($notifications);
    }

    // Account Management
    public function account()
    {
        return view('admin.account');
    }

    public function updateAccount(Request $request)
    {
        $request->validate([
            'first_name' => 'required|string|max:100',
            'last_name'  => 'required|string|max:100',
            'email'      => 'required|email|unique:users,email,' . auth()->id(),
            'contact_no' => 'required|string|max:20',
        ]);
        auth()->user()->update($request->only('first_name', 'last_name', 'email', 'contact_no'));
        return back()->with('success', 'Account updated successfully.');
    }

    public function updatePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required',
            'password'         => 'required|min:8|confirmed',
        ]);
        if (!\Hash::check($request->current_password, auth()->user()->password)) {
            return back()->withErrors(['current_password' => 'Current password is incorrect.']);
        }
        auth()->user()->update(['password' => \Hash::make($request->password)]);
        return back()->with('success', 'Password changed successfully.');
    }

    // Helper: store a simple DB notification for admin
    private function notifyAdmin(string $message): void
    {
        $admin = auth()->user();
        $admin->notifications()->create([
            'id'   => \Illuminate\Support\Str::uuid(),
            'type' => 'App\Notifications\AdminActivity',
            'data' => json_encode(['message' => $message]),
        ]);
    }
}
