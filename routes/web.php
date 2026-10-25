<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\SellerController;
use App\Http\Controllers\BuyerController;
use App\Http\Controllers\CourierController;
use App\Http\Controllers\LogisticsController;
use App\Http\Middleware\AdminMiddleware;
use App\Http\Middleware\CourierMiddleware;
use App\Http\Middleware\LogisticsMiddleware;
use App\Http\Middleware\SellerMiddleware;
use App\Http\Middleware\BuyerMiddleware;
use App\Models\Product;
use Illuminate\Http\Request;

Route::get('/', function () {
    $featuredProducts = Product::where('status', 'active')->where('stock', '>', 0)
        ->where('is_featured', true)->with('seller')->latest()->take(8)->get();
    return view('welcome', compact('featuredProducts'));
});
Route::get('/shop', function (Request $request) {
    $query = Product::where('status', 'active')->where('stock', '>', 0)->whereNotNull('image')->with('seller');
    $search = trim((string) $request->get('q', ''));
    if ($search) {
        $query->where(function ($builder) use ($search) {
            $builder->where('name', 'like', "%{$search}%")
                ->orWhere('category', 'like', "%{$search}%");
        });
    }
    $category = strtolower(trim((string) $request->get('cat', '')));
    $category = $category === 'home' ? 'home & living' : $category;
    if ($category) $query->whereRaw('LOWER(category) = ?', [$category]);
    if ($request->filled('min')) $query->where('price', '>=', $request->float('min'));
    if ($request->filled('max')) $query->where('price', '<=', $request->float('max'));
    $products = $query->latest()->get();
    return view('pages.shop', compact('products'));
})->name('shop');
Route::get('/about', fn() => view('pages.about'))->name('about');
Route::get('/contact', fn() => view('pages.contact'))->name('contact');
Route::post('/contact', fn() => back()->with('success', 'Message sent!'))->name('contact.send');

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login']);
    Route::get('/register', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register']);
    Route::get('/forgot-password', [AuthController::class, 'showForgotPassword'])->name('password.request');
    Route::post('/forgot-password', [AuthController::class, 'sendResetLink'])->name('password.email');
    Route::get('/reset-password/{token}', [AuthController::class, 'showResetPassword'])->name('password.reset');
    Route::post('/reset-password', [AuthController::class, 'resetPassword'])->name('password.update');
});

Route::middleware('auth')->group(function () {
    // Private identity documents & dispute evidence (authorized per file).
    Route::get('/documents/users/{user}/{type}', [\App\Http\Controllers\DocumentController::class, 'userDocument'])
        ->whereIn('type', ['id', 'permit', 'orcr'])->name('documents.user');
    Route::get('/documents/complaints/{complaint}/{index?}', [\App\Http\Controllers\DocumentController::class, 'complaintEvidence'])
        ->whereNumber('index')->name('documents.complaint');

    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
    Route::delete('/account', [AuthController::class, 'deleteAccount'])->name('account.delete');
    Route::get('/buyer/dashboard',   fn() => view('dashboard'))->name('buyer.dashboard');
    Route::get('/courier/dashboard', fn() => redirect('/courier/orders'))->name('courier.dashboard');
    Route::get('/dashboard', fn() => redirect(match(auth()->user()->role) {
        'seller'  => '/seller/dashboard',
        'courier' => '/courier/dashboard',
        'admin'   => '/admin/dashboard',
        'logistics' => '/logistics/dashboard',
        default   => '/buyer/dashboard',
    }));
});

// Logistics / Sorting Center Staff Routes
Route::middleware(['auth', LogisticsMiddleware::class])->prefix('logistics')->group(function () {
    Route::get('/dashboard', [LogisticsController::class, 'dashboard'])->name('logistics.dashboard');
    Route::get('/applications', [LogisticsController::class, 'applications'])->name('logistics.applications');
    Route::patch('/applications/{user}/approve', [LogisticsController::class, 'approveCourier'])->name('logistics.applications.approve');
    Route::patch('/applications/{user}/disapprove', [LogisticsController::class, 'disapproveCourier'])->name('logistics.applications.disapprove');
    Route::get('/parcels', [LogisticsController::class, 'parcels'])->name('logistics.parcels');
    Route::patch('/parcels/{order}/scan', [LogisticsController::class, 'scanParcel'])->name('logistics.parcels.scan');
    Route::patch('/parcels/{order}/assign', [LogisticsController::class, 'assignCourier'])->name('logistics.parcels.assign');
});

