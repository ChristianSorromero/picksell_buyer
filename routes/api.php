<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\BuyerController;
use App\Http\Controllers\MobileAuthController;
use App\Models\Product;

// Mobile auth routes
Route::post('/register', [MobileAuthController::class, 'register']);
Route::post('/login',    [MobileAuthController::class, 'login']);
Route::post('/upload-id', [MobileAuthController::class, 'uploadId']);
Route::get('/products',  [MobileAuthController::class, 'products']);

Route::middleware('auth:sanctum')->group(function () {
    Route::patch('/buyer/account', [BuyerController::class, 'updateAccount']);

    // Chat
    Route::get('/chat/contacts', function (Request $request) {
        $buyer = $request->user();
        $chattedUserIds = \App\Models\Message::where(function ($q) use ($buyer) {
            $q->where('sender_id', $buyer->id)->orWhere('receiver_id', $buyer->id);
        })->get()->map(fn ($m) => $m->sender_id === $buyer->id ? $m->receiver_id : $m->sender_id)
            ->unique()->values();

        $orderedSellerIds = \App\Models\Order::where('buyer_id', $buyer->id)->pluck('seller_id');
        $contactIds = $chattedUserIds->merge($orderedSellerIds)->unique()->values();

        $contacts = \App\Models\User::whereIn('id', $contactIds)
            ->where('role', 'seller')->where('status', 'approved')->get()
            ->map(function ($u) use ($buyer) {
                $last = \App\Models\Message::where(function ($q) use ($buyer, $u) {
                    $q->where('sender_id', $buyer->id)->where('receiver_id', $u->id);
                })->orWhere(function ($q) use ($buyer, $u) {
                    $q->where('sender_id', $u->id)->where('receiver_id', $buyer->id);
                })->latest()->first();
                $unread = \App\Models\Message::where('sender_id', $u->id)
                    ->where('receiver_id', $buyer->id)->where('read', false)->count();
                return [
                    'id'           => $u->id,
                    'name'         => $u->business_name ?: trim(($u->first_name ?? '').' '.($u->last_name ?? '')),
                    'initials'     => strtoupper(substr($u->first_name ?? '?', 0, 1).substr($u->last_name ?? '', 0, 1)),
                    'last_message' => $last?->body ?? '',
                    'last_time'    => $last?->created_at?->toIso8601String(),
                    'unread'       => $unread,
                ];
            });

        return response()->json(['contacts' => $contacts]);
    });

    Route::get('/chat/messages/{userId}', function (Request $request, $userId) {
        $buyer = $request->user();
        \App\Models\Message::where('sender_id', $userId)
            ->where('receiver_id', $buyer->id)->update(['read' => true]);

        $messages = \App\Models\Message::where(function ($q) use ($buyer, $userId) {
            $q->where('sender_id', $buyer->id)->where('receiver_id', $userId);
        })->orWhere(function ($q) use ($buyer, $userId) {
            $q->where('sender_id', $userId)->where('receiver_id', $buyer->id);
        })->orderBy('created_at')->get()->map(fn ($m) => [
            'id'         => $m->id,
            'body'       => $m->body,
            'sender_id'  => $m->sender_id,
            'created_at' => $m->created_at->toIso8601String(),
            'is_mine'    => $m->sender_id === $buyer->id,
        ]);

        return response()->json(['messages' => $messages]);
    });

    Route::post('/chat/send', function (Request $request) {
        $data = $request->validate([
            'receiver_id' => 'required|exists:users,id',
            'body'        => 'required|string|max:2000',
        ]);
        $buyer    = $request->user();
        $receiver = \App\Models\User::whereKey($data['receiver_id'])
            ->where('role', 'seller')->where('status', 'approved')->firstOrFail();

        $msg = \App\Models\Message::create([
            'sender_id'   => $buyer->id,
            'receiver_id' => $receiver->id,
            'body'        => $data['body'],
            'read'        => false,
        ]);

        return response()->json([
            'id'         => $msg->id,
            'body'       => $msg->body,
            'sender_id'  => $msg->sender_id,
            'created_at' => $msg->created_at->toIso8601String(),
            'is_mine'    => true,
        ], 201);
    });
});

Route::get('/ping', function (Request $request) {
    return response()->json(['ok' => true]);
});

Route::get('/search-suggestions', function (Request $request) {
    $query = trim((string) $request->get('q', ''));
    if (mb_strlen($query) < 2) return response()->json(['products' => [], 'categories' => []]);

    $products = Product::query()
        ->where('status', 'active')
        ->where('stock', '>', 0)
        ->where(function ($builder) use ($query) {
            $builder->where('name', 'like', "%{$query}%")
                ->orWhere('category', 'like', "%{$query}%");
        })
        ->latest()
        ->take(6)
        ->get(['name', 'category']);

    $categories = Product::query()
        ->where('status', 'active')
        ->where('stock', '>', 0)
        ->where('category', 'like', "%{$query}%")
        ->whereNotNull('category')
        ->distinct()
        ->orderBy('category')
        ->limit(3)
        ->pluck('category');

    return response()->json(['products' => $products, 'categories' => $categories]);
});
