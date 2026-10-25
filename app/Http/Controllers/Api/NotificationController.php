<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\OrderEvent;
use App\Models\PlatformSetting;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;

/** BUY-A12 / LOG-C11 — order tracking events become buyer notifications. */
class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $seen = $user->notifications_seen_at;

        $events = OrderEvent::whereHas('order', fn ($q) => $q->where('buyer_id', $user->id))
            ->with('order.product')->latest('occurred_at')->latest('id')->take(50)->get();

        return response()->json([
            'notifications' => $events->map(fn ($e) => [
                'id'           => (string) $e->id,
                'type'         => 'order',
                'status'       => $e->status,
                'title'        => $e->title,
                'body'         => "{$e->order->product_name} · {$e->order->order_number}",
                'order_id'     => $e->order_id,
                'image'        => BuyerPresenter::image($e->order->product?->image),
                'occurred_at'  => BuyerPresenter::date($e->occurred_at),
                'unread'       => !$seen || $e->occurred_at->gt($seen),
            ])->values(),
            'unread_count' => $events->filter(fn ($e) => !$seen || $e->occurred_at->gt($seen))->count(),
        ]);
    }

    public function markAllRead(Request $request)
    {
        $request->user()->forceFill(['notifications_seen_at' => now()])->save();
        return response()->json(['message' => 'All caught up.', 'unread_count' => 0]);
    }

    /** GET /legal/{terms|privacy} — text managed in the admin panel. */
    public function legal(string $document)
    {
        $key = ['terms' => 'terms_of_service', 'privacy' => 'privacy_policy'][$document] ?? abort(404);
        $title = $document === 'terms' ? 'Terms of Service' : 'Privacy Policy';

        return response()->json(['title' => $title, 'body' => PlatformSetting::get($key)]);
    }
}
