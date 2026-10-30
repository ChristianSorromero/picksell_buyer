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

  http.Response _json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path.replaceFirst(RegExp(r'^/api'), '');
    final isJson = (r.headers['content-type'] ?? '').contains('json');
    final body = r.body.isEmpty || !isJson ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;

    switch ((r.method, path)) {
      case ('GET', '/buyer/cart'):
        return _json({'cart': _quote(cart)});
      case ('GET', '/buyer/cart/count'):
        return _json({'cart_count': cart.fold<int>(0, (s, l) => s + (l['quantity'] as int))});
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
        return _json({'quote': _quote(cart.where((l) => ids.contains(l['id'])), voucher: body['voucher_code']), 'delivery_address': deliveryAddress});
      case ('POST', '/buyer/checkout'):
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

    final order = RegExp(r'^/buyer/orders/(\d+)(/cancel)?$').firstMatch(path);
    if (order != null && orderDetail != null) {
      if (order.group(2) != null) {
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
