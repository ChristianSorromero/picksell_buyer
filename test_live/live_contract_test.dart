// Live check: the app's own services against a running PickSell website.
//
// Not part of `flutter test` (it lives outside test/). Run it against a
// website on a disposable database, never the live one:
//
//   flutter test test_live --dart-define=API_BASE_URL=http://127.0.0.1:8090/api/mobile \
//     --dart-define=LIVE_EMAIL=buyer@live.test --dart-define=LIVE_PASSWORD=Password1!
//
// The account needs an approved buyer profile with a complete address, and
// the catalog needs at least one active product with stock. The run places
// and then cancels one order.
// ignore_for_file: invalid_use_of_visible_for_testing_member (a test, outside test/ so CI skips it)
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/status/order_status.dart';
import 'package:picksell/services/account_service.dart';
import 'package:picksell/services/auth_service.dart';
import 'package:picksell/services/cart_service.dart';
import 'package:picksell/services/catalog_service.dart';
import 'package:picksell/services/chat_service.dart';
import 'package:picksell/services/checkout_service.dart';
import 'package:picksell/services/order_service.dart';
import 'package:picksell/services/recently_viewed_service.dart';
import 'package:picksell/services/wishlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = String.fromEnvironment('LIVE_EMAIL');
const _password = String.fromEnvironment('LIVE_PASSWORD');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = null; // flutter_test blocks real HTTP by default
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  final skip = _email.isEmpty || const String.fromEnvironment('API_BASE_URL').isEmpty
      ? 'Set API_BASE_URL, LIVE_EMAIL and LIVE_PASSWORD to run against a live website.'
      : null;

  test('buyer journey through the website API', () async {
    final auth = AuthService();
    final catalog = CatalogService();
    final account = AccountService();
    final cart = CartStore();
    final checkout = CheckoutService();
    final orders = OrderService();

    // Public: legal text, home, categories, listing, product, reviews, seller, search.
    expect((await auth.legal('terms')).success, isTrue, reason: 'GET /legal/terms');
    final home = await catalog.home();
    expect(await catalog.categories(), isA<List>());
    final page = await catalog.products();
    expect(page.products, isNotEmpty, reason: 'the catalog needs an active product');
    final product = page.products.first;
    final detail = await catalog.product(product.id);
    expect(detail, isNotNull);
    await catalog.reviews(product.id);
    await catalog.suggestions(product.name.split(' ').first);
    printOnFailure('home sections: featured=${home.featured.length} recommended=${home.recommended.length}');

    // Sign in exactly as the login screen does.
    final login = await auth.login(email: _email, password: _password);
    expect(login.success, isTrue, reason: 'POST /login: ${login.message}');
    final user = login.data!['user'] as Map<String, dynamic>;
    await SessionManager().save(
      token: login.data!['token'] as String,
      userId: user['id'] as int,
      name: user['name'] as String,
      email: user['email'] as String,
    );

    // Profile and delivery address (the website books parcels to it).
    final overview = await account.overview();
    expect(overview.profile.email, _email);
    expect(overview.deliveryAddress?.complete, isTrue, reason: 'checkout needs a complete profile address');
    final p = overview.profile;
    final saved = await account.updateProfile(
      firstName: p.firstName,
      lastName: p.lastName,
      birthday: p.birthday!.toIso8601String().substring(0, 10),
      contactNo: p.contactNo,
      province: p.province,
      municipality: p.municipality,
      barangay: p.barangay,
      street: p.street,
      houseNo: p.houseNo,
      sex: p.sex,
      middleInitial: p.middleInitial,
    );
    expect(saved.email, _email);
    await account.notifications();
    await account.markAllRead();

    // Wishlist and recently viewed.
    final wishlist = WishlistStore();
    await wishlist.load();
    final wasSaved = wishlist.contains(product.id);
    await wishlist.toggle(product.id);
    expect(wishlist.contains(product.id), !wasSaved);
    await wishlist.toggle(product.id);
    await RecentlyViewedService().list();

    // Cart: add, change quantity, price it.
    final lineId = await cart.add(product, quantity: 1);
    expect(lineId, greaterThan(0));
    var quote = await cart.load();
    final line = quote.lines.firstWhere((l) => l.id == lineId);
    quote = await cart.setQuantity(line, 2);
    expect(quote.lines.firstWhere((l) => l.id == lineId).quantity, 2);
    await cart.refreshCount();
    expect(cart.count, greaterThan(0));

    // Checkout: the server's quote, then place (cash on delivery).
    final priced = await checkout.quote(lineIds: [lineId]);
    expect(priced.deliveryAddress.complete, isTrue);
    final placed = await checkout.place(lineIds: [lineId]);
    expect(placed.orders, isNotEmpty, reason: 'POST /buyer/checkout');
    final orderId = placed.orders.first.id;

    // Orders: list, detail, options, cancel.
    final list = await orders.list();
    expect(list.orders.map((o) => o.id), contains(orderId));
    final shown = await orders.detail(orderId);
    expect(shown.actions.canCancel, isTrue);
    final options = await orders.options();
    expect(options.cancelReasons, isNotEmpty);
    final cancelled = await orders.cancel(orderId, options.cancelReasons.first);
    expect(cancelled.status, OrderStatus.cancelled);
    await orders.reorderCandidates();
    await orders.tickets();

    // Chat with the product's seller.
    final chat = ChatService();
    final sellerId = detail.seller?.id ?? product.seller?.id;
    if (sellerId != null) {
      await catalog.seller(sellerId);
      await chat.sendMessage(sellerId, 'Live check: is this available?');
      expect(await chat.getMessages(sellerId), isNotEmpty);
      expect(await chat.getContacts(), isNotEmpty);
    }

    await auth.logout();
    expect(await SessionManager().isLoggedIn(), isFalse);
    expect(() => account.overview(), throwsA(isA<ApiException>()), reason: 'the token is revoked');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