// Courier / Rider Routes
Route::middleware(['auth', CourierMiddleware::class])->prefix('courier')->group(function () {
    Route::get('/orders', [CourierController::class, 'dashboard'])->name('courier.orders');
    Route::patch('/orders/{order}/status', [CourierController::class, 'updateStatus'])->name('courier.orders.status');
    Route::get('/reports', [CourierController::class, 'reports'])->name('courier.reports');
    Route::get('/chat', [CourierController::class, 'chat'])->name('courier.chat');
    Route::post('/chat/send', [CourierController::class, 'sendMessage'])->name('courier.chat.send');
    Route::get('/account', [CourierController::class, 'account'])->name('courier.account');
    Route::patch('/account', [CourierController::class, 'updateAccount'])->name('courier.account.update');
    Route::patch('/account/password', [CourierController::class, 'updatePassword'])->name('courier.account.password');
});

// Buyer Routes
Route::middleware(['auth', BuyerMiddleware::class])->prefix('buyer')->group(function () {
    Route::get('/dashboard',                        [BuyerController::class, 'home'])->name('buyer.dashboard');
    Route::get('/shop',                             [BuyerController::class, 'home'])->name('buyer.home');
    Route::get('/product/{product}',                [BuyerController::class, 'productDetail'])->name('buyer.product');

    // Cart
    Route::get('/cart',                             [BuyerController::class, 'cart'])->name('buyer.cart');
    Route::post('/cart/checkout',                   [BuyerController::class, 'placeOrder'])->name('buyer.checkout');
    Route::post('/cart/{product}',                  [BuyerController::class, 'addToCart'])->name('buyer.cart.add');
    Route::patch('/cart/item/{item}',               [BuyerController::class, 'updateCart'])->name('buyer.cart.update');
    Route::delete('/cart/item/{item}',              [BuyerController::class, 'removeFromCart'])->name('buyer.cart.remove');

    // Orders
    Route::get('/orders',                           [BuyerController::class, 'orders'])->name('buyer.orders');
    Route::post('/orders/{order}/feedback',         [BuyerController::class, 'submitFeedback'])->name('buyer.feedback');

    // Chat
    Route::get('/chat',                             [BuyerController::class, 'chat'])->name('buyer.chat');
    Route::post('/chat/send',                       [BuyerController::class, 'sendMessage'])->name('buyer.chat.send');

    // Account
    Route::get('/account',                          [BuyerController::class, 'account'])->name('buyer.account');
    Route::patch('/account',                        [BuyerController::class, 'updateAccount'])->name('buyer.account.update');
    Route::patch('/account/password',               [BuyerController::class, 'updatePassword'])->name('buyer.account.password');
});

// Seller Routes
Route::middleware(['auth', SellerMiddleware::class])->prefix('seller')->group(function () {
    Route::get('/dashboard', [SellerController::class, 'dashboard'])->name('seller.dashboard');

    // Inventory
    Route::get('/inventory',                        [SellerController::class, 'inventory'])->name('seller.inventory');
    Route::post('/inventory',                       [SellerController::class, 'storeProduct'])->name('seller.inventory.store');
    Route::patch('/inventory/{product}',            [SellerController::class, 'updateProduct'])->name('seller.inventory.update');
    Route::patch('/inventory/{product}/archive',    [SellerController::class, 'archiveProduct'])->name('seller.inventory.archive');

    // Orders
    Route::get('/orders',                           [SellerController::class, 'orders'])->name('seller.orders');
    Route::get('/orders/{order}',                   [SellerController::class, 'showOrder'])->name('seller.orders.show');
    Route::patch('/orders/{order}/pack',            [SellerController::class, 'packOrder'])->name('seller.orders.pack');
    Route::patch('/orders/{order}/handover',        [SellerController::class, 'handoverOrder'])->name('seller.orders.handover');

    // Reports
    Route::get('/reports', [SellerController::class, 'reports'])->name('seller.reports');

    // Chat
    Route::get('/chat',       [SellerController::class, 'chat'])->name('seller.chat');
    Route::post('/chat/send', [SellerController::class, 'sendMessage'])->name('seller.chat.send');

    // Account
    Route::get('/account',            [SellerController::class, 'account'])->name('seller.account');
    Route::patch('/account',          [SellerController::class, 'updateAccount'])->name('seller.account.update');
    Route::patch('/account/password', [SellerController::class, 'updatePassword'])->name('seller.account.password');
});

