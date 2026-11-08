import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:picksell/core/network/api_client.dart';
import 'package:picksell/services/cart_service.dart';
import 'package:picksell/services/wishlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the buyer API, enough for widget tests of sign-up,
/// cart → checkout → orders. Prices follow the website's checkout rules
/// (App\Services\CartQuote): no fees, a product voucher code is case-sensitive.
class FakeBuyerApi {
  FakeBuyerApi() {
    reset();
  }

  final List<http.Request> requests = [];
  late List<Map<String, dynamic>> cart;
  int nextLineId = 100;
  String? placeError; // 'stock' → 422 item_ids
  Map<String, dynamic>? orderDetail;

  /// The address book (website: BuyerAddressBook) and the default address's pin.
  late List<Map<String, dynamic>> addresses;
  int nextAddressId = 40;
  Map<String, dynamic>? defaultPin;

  /// Checkout vouchers: Island Threads' SAVE50 (₱50 off ₱500+) and PickSell's PICK20 (₱20 off).
  /// Set [usedUp] to make placing an order with SAVE50 fail, like a voucher used up since the quote.
  bool usedUp = false;

  /// Seller ids the buyer follows (website: seller_follows), and other buyers' follows of Island Threads.
  final Set<int> following = {};
  int otherFollowers = 4;

  /// Reviews of the tee: 31 by someone else (2 others found it helpful), 32 the buyer's own.
  bool votedHelpful = false;

  /// The raw multipart body of the last sign-up resubmission.
  String? resubmitted;
  Map<String, dynamic>? lastReport;

  static const shirt = {
    'id': 7,
    'name': 'Cotton Basic Tee',
    'category': 'Fashion',
    'price': 400.0,
    'original_price': 500.0,
    'discount_percent': 20,
    'stock': 5,
    'image': null,
    'images': [],
    'rating': 4.5,
    'review_count': 2,
    'sold_count': 10,
    'is_featured': false,
    'is_available': true,
    'wishlisted': false,
    'voucher_code': 'TEE10',
    'voucher_discount': 10.0,
    'seller': {'id': 3, 'name': 'Island Threads', 'location': 'Cebu City, Cebu', 'verified': true},
  };

  static const mug = {
    'id': 8,
    'name': 'Ceramic Mug',
    'category': 'Home',
    'price': 300.0,
    'original_price': null,
    'discount_percent': null,
    'stock': 10,
    'image': null,
    'images': [],
    'rating': null,
    'review_count': 0,
    'sold_count': 0,
    'is_featured': false,
    'is_available': true,
    'wishlisted': false,
    'seller': {'id': 3, 'name': 'Island Threads', 'location': 'Cebu City, Cebu', 'verified': true},
  };

  static const deliveryAddress = {
    'recipient_name': 'Juan Dela Cruz',
    'phone': '09171234567',
    'province': 'Metro Manila',
    'municipality': 'Quezon City',
    'barangay': 'Diliman',
    'street': 'Rizal Ave',
    'house_no': '123',
    'full_address': '123, Rizal Ave, Diliman, Quezon City, Metro Manila',
    'complete': true,
  };

  void reset() {
    requests.clear();
    placeError = null;
    addresses = [];
    nextAddressId = 40;
    defaultPin = null;
    usedUp = false;
    following.clear();
    otherFollowers = 4;
    votedHelpful = false;
    lastReport = null;
    resubmitted = null;
    cart = [
      {'id': 1, 'product': shirt, 'quantity': 1, 'variation_ids': [11], 'variation_label': 'Color: White'},
      {'id': 2, 'product': mug, 'quantity': 2, 'variation_ids': <int>[], 'variation_label': null},
    ];
  }

