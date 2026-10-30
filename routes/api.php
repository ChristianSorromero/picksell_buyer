<?php

use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\MobileAuthController;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
| Picksell buyer mobile API. It reads and writes the Picksell website's database, so every rule
| here mirrors the website's buyer pages. Each throttle has its own prefix so limits don't share
| a counter.
*/

// Sign-up (website flow: email code → details with ID → pending admin approval), login, reset.
Route::post('/register/email-code', [MobileAuthController::class, 'sendRegistrationCode'])->middleware('throttle:6,1,register-code');
Route::post('/register/email-code/verify', [MobileAuthController::class, 'verifyRegistrationCode'])->middleware('throttle:20,1,register-verify');
Route::post('/register/check-contact', [MobileAuthController::class, 'checkContact'])->middleware('throttle:20,1,check-contact');
Route::post('/register', [MobileAuthController::class, 'register'])->middleware('throttle:10,1,register');
Route::post('/login', [MobileAuthController::class, 'login'])->middleware('throttle:10,1,login');
Route::post('/password/forgot', [MobileAuthController::class, 'forgotPassword'])->middleware('throttle:5,1,password-forgot');
Route::post('/password/reset', [MobileAuthController::class, 'resetPassword'])->middleware('throttle:10,1,password-reset');

// Public catalog (a bearer token is optional: it adds `wishlisted` and records recently viewed).
Route::middleware('throttle:120,1,catalog')->group(function () {
    Route::get('/home', [CatalogController::class, 'home']);
    Route::get('/categories', [CatalogController::class, 'categories']);
    Route::get('/products', [CatalogController::class, 'index']);
    Route::get('/products/{product}', [CatalogController::class, 'show']);
    Route::get('/products/{product}/reviews', [CatalogController::class, 'reviews']);
    Route::get('/sellers/{seller}', [CatalogController::class, 'seller']);
    Route::get('/payment-methods', [CheckoutController::class, 'paymentMethods']);
    Route::get('/legal/{document}', [NotificationController::class, 'legal'])->whereIn('document', ['terms', 'privacy']);
});

Route::middleware(['auth:sanctum', 'active.buyer', 'throttle:120,1,buyer-api'])->group(function () {
    Route::prefix('buyer')->group(function () {
        Route::get('/profile', [ProfileController::class, 'show']);
        Route::patch('/profile', [ProfileController::class, 'update']);
        Route::patch('/password', [ProfileController::class, 'password']);
        Route::post('/logout', [ProfileController::class, 'logout']);

        Route::get('/wishlist', [WishlistController::class, 'index']);
        Route::post('/wishlist/{product}', [WishlistController::class, 'store']);
        Route::delete('/wishlist/{product}', [WishlistController::class, 'destroy']);
        Route::get('/recently-viewed', [WishlistController::class, 'recentlyViewed']);
        Route::delete('/recently-viewed', [WishlistController::class, 'clearRecentlyViewed']);

        Route::get('/cart', [CartController::class, 'index']);
        Route::get('/cart/count', [CartController::class, 'summary']);
        Route::post('/cart', [CartController::class, 'store']);
        Route::patch('/cart/{item}', [CartController::class, 'update']);
        Route::delete('/cart/{item}', [CartController::class, 'destroy']);
        Route::delete('/cart', [CartController::class, 'destroyMany']);

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
        Route::get('/support/tickets', [OrderController::class, 'tickets']);

        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    });

    Route::get('/chat/contacts', [ChatController::class, 'contacts']);
    Route::get('/chat/messages/{userId}', [ChatController::class, 'messages'])->whereNumber('userId');
    Route::post('/chat/send', [ChatController::class, 'send'])->middleware('throttle:30,1,chat-send');
});

Route::get('/ping', fn () => response()->json(['ok' => true]));

Route::middleware('throttle:60,1,suggestions')->get('/search-suggestions', function (Request $request) {
    $query = trim((string) $request->get('q', ''));
    if (mb_strlen($query) < 2) return response()->json(['products' => [], 'categories' => []]);

    $products = Product::without('images')->purchasable()->where('stock', '>', 0)
        ->where(fn ($builder) => $builder->where('name', 'like', "%{$query}%")->orWhere('category', 'like', "%{$query}%"))
        ->latest()->take(6)->get(['name', 'category']);

    $categories = Product::without('images')->purchasable()->where('stock', '>', 0)
        ->where('category', 'like', "%{$query}%")->whereNotNull('category')
        ->distinct()->orderBy('category')->limit(3)->pluck('category');

    return response()->json(['products' => $products, 'categories' => $categories]);
});