// Admin Routes
Route::middleware(['auth', AdminMiddleware::class])->prefix('admin')->group(function () {
    Route::get('/dashboard', [AdminController::class, 'dashboard'])->name('admin.dashboard');
    Route::get('/products', [AdminController::class, 'products'])->name('admin.products');
    Route::patch('/products/{product}/featured', [AdminController::class, 'toggleFeatured'])->name('admin.products.featured');

    // Registrations
    Route::get('/registrations',                     [AdminController::class, 'registrations'])->name('admin.registrations');
    Route::get('/registrations/{user}',              [AdminController::class, 'showApplication'])->name('admin.registrations.show');
    Route::patch('/registrations/{user}/approve',    [AdminController::class, 'approveUser'])->name('admin.registrations.approve');
    Route::patch('/registrations/{user}/disapprove', [AdminController::class, 'disapproveUser'])->name('admin.registrations.disapprove');

    // Users
    Route::get('/users',                  [AdminController::class, 'users'])->name('admin.users');
    Route::patch('/users/{user}/status',  [AdminController::class, 'updateUserStatus'])->name('admin.users.status');

    // Compliance
    Route::get('/compliance',               [AdminController::class, 'compliance'])->name('admin.compliance');
    Route::patch('/compliance/{user}/warn', [AdminController::class, 'warnSeller'])->name('admin.compliance.warn');

    // Complaints
    Route::get('/complaints',                        [AdminController::class, 'complaints'])->name('admin.complaints');
    Route::get('/complaints/{complaint}',            [AdminController::class, 'showComplaint'])->name('admin.complaints.show');
    Route::patch('/complaints/{complaint}',          [AdminController::class, 'updateComplaint'])->name('admin.complaints.update');

    // Commission
    Route::get('/commission', [AdminController::class, 'commission'])->name('admin.commission');

    // Reports
    Route::get('/reports',        [AdminController::class, 'reports'])->name('admin.reports');
    Route::get('/reports/export', [AdminController::class, 'exportPdf'])->name('admin.reports.export');

    // Sorting Center / Logistics
    Route::get('/logistics', [AdminController::class, 'logistics'])->name('admin.logistics');
    Route::patch('/logistics/orders/{order}/scan', [AdminController::class, 'scanParcel'])->name('admin.logistics.scan');
    Route::patch('/logistics/orders/{order}/assign', [AdminController::class, 'assignCourier'])->name('admin.logistics.assign');

    // Settings
    Route::get('/settings',  [AdminController::class, 'settings'])->name('admin.settings.index');
    Route::post('/settings', [AdminController::class, 'saveSettings'])->name('admin.settings.save');
    Route::patch('/settings/announcements/{announcement}/toggle', [AdminController::class, 'toggleAnnouncement'])->name('admin.announcements.toggle');
    Route::delete('/settings/announcements/{announcement}', [AdminController::class, 'deleteAnnouncement'])->name('admin.announcements.delete');

    // Chat
    Route::get('/chat',         [AdminController::class, 'chat'])->name('admin.chat');
    Route::post('/chat/send',   [AdminController::class, 'sendMessage'])->name('admin.chat.send');

    // Notifications (JSON)
    Route::get('/notifications', [AdminController::class, 'notifications'])->name('admin.notifications');

    // Account
    Route::get('/account',             [AdminController::class, 'account'])->name('admin.account');
    Route::patch('/account',           [AdminController::class, 'updateAccount'])->name('admin.account.update');
    Route::patch('/account/password',  [AdminController::class, 'updatePassword'])->name('admin.account.password');
});