  Map<String, dynamic> _quote(Iterable<Map<String, dynamic>> lines, {String? voucher}) {
    final items = [
      for (final l in lines)
        () {
          final product = l['product'] as Map;
          final lineTotal = (product['price'] as double) * (l['quantity'] as int);
          final pct = voucher != null && voucher == product['voucher_code'] ? product['voucher_discount'] as double : 0.0;
          return {
            'cart_item_id': l['id'],
            'product': product,
            'variation_ids': l['variation_ids'],
            'variation_label': l['variation_label'],
            'quantity': l['quantity'],
            'available_stock': product['stock'],
            'unit_price': product['price'],
            'line_total': lineTotal,
            'discount': lineTotal * pct / 100,
            'issue': null,
          };
        }(),
    ];
    final merch = items.fold<double>(0, (s, i) => s + (i['line_total'] as double));
    final discount = items.fold<double>(0, (s, i) => s + (i['discount'] as double));
    return {
      'groups': items.isEmpty
          ? []
          : [
              {'seller': shirt['seller'], 'items': items, 'subtotal': merch, 'discount': discount, 'shipping_fee': 0.0},
            ],
      'shipping_option': null,
      'voucher': discount > 0 ? {'code': voucher, 'title': 'Product voucher', 'discount': discount} : null,
      'voucher_error': voucher != null && discount == 0 ? 'That voucher doesn’t apply to the selected items. Product vouchers are case-sensitive.' : null,
      'has_issues': false,
      'item_count': items.fold<int>(0, (s, i) => s + (i['quantity'] as int)),
      'totals': {
        'merchandise_subtotal': merch,
        'shipping_total': 0.0,
        'discount_total': discount,
        'service_fee': 0.0,
        'total': merch - discount,
      },
    };
  }

  Map<String, dynamic> get defaultAddress => {...deliveryAddress, 'pin': defaultPin, 'municipality_code': '137404000', 'barangay_code': '137404001'};

  Map<String, dynamic> get book => {'default': defaultAddress, 'addresses': addresses, 'max': 10};

  /// An address-book entry from the form body, shaped like BuyerPresenter::addressEntry.
  Map<String, dynamic> _entry(int id, Map<String, dynamic> b) {
    final line = [b['house_no'], b['street'], b['barangay'], b['municipality'], b['province']]
        .where((p) => p != null && '$p'.isNotEmpty)
        .join(', ');
    return {
      'id': id,
      'label': b['label'],
      'recipient_name': b['recipient_name'],
      'phone': b['contact_no'],
      'province': b['province'],
      'municipality': b['municipality'],
      'barangay': b['barangay'],
      'street': b['street'],
      'house_no': b['house_no'],
      'full_address': line,
      'complete': true,
      'pin': b['lat'] == null ? null : {'lat': b['lat'], 'lng': b['lng']},
    };
  }

  /// The quote's `vouchers`, priced like CheckoutVouchers: SAVE50 on the store's items, then PICK20.
  Map<String, dynamic> _vouchers(Iterable<Map<String, dynamic>> lines, Map<String, dynamic> body) {
    final merch = lines.fold<double>(0, (s, l) => s + ((l['product'] as Map)['price'] as double) * (l['quantity'] as int));
    final stores = <String, dynamic>{...?(body['store_vouchers'] as Map?)};
    var platform = body['platform_voucher'];
    String? error;
    final code = '${body['code'] ?? ''}'.toUpperCase();
    if (code == 'SAVE50') stores['3'] = 61;
    if (code == 'PICK20') platform = 62;
    if (code.isNotEmpty && code != 'SAVE50' && code != 'PICK20') error = '$code is not a voucher for these items.';
    final save50Problem = merch < 500 ? 'Spend ₱${(500 - merch).toStringAsFixed(2)} more to use this voucher.' : null;
    if (stores['3'] == 61 && save50Problem != null) {
      error ??= 'SAVE50: $save50Problem';
      stores.remove('3');
    }
    final storeSaving = stores['3'] == 61 ? 50.0 : 0.0;
    final platformSaving = platform == 62 ? 20.0 : 0.0;
    return {
      'stores': [
        {
          'seller_id': 3,
          'options': [
            {'id': 61, 'code': 'SAVE50', 'title': '₱50 off', 'summary': '₱50 off · min. spend ₱500', 'type': 'fixed', 'discount': 50, 'problem': save50Problem, 'ends_at': null},
          ],
        },
      ],
      'platform': [
        {'id': 62, 'code': 'PICK20', 'title': 'PickSell treat', 'summary': '₱20 off', 'type': 'fixed', 'discount': 20, 'problem': null, 'ends_at': null},
      ],
      'picked': {'stores': stores, 'platform': platform == 62 ? 62 : null},
      'store_savings': {'3': storeSaving},
      'platform_saving': platformSaving,
      'total': storeSaving + platformSaving,
      'error': error,
    };
  }

