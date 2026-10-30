<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\PlatformSetting;
use App\Support\BuyerPresenter;
use App\Support\OrderStatus;
use Illuminate\Http\Request;

/**
 * The buyer's notifications: the same rows as the website's buyer bell (order updates from the
 * seller and Pickrush, new chat messages), so reading them on one side marks them read on both.
 */
class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $notifications = $user->notifications()->latest()->take(50)->get();
        $orders = Order::whereIn('id', $notifications->map(fn ($n) => $this->payload($n)['order_id'] ?? null)->filter())
            ->with('product')->get()->keyBy('id');

        return response()->json([
            'notifications' => $notifications->map(function ($n) use ($orders) {
                $data = $this->payload($n);
                $order = $orders->get($data['order_id'] ?? null);
                $status = $data['status'] ?? null;

                return [
                    'id'          => $n->id,
                    'type'        => $order ? 'order' : 'message',
                    'status'      => $status ? (OrderStatus::LEGACY[$status] ?? $status) : null,
                    'title'       => $status ? (OrderStatus::EVENTS[OrderStatus::LEGACY[$status] ?? $status][0] ?? 'Order update') : ($order ? 'Order update' : 'New message'),
                    'body'        => $data['message'] ?? 'New notification',
                    'order_id'    => $order?->id,
                    'image'       => BuyerPresenter::image($order?->product?->primary_image),
                    'occurred_at' => BuyerPresenter::date($n->created_at),
                    'unread'      => $n->read_at === null,
                ];
            })->values(),
            'unread_count' => $user->unreadNotifications()->count(),
        ]);
    }

    public function markAllRead(Request $request)
    {
        $request->user()->unreadNotifications()->update(['read_at' => now()]);

        return response()->json(['message' => 'All caught up.', 'unread_count' => 0]);
    }

    /** GET /legal/{terms|privacy} — text managed in the website's admin panel. */
    public function legal(string $document)
    {
        $key = ['terms' => 'terms_of_service', 'privacy' => 'privacy_policy'][$document] ?? abort(404);
        $title = $document === 'terms' ? 'Terms of Service' : 'Privacy Policy';

        return response()->json(['title' => $title, 'body' => PlatformSetting::get($key)]);
    }

    /** The website stores some notification data JSON-encoded twice; accept both. */
    private function payload($notification): array
    {
        $data = $notification->data;
        while (is_string($data)) {
            $decoded = json_decode($data, true);
            if ($decoded === null) break;
            $data = $decoded;
        }

        return is_array($data) ? $data : [];
    }
}
