import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:picksell/core/network/api_client.dart';
import 'package:picksell/services/cart_service.dart';
import 'package:picksell/services/wishlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the Laravel buyer API, enough for widget tests
/// of cart → checkout → orders. Prices are computed like CheckoutPricing.
class FakeBuyerApi {
  FakeBuyerApi() {
    reset();
  }

  final List<http.Request> requests = [];
  late List<Map<String, dynamic>> cart;
  int nextLineId = 100;
  String? placeError; // 'conflict' → 409
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

  void reset() {
    requests.clear();
    placeError = null;
    cart = [
      {'id': 1, 'product': shirt, 'quantity': 1, 'variation_ids': [11, 21], 'variation_label': 'White, M'},
      {'id': 2, 'product': mug, 'quantity': 2, 'variation_ids': <int>[], 'variation_label': null},
    ];
  }

  Map<String, dynamic> _quote(Iterable<Map<String, dynamic>> lines, {String shipping = 'standard', String? voucher}) {
    final items = [
      for (final l in lines)
        {
          'cart_item_id': l['id'],
          'product': l['product'],
          'variation_ids': l['variation_ids'],
          'variation_label': l['variation_label'],
          'quantity': l['quantity'],
          'available_stock': (l['product'] as Map)['stock'],
          'unit_price': (l['product'] as Map)['price'],
          'line_total': ((l['product'] as Map)['price'] as double) * (l['quantity'] as int),
          'discount': 0.0,
          'issue': null,
        },
    ];
    final merch = items.fold<double>(0, (s, i) => s + (i['line_total'] as double));
    final fee = shipping == 'express' ? 120.0 : 45.0;
    final discount = voucher == 'SAVE50' && merch >= 500 ? 50.0 : 0.0;
    return {
      'groups': items.isEmpty
          ? []
          : [
              {'seller': shirt['seller'], 'items': items, 'subtotal': merch, 'discount': discount, 'shipping_fee': fee},
            ],
      'shipping_option': {'code': shipping, 'name': shipping == 'express' ? 'Picksell Express' : 'Picksell Standard', 'fee': fee, 'min_days': 3, 'max_days': 5, 'official': true, 'estimated_from': '2026-10-24', 'estimated_to': '2026-10-26'},
      'voucher': discount > 0 ? {'code': 'SAVE50', 'title': '₱50 Off', 'discount': discount} : null,
      'voucher_error': voucher != null && discount == 0 ? 'We couldn’t find that voucher code.' : null,
      'has_issues': false,
      'item_count': items.fold<int>(0, (s, i) => s + (i['quantity'] as int)),
      'totals': {
        'merchandise_subtotal': merch,
        'shipping_total': items.isEmpty ? 0 : fee,
        'discount_total': discount,
        'service_fee': 0,
        'total': items.isEmpty ? 0 : merch - discount + fee,
      },
    };
  }

  http.Response _json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path.replaceFirst(RegExp(r'^/api'), '');
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;

    switch ((r.method, path)) {
      case ('GET', '/buyer/cart'):
        return _json({'cart': _quote(cart)});
      case ('GET', '/buyer/cart/count'):
        return _json({'cart_count': cart.fold<int>(0, (s, l) => s + (l['quantity'] as int))});
      case ('POST', '/buyer/cart'):
        final product = body['product_id'] == 7 ? shirt : mug;
        final ids = (body['variation_ids'] as List? ?? []).cast<int>();
        if (product == shirt && ids.length < 2) {
          return _json({'message': 'Please select a size.', 'errors': {'variation_ids': ['Please select a size.']}}, 422);
        }
        cart.add({'id': nextLineId, 'product': product, 'quantity': body['quantity'], 'variation_ids': ids, 'variation_label': ids.isEmpty ? null : 'Black, L'});
        return _json({'message': 'added', 'cart_item_id': nextLineId++, 'cart_count': 99}, 201);
      case ('POST', '/buyer/checkout/quote'):
        final ids = (body['item_ids'] as List).cast<int>();
        return _json({'quote': _quote(cart.where((l) => ids.contains(l['id'])), shipping: body['shipping_option'] ?? 'standard', voucher: body['voucher_code'])});
      case ('POST', '/buyer/checkout'):
        if (placeError == 'conflict') {
          return _json({'message': 'Some items in your order changed (stock or availability). Please review your cart.'}, 409);
        }
        final ids = (body['item_ids'] as List).cast<int>();
        final q = _quote(cart.where((l) => ids.contains(l['id'])), shipping: body['shipping_option'] ?? 'standard', voucher: body['voucher_code']);
        cart.removeWhere((l) => ids.contains(l['id']));
        return _json({
          'message': 'Order placed! We’ll notify you as it moves.',
          'checkout_ref': 'CO-TEST',
          'totals': q['totals'],
          'orders': [
            {'id': 501, 'order_number': 'PS-10000001', 'status': 'placed', 'tab': 'to_ship', 'seller': shirt['seller'], 'product_id': 7, 'product_name': 'Cotton Basic Tee', 'quantity': 1, 'unit_price': 400, 'total': 445, 'created_at': '2026-10-21T10:00:00+08:00'},
          ],
        }, 201);
      case ('DELETE', '/buyer/cart'):
        final ids = (body['item_ids'] as List).cast<int>();
        cart.removeWhere((l) => ids.contains(l['id']));
        return _json({'cart': _quote(cart)});
      case ('GET', '/buyer/addresses'):
        return _json({
          'addresses': [
            {'id': 9, 'label': 'home', 'recipient_name': 'Juan Dela Cruz', 'phone': '09171234567', 'province': 'Metro Manila', 'municipality': 'Quezon City', 'barangay': 'Diliman', 'street': 'Rizal Ave', 'full_address': '123 Rizal Ave, Brgy. Diliman, Quezon City, Metro Manila', 'is_default': true},
          ],
        });
      case ('GET', '/buyer/vouchers'):
        return _json({'platform': [], 'store': []});
      case ('GET', '/buyer/wishlist'):
        return _json({'products': []});
      case ('GET', '/buyer/notifications'):
        return _json({'notifications': [], 'unread_count': 0});
      case ('GET', '/buyer/orders/options'):
        return _json({'cancel_reasons': ['Ordered by mistake'], 'report_categories': [], 'return_reasons': [], 'refund_methods': [], 'return_window_days': 7});
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

    // Return cases: accept → resolved, decline → escalated, reply → back to review.
    final returnStep = RegExp(r'^/buyer/returns/(\d+)/(accept|decline|reply)$').firstMatch(path);
    if (returnStep != null && r.method == 'POST') {
      final (stage, label) = switch (returnStep.group(2)) {
        'accept' => ('resolved', 'Resolution agreed — in progress'),
        'decline' => ('escalated', 'Picksell is deciding'),
        _ => ('requested', 'Waiting for Picksell review'),
      };
      return _json({
        'message': 'ok',
        'return_request': {
          'id': int.parse(returnStep.group(1)!), 'status': stage == 'resolved' ? 'processing' : 'under_review', 'stage': stage,
          'stage_label': label, 'awaiting': null, 'quantity': 1, 'reason': 'Damaged or defective item',
          'refund_amount': 300, 'refund_to': 'Cash, handed over by a Picksell rider', 'requested_at': '2026-10-24T10:00:00+08:00',
        },
      });
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
          'shipping': {'code': 'standard', 'name': 'Picksell Standard', 'fee': 45, 'estimated_from': '2026-10-24', 'estimated_to': '2026-10-26'},
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
