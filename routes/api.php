<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\ReturnController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\BuyerController;
use App\Http\Controllers\MobileAuthController;
use App\Models\Product;

// Mobile auth routes
Route::post('/register', [MobileAuthController::class, 'register'])->middleware('throttle:10,1,register');
Route::post('/register/check-contact', [MobileAuthController::class, 'checkContact'])->middleware('throttle:20,1,check-contact');
Route::post('/register/verify', [MobileAuthController::class, 'verifyEmail'])->middleware('throttle:10,1,verify-email');
Route::post('/register/resend', [MobileAuthController::class, 'resendCode'])->middleware('throttle:5,1,resend-code');
// Brute-force protection: 10 attempts per minute per IP. Each throttle
// gets its own prefix so limits don't share one counter.
Route::post('/login', [MobileAuthController::class, 'login'])->middleware('throttle:10,1,login');
Route::post('/password/forgot', [MobileAuthController::class, 'forgotPassword'])->middleware('throttle:5,1,password-forgot');
Route::post('/password/reset', [MobileAuthController::class, 'resetPassword'])->middleware('throttle:10,1,password-reset');

// Public catalog (bearer token optional — adds `wishlisted`)
Route::get('/home', [CatalogController::class, 'home']);
Route::get('/categories', [CatalogController::class, 'categories']);
Route::get('/products', [CatalogController::class, 'index']);
Route::get('/products/{product}', [CatalogController::class, 'show']);
Route::get('/products/{product}/reviews', [CatalogController::class, 'reviews']);
Route::get('/sellers/{seller}', [CatalogController::class, 'seller']);
Route::get('/shipping-options', [CheckoutController::class, 'shippingOptions']);
Route::get('/payment-methods', [CheckoutController::class, 'paymentMethods']);
Route::get('/legal/{document}', [NotificationController::class, 'legal'])->whereIn('document', ['terms', 'privacy']);

Route::middleware(['auth:sanctum', 'active.buyer', 'throttle:120,1,buyer-api'])->group(function () {
    Route::patch('/buyer/account', [BuyerController::class, 'updateAccount']);

    // Mobile buyer API
    Route::prefix('buyer')->group(function () {
        Route::get('/profile', [ProfileController::class, 'show']);
        Route::patch('/profile', [ProfileController::class, 'update']);
        Route::patch('/password', [ProfileController::class, 'password']);
        Route::post('/logout', [ProfileController::class, 'logout']);

        Route::get('/addresses', [AddressController::class, 'index']);
        Route::post('/addresses', [AddressController::class, 'store']);
        Route::patch('/addresses/{address}', [AddressController::class, 'update']);
        Route::delete('/addresses/{address}', [AddressController::class, 'destroy']);

        Route::get('/wishlist', [WishlistController::class, 'index']);
        Route::post('/wishlist/{product}', [WishlistController::class, 'store']);
        Route::delete('/wishlist/{product}', [WishlistController::class, 'destroy']);

        Route::get('/cart', [CartController::class, 'index']);
        Route::get('/cart/count', [CartController::class, 'summary']);
        Route::post('/cart', [CartController::class, 'store']);
        Route::patch('/cart/{item}', [CartController::class, 'update']);
        Route::delete('/cart/{item}', [CartController::class, 'destroy']);
        Route::delete('/cart', [CartController::class, 'destroyMany']);

        Route::get('/vouchers', [CheckoutController::class, 'vouchers']);
        Route::post('/checkout/quote', [CheckoutController::class, 'quote']);
        Route::post('/checkout', [CheckoutController::class, 'place'])->middleware('throttle:10,1,checkout');

        Route::get('/orders', [OrderController::class, 'index']);
        Route::get('/orders/options', [OrderController::class, 'options']);
        Route::get('/orders/{order}', [OrderController::class, 'show']);
        Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel']);
        Route::post('/orders/{order}/rate', [OrderController::class, 'rate']);
        Route::post('/orders/{order}/report', [OrderController::class, 'report'])->middleware('throttle:10,1,report');
        Route::post('/orders/{order}/return', [OrderController::class, 'requestReturn'])->middleware('throttle:10,1,return');
        Route::post('/orders/{order}/reorder', [OrderController::class, 'reorder']);
        Route::get('/reorder', [OrderController::class, 'reorderCandidates']);
        Route::post('/returns/{returnRequest}/reply', [ReturnController::class, 'reply'])->middleware('throttle:10,1,return-reply');
        Route::post('/returns/{returnRequest}/accept', [ReturnController::class, 'accept']);
        Route::post('/returns/{returnRequest}/decline', [ReturnController::class, 'decline']);
        Route::get('/support/tickets', [OrderController::class, 'tickets']);

        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    });

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

Route::middleware('throttle:60,1,suggestions')->get('/search-suggestions', function (Request $request) {
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