  /// Where a checkout ships, like the quote's ship_to.
  Map<String, dynamic>? _shipTo(Object? addressId) {
    if (addressId == null) {
      return {'address_id': null, 'label': 'Default', 'recipient_name': deliveryAddress['recipient_name'], 'phone': deliveryAddress['phone'],
          'full_address': deliveryAddress['full_address'], 'complete': true, 'pin': defaultPin};
    }
    final a = addresses.where((x) => x['id'] == addressId).firstOrNull;
    return a == null
        ? null
        : {'address_id': a['id'], 'label': a['label'], 'recipient_name': a['recipient_name'], 'phone': a['phone'],
            'full_address': a['full_address'], 'complete': a['complete'], 'pin': a['pin']};
  }

  http.Response _json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path.replaceFirst(RegExp(r'^/api/mobile'), '');
    final isJson = (r.headers['content-type'] ?? '').contains('json');
    final body = r.body.isEmpty || !isJson ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;

    switch ((r.method, path)) {
      case ('GET', '/buyer/cart'):
        return _json({'cart': _quote(cart)});
      case ('GET', '/buyer/cart/count'):
        return _json({'cart_count': cart.length}); // lines, as /api/mobile counts them
      case ('POST', '/buyer/cart'):
        final product = body['product_id'] == 7 ? shirt : mug;
        final ids = (body['variation_ids'] as List? ?? []).cast<int>();
        if (ids.length > 1) {
          return _json({'message': 'Choose one option.', 'errors': {'variation_ids': ['Choose one option.']}}, 422);
        }
        cart.add({'id': nextLineId, 'product': product, 'quantity': body['quantity'], 'variation_ids': ids, 'variation_label': ids.isEmpty ? null : 'Size: M'});
        return _json({'message': '${product['name']} added to cart.', 'cart_item_id': nextLineId++, 'cart_count': 99}, 201);
      case ('POST', '/buyer/checkout/quote'):
        final ids = (body['item_ids'] as List).cast<int>();
        final shipTo = _shipTo(body['address_id']);
        if (shipTo == null) return _addressIdError();
        final picked = cart.where((l) => ids.contains(l['id']));
        return _json({
          'quote': _quote(picked, voucher: body['voucher_code']),
          'delivery_address': defaultAddress,
          'ship_to': shipTo,
          'vouchers': _vouchers(picked, body),
        });
      case ('POST', '/buyer/checkout'):
        if (_shipTo(body['address_id']) == null) return _addressIdError();
        if (usedUp && (body['store_vouchers'] as Map?)?['3'] == 61) {
          return _json({'message': 'SAVE50: You have already used this voucher.', 'errors': {'vouchers': ['SAVE50: You have already used this voucher.']}}, 422);
        }
        if (placeError == 'stock') {
          return _json({'message': 'Not enough stock for: Cotton Basic Tee.', 'errors': {'item_ids': ['Not enough stock for: Cotton Basic Tee.']}}, 422);
        }
        final ids = (body['item_ids'] as List).cast<int>();
        final q = _quote(cart.where((l) => ids.contains(l['id'])), voucher: body['voucher_code']);
        cart.removeWhere((l) => ids.contains(l['id']));
        return _json({
          'message': 'Order placed! We’ll notify you as it moves.',
          'checkout_ref': 'ORD-TESTTEST',
          'total': (q['totals'] as Map)['total'],
          'orders': [
            {'id': 501, 'order_number': 'ORD-TESTTEST', 'status': 'placed', 'tab': 'to_ship', 'seller': shirt['seller'], 'product_id': 7, 'product_name': 'Cotton Basic Tee', 'quantity': 1, 'unit_price': 400, 'total': 400, 'created_at': '2026-10-21T10:00:00+08:00'},
          ],
        }, 201);
      case ('DELETE', '/buyer/cart'):
        final ids = (body['item_ids'] as List).cast<int>();
        cart.removeWhere((l) => ids.contains(l['id']));
        return _json({'cart': _quote(cart)});
      case ('GET', '/buyer/addresses'):
        return _json(book);
      case ('POST', '/buyer/addresses'):
        if (addresses.length >= 10) {
          return _json({'message': 'You can save up to 10 addresses.', 'errors': {'address': ['You can save up to 10 addresses.']}}, 422);
        }
        if ('${body['barangay'] ?? ''}'.isEmpty) {
          return _json({'message': 'The barangay field is required.', 'errors': {'barangay': ['The barangay field is required.']}}, 422);
        }
        addresses.add(_entry(nextAddressId++, body));
        return _json(book, 201);
      case ('PATCH', '/buyer/delivery-location'):
        final lat = toNum(body['lat']);
        if (lat == null || lat < 4 || lat > 22) {
          return _json({'message': 'Pin a spot inside the Philippines.', 'errors': {'lat': ['Pin a spot inside the Philippines.']}}, 422);
        }
        defaultPin = {'lat': body['lat'], 'lng': body['lng']};
        return _json({'message': 'Delivery pin saved.', 'parcels_updated': 2, 'delivery_address': defaultAddress});
      // A buyer whose sign-up was turned down: refused, with a way to fix it (website: resubmit page).
      case ('POST', '/login') when body['email'] == 'rejected@example.com':
        return _json({
          'message': 'Your registration was disapproved. Fix it and resubmit it for review.',
          'status': 'disapproved',
          'reason': 'The ID photo is blurry.',
          'documents': [
            {'field': 'id_upload', 'label': 'Government-issued ID'},
          ],
          'resubmit_token': 'r' * 64,
          'expires_in': 1800,
        }, 403);
      case ('POST', '/register/resubmit'):
        resubmitted = r.body;
        return _json({'status': 'pending', 'message': 'Your application was resubmitted and is pending approval again. You will be notified via email.'});
      case ('GET', '/products/7/reviews'):
        return _json({
          'summary': {'average': 4.5, 'count': 2, 'distribution': {'5': 1, '4': 1, '3': 0, '2': 0, '1': 0}},
          'reviews': [
            {'id': 31, 'reviewer': 'Maria S.', 'rating': 5, 'comment': 'Soft and true to size.', 'photos': [], 'helpful_count': 2 + (votedHelpful ? 1 : 0),
                'seller_reply': 'Salamat po!', 'created_at': '2026-11-01', 'is_helpful': votedHelpful, 'is_mine': false, 'reported': lastReport != null},
            {'id': 32, 'reviewer': 'Juan D.', 'rating': 4, 'comment': 'Nice.', 'photos': [], 'helpful_count': 0,
                'seller_reply': null, 'created_at': '2026-11-02', 'is_helpful': false, 'is_mine': true, 'reported': false},
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 2},
          'report_reasons': [
            {'code': 'fake', 'label': 'Fake or not from a real purchase'},
            {'code': 'spam', 'label': 'Spam or advertising'},
          ],
        });
      case ('POST', '/buyer/reviews/31/helpful'):
        votedHelpful = true;
        return _json({'helpful': true, 'count': 3});
      case ('DELETE', '/buyer/reviews/31/helpful'):
        votedHelpful = false;
        return _json({'helpful': false, 'count': 2});
      case ('POST', '/buyer/reviews/32/helpful'):
        return _json({'message': 'You cannot vote on your own review.'}, 422);
      case ('POST', '/buyer/reviews/31/report'):
        if (body['reason'] == null) {
          return _json({'message': 'Choose why you are reporting this review.', 'errors': {'reason': ['Choose why you are reporting this review.']}}, 422);
        }
        lastReport = body;
        return _json({'reported': true, 'message': 'Thanks. Our team will look at this review.'});
      case ('GET', '/buyer/following'):
        return _json({
          'stores': [
            if (following.contains(3))
              {...(shirt['seller'] as Map), 'logo': null, 'active_products': 2, 'followed_at': '2026-11-08T10:00:00+08:00'},
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': following.length},
        });
      case ('GET', '/sellers/3'):
        return _json({
          'seller': {...(shirt['seller'] as Map), 'rating': 4.8, 'review_count': 12, 'positive_rate': 98, 'product_count': 2, 'joined_at': '2025-01-10',
              'followers': otherFollowers + (following.contains(3) ? 1 : 0), 'is_following': following.contains(3)},
          'categories': ['Fashion', 'Home'],
          'products': [shirt, mug],
        });
      case ('GET', '/buyer/wishlist'):
        return _json({'products': []});
      case ('GET', '/buyer/notifications'):
        return _json({'notifications': [], 'unread_count': 0});
      case ('GET', '/buyer/orders/options'):
        return _json({
          'cancel_reasons': ['Ordered by mistake'],
          'report_categories': [],
          'return_reasons': ['Damaged item', 'Wrong item received', 'Wrong size', 'Not as described', 'Other'],
          'refund_methods': [],
        });

      // Sign-up, the website's flow.
      case ('POST', '/register/check-contact'):
        return body['email'] == 'taken@example.com'
            ? _json({'message': 'This email is already registered.', 'errors': {'email': ['This email is already registered. Try logging in instead.']}}, 422)
            : _json({'message': 'Available.'});
      case ('POST', '/register/email-code'):
        return _json({'message': 'We sent a 6-digit code to your email.', 'masked_email': 'j***n@example.com', 'expires_in': 300, 'resend_in': 60});
      case ('POST', '/register/email-code/verify'):
        return body['code'] == '123456'
            ? _json({'verified': true, 'message': 'Email verified.', 'registration_token': 'reg-token'})
            : _json({'message': 'That code is incorrect.', 'errors': {'code': ['That code is incorrect. You have 4 tries left.']}}, 422);
      case ('POST', '/register'):
        return _json({'status': 'pending', 'message': 'Registration submitted! Please wait for admin approval. You will be notified via email.'}, 201);
    }

    final cartItem = RegExp(r'^/buyer/cart/(\d+)$').firstMatch(path);
    if (cartItem != null) {
      final id = int.parse(cartItem.group(1)!);
      if (r.method == 'DELETE') {
        cart.removeWhere((l) => l['id'] == id);
      } else if (r.method == 'PATCH') {
        final q = body['quantity'] as int?;
        if (q != null && q > 5) {
          return _json({'message': 'Only 5 left in stock.', 'errors': {'quantity': ['Only 5 left in stock.']}}, 422);
        }
        cart = [for (final l in cart) l['id'] == id ? {...l, if (q != null) 'quantity': q} : l];
      }
      return _json({'cart': _quote(cart)});
    }

    final address = RegExp(r'^/buyer/addresses/(\d+)(/default)?$').firstMatch(path);
    if (address != null) {
      final id = int.parse(address.group(1)!);
      final i = addresses.indexWhere((a) => a['id'] == id);
      if (i < 0) return _json({'message': 'Not found.'}, 404);
      if (address.group(2) != null) {
        final picked = addresses.removeAt(i);
        addresses.add({..._entry(nextAddressId++, {
          'label': 'Previous default', 'recipient_name': deliveryAddress['recipient_name'], 'contact_no': deliveryAddress['phone'],
          'province': deliveryAddress['province'], 'municipality': deliveryAddress['municipality'], 'barangay': deliveryAddress['barangay'],
          'street': deliveryAddress['street'], 'house_no': deliveryAddress['house_no'],
        })});
        madeDefault = picked;
      } else if (r.method == 'DELETE') {
        addresses.removeAt(i);
      } else if (r.method == 'PATCH') {
        addresses[i] = _entry(id, body);
      }
      return _json(book);
    }

    // The rider's photo at the door: a 1x1 PNG, only when the order says there is one.
    if (r.method == 'GET' && RegExp(r'^/buyer/orders/\d+/proof-of-delivery$').hasMatch(path)) {
      if (orderDetail?['has_proof_of_delivery'] != true) return _json({'message': 'No delivery photo for this order yet.'}, 404);
      return http.Response.bytes(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='), 200,
          headers: {'content-type': 'image/png'});
    }

    final follow = RegExp(r'^/buyer/sellers/(\d+)/follow$').firstMatch(path);
    if (follow != null) {
      final id = int.parse(follow.group(1)!);
      if (id != 3) return _json({'message': 'Store not found.'}, 404);
      r.method == 'DELETE' ? following.remove(id) : following.add(id);
      return _json({'following': following.contains(id), 'followers': otherFollowers + (following.contains(id) ? 1 : 0)});
    }

    final order = RegExp(r'^/buyer/orders/(\d+)(/cancel|/received)?$').firstMatch(path);
    if (order != null && orderDetail != null) {
      if (order.group(2) == '/received') {
        // "Order Received": completed, and now it can be rated (website: OrderReceipt).
        orderDetail = {
          ...orderDetail!,
          'status': 'completed',
          'tab': 'to_rate',
          'actions': {...?(orderDetail!['actions'] as Map?), 'can_confirm_received': false, 'can_rate': true},
        };
      } else if (order.group(2) != null) {
        orderDetail = {
          ...orderDetail!,
          'status': 'cancelled',
          'tab': 'cancelled',
          'cancel_reason': body['reason'],
          'actions': {'can_cancel': false, 'can_reorder': true},
        };
      }
      return _json({'order': orderDetail});
    }

    if (r.method == 'POST' && path == '/password/forgot') {
      return _json({'message': 'If a PickSell account uses that email, we sent it a six-digit code.', 'expires_in': 300, 'resend_in': 60});
    }
    if (r.method == 'POST' && path == '/password/reset') {
      return body['code'] == '123456'
          ? _json({'message': 'Your password was changed. Log in with your new password.'})
          : _json({'message': 'The code is incorrect or has expired. Request a new one.', 'errors': {'code': ['The code is incorrect or has expired. Request a new one.']}}, 422);
    }

    if (r.method == 'GET' && path == '/products/7') {
      return _json({
        'product': {
          ...shirt,
          'description': 'Soft everyday tee.',
          'variation_groups': [
            {'name': 'Color', 'options': [{'id': 11, 'value': 'White', 'stock': 3}, {'id': 12, 'value': 'Black', 'stock': 5}]},
            {'name': 'Size', 'options': [{'id': 21, 'value': 'M', 'stock': 5}, {'id': 22, 'value': 'L', 'stock': 0}]},
          ],
          'max_quantity': 5,
          'seller': {...(shirt['seller'] as Map), 'rating': 4.8, 'review_count': 12, 'positive_rate': 98, 'product_count': 4},
          'rating_summary': {'average': 4.5, 'count': 2, 'distribution': {'5': 1, '4': 1, '3': 0, '2': 0, '1': 0}},
          'top_reviews': [],
          'shipping': null,
          'vouchers': [],
        },
      });
    }

    return _json({'message': 'Not found in fake: ${r.method} $path'}, 404);
  }

  /// The entry last made the default (its place moves onto the profile on the server).
  Map<String, dynamic>? madeDefault;

  static num? toNum(Object? v) => v is num ? v : num.tryParse('$v');

  http.Response _addressIdError() =>
      _json({'message': 'The selected address id is invalid.', 'errors': {'address_id': ['The selected address id is invalid.']}}, 422);

  /// Points every service at this fake and silences network fonts.
  Future<void> install() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    ApiClient.instance = ApiClient(client: MockClient(handle));
    CartStore.instance = CartStore();
    WishlistStore.instance = WishlistStore();
  }

  Iterable<http.Request> calls(String method, String pathSuffix) =>
      requests.where((r) => r.method == method && r.url.path.endsWith(pathSuffix));
}
