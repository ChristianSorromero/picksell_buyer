import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/catalog.dart';
import 'package:picksell/services/cart_service.dart';
import 'package:picksell/services/checkout_service.dart';
import 'package:picksell/userpages/buyer/cart/cart_tab.dart';
import 'package:picksell/userpages/buyer/cart/checkout_page.dart';
import 'package:picksell/userpages/buyer/orders/order_details_page.dart';
import 'package:picksell/userpages/buyer/shop/product_detail_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  group('CartStore', () {
    test('loads the server-priced cart and keeps the badge count in sync', () async {
      final quote = await CartStore.instance.load();
      expect(quote.groups.single.items, hasLength(2));
      expect(CartStore.instance.count, 3);
      expect(quote.totals.merchandiseSubtotal, 1000);

      await CartStore.instance.setQuantity(quote.lines.first, 3);
      expect(CartStore.instance.count, 5);
      expect(CartStore.instance.quote.totals.merchandiseSubtotal, 1800);

      await CartStore.instance.remove(CartStore.instance.quote.lines.last);
      expect(CartStore.instance.count, 3);
    });

    test('surfaces the server’s stock limit as an ApiException', () async {
      final quote = await CartStore.instance.load();
      expect(
        () => CartStore.instance.setQuantity(quote.lines.first, 9),
        throwsA(predicate((e) => e.toString().contains('Only 5 left'))),
      );
    });

    test('quote and placement use the website rules: product voucher, COD, no fees', () async {
      final checkout = CheckoutService();
      final r = await checkout.quote(lineIds: [1, 2], voucherCode: 'TEE10');
      // Tee 400 -10% (TEE10) + mugs 600, no delivery fee.
      expect(r.quote.totals.total, 1000 - 40);
      expect(r.quote.totals.shippingTotal, 0);
      expect(r.deliveryAddress.recipientName, 'Juan Dela Cruz');

      final placed = await checkout.place(lineIds: [1, 2], voucherCode: 'TEE10');
      expect(placed.total, r.quote.totals.total);
      final sent = jsonDecode(api.calls('POST', '/buyer/checkout').single.body) as Map;
      expect(sent, containsPair('voucher_code', 'TEE10'));
      expect(sent, containsPair('payment_method', 'cod'));
      expect(sent.containsKey('address_id'), isFalse);
      expect(sent['item_ids'], [1, 2]);
    });
  });

  testWidgets('cart: quantity edit, deselect and checkout count', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const CartTab()));
    await tester.pumpAndSettle();

    expect(find.text('Island Threads'), findsOneWidget);
    expect(find.text('Cotton Basic Tee'), findsOneWidget);
    expect(find.text('Check Out (3)'), findsOneWidget);
    expect(find.text('₱1,000.00'), findsOneWidget);

    // + on the first line (tee) → PATCH quantity 2.
    await tester.tap(find.bySemanticsLabel('Increase quantity').first);
    await tester.pumpAndSettle();
    expect(jsonDecode(api.calls('PATCH', '/buyer/cart/1').single.body), {'quantity': 2});
    expect(find.text('Check Out (4)'), findsOneWidget);
    expect(find.text('₱1,400.00'), findsOneWidget);

    // Deselect the mug line.
    await tester.tap(find.bySemanticsLabel('Select Ceramic Mug'));
    await tester.pumpAndSettle();
    expect(find.text('Check Out (2)'), findsOneWidget);
    expect(find.text('₱800.00'), findsOneWidget);
  });

  testWidgets('cart: edit mode deletes selected lines after confirmation', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const CartTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Select Cotton Basic Tee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Remove 1 item?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(api.calls('DELETE', '/buyer/cart'), isNotEmpty);
    expect(find.text('Cotton Basic Tee'), findsNothing);
    expect(find.text('Ceramic Mug'), findsOneWidget);
  });

  testWidgets('checkout: shows server totals and places the order', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const CheckoutPage(lineIds: [1, 2])));
    await tester.pumpAndSettle();

    // Delivered to the profile address, as on the website.
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Merchandise Subtotal'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Merchandise Subtotal'), findsOneWidget);
    expect(find.text('₱1,000.00'), findsWidgets); // no delivery fee

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();

    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.textContaining('ORD-TESTTEST'), findsOneWidget);
    final sent = jsonDecode(api.calls('POST', '/buyer/checkout').single.body) as Map;
    expect(sent, containsPair('payment_method', 'cod'));
  });

  testWidgets('checkout: a stock conflict shows the "cart changed" popup', (tester) async {
    _phone(tester);
    api.placeError = 'stock';
    await tester.pumpWidget(_app(const CheckoutPage(lineIds: [1])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart changed'), findsOneWidget);
    expect(find.textContaining('Not enough stock for: Cotton Basic Tee.'), findsOneWidget);
  });

  testWidgets('product: add to cart needs one option, as a website cart line holds one', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const ProductDetailPage(productId: 7)));
    await tester.pumpAndSettle();

    expect(find.text('Cotton Basic Tee'), findsWidgets);
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();

    // Submit without choosing → both groups flagged.
    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    expect(find.text('Please select'), findsNWidgets(2));
    expect(api.calls('POST', '/buyer/cart'), isEmpty);

    // Sold-out size L is disabled. Choosing M after Black replaces it.
    final sheet = find.byType(BottomSheet);
    await tester.tap(find.descendant(of: sheet, matching: find.bySemanticsLabel('Black')));
    await tester.tap(find.descendant(of: sheet, matching: find.bySemanticsLabel('M')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.bySemanticsLabel('L, sold out')), findsOneWidget);

    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    final sent = jsonDecode(api.calls('POST', '/buyer/cart').single.body) as Map;
    expect(sent['variation_ids'], [21]);
    expect(find.textContaining('added to cart'), findsOneWidget);
  });

  testWidgets('order details: cancel is offered for a new order and confirmed', (tester) async {
    _phone(tester);
    api.orderDetail = {
      'id': 501,
      'order_number': 'PS-10000001',
      'status': 'placed',
      'tab': 'to_ship',
      'seller': FakeBuyerApi.shirt['seller'],
      'product_id': 7,
      'product_name': 'Cotton Basic Tee',
      'quantity': 1,
      'unit_price': 400,
      'total': 445,
      'subtotal': 400,
      'shipping_fee': 45,
      'payment_method': 'Cash on Delivery',
      'events': [
        {'status': 'placed', 'title': 'Order placed', 'description': 'Your order has been received.', 'occurred_at': '2026-10-21T10:00:00+08:00'},
      ],
      'actions': {'can_cancel': true, 'can_track': true},
    };
    await tester.pumpWidget(_app(const OrderDetailsPage(orderId: 501)));
    await tester.pumpAndSettle();

    expect(find.text('Order Placed'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cancel Order'), 200);
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordered by mistake'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);
    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();

    expect(jsonDecode(api.calls('POST', '/buyer/orders/501/cancel').single.body), {'reason': 'Ordered by mistake'});
    expect(find.text('Cancelled'), findsOneWidget);
  });

  test('ProductSort exposes every API sort value', () {
    expect(ProductSort.values.map((s) => s.apiValue), containsAll(['newest', 'popular', 'rating', 'price_asc', 'price_desc']));
  });
}
