import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:picksell/components/commerce/ps_order_card.dart';
import 'package:picksell/core/network/api_client.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/cart.dart';
import 'package:picksell/models/order.dart';
import 'package:picksell/services/cart_service.dart';
import 'package:picksell/userpages/buyer/cart/cart_tab.dart';
import 'package:picksell/userpages/buyer/orders/orders_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _line(int id, int quantity) => {
      'id': id,
      'quantity': quantity,
      'unit_price': 100.0,
      'line_total': 100.0 * quantity,
      'product': {'id': id, 'name': 'Item $id', 'price': 100.0, 'stock': 10},
    };

CartQuote _quote(List<Map<String, dynamic>> lines) => CartQuote.fromJson({
      'groups': lines.isEmpty
          ? []
          : [
              {'seller': {'id': 3, 'name': 'Lamp House'}, 'items': lines},
            ],
      'item_count': lines.fold<int>(0, (s, l) => s + (l['quantity'] as int)),
      'totals': {},
    });

/// An order as /api/mobile lists it: `tab` is the server's own verdict on whether it can be rated.
Map<String, dynamic> _order(int id, String status, String tab) => {
      'id': id,
      'order_number': 'ORD-$id',
      'status': status,
      'tab': tab,
      'seller': {'id': 3, 'name': 'Lamp House', 'verified': true},
      'product_id': 7,
      'product_name': 'Desk Lamp $id',
      'quantity': 1,
      'unit_price': 850,
      'total': 850,
    };

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  group('cart count: distinct lines, like the badge', () {
    test('several units of one product are one line; two products are two', () {
      expect(_quote([_line(1, 3)]).lineCount, 1);
      expect(_quote([_line(1, 3), _line(2, 1)]).lineCount, 2);
      expect(_quote([_line(1, 3), _line(2, 1)]).itemCount, 4, reason: 'units stay available for totals');
      expect(_quote([]).lineCount, 0);
    });

    testWidgets('the header and the badge show the same number', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const CartTab()));
      await tester.pumpAndSettle();

      // The fake cart holds 2 lines with 3 units between them.
      expect(CartStore.instance.quote.itemCount, 3);
      expect(CartStore.instance.count, 2);
      expect(find.text('Cart (2)'), findsOneWidget);
      expect(find.text('Cart (3)'), findsNothing);
      expect(find.text('Check Out (3)'), findsOneWidget, reason: 'checkout still counts units');
    });

    testWidgets('an empty cart shows no count', (tester) async {
      _phone(tester);
      api.cart = [];
      await tester.pumpWidget(_app(const CartTab()));
      await tester.pumpAndSettle();

      expect(CartStore.instance.count, 0);
      expect(find.text('Cart'), findsOneWidget);
      expect(find.textContaining('Cart ('), findsNothing);
    });
  });

  group('order card actions', () {
    Future<void> pumpCard(WidgetTester tester, Map<String, dynamic> json, {VoidCallback? onRate, VoidCallback? onBuyAgain, VoidCallback? onTrack}) async {
      _phone(tester);
      await tester.pumpWidget(_app(Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PsOrderCard(
            order: OrderSummaryItem.fromJson(json),
            onTap: () {},
            onRate: onRate ?? () {},
            onBuyAgain: onBuyAgain ?? () {},
            onTrack: onTrack ?? () {},
          ),
        ),
      )));
      await tester.pump();
    }

    testWidgets('a completed, unrated order offers Rate Order and keeps Buy Again', (tester) async {
      var rated = 0, again = 0;
      await pumpCard(tester, _order(1, 'completed', 'to_rate'), onRate: () => rated++, onBuyAgain: () => again++);

      expect(find.text('Rate Order'), findsOneWidget);
      expect(find.text('Buy Again'), findsOneWidget);
      await tester.tap(find.text('Rate Order'));
      await tester.tap(find.text('Buy Again'));
      expect([rated, again], [1, 1]);
      expect(tester.takeException(), isNull, reason: 'both actions fit a 390pt-wide phone');
    });

    testWidgets('a delivered, unrated order offers Rate Order only', (tester) async {
      await pumpCard(tester, _order(2, 'delivered', 'to_rate'));
      expect(find.text('Rate Order'), findsOneWidget);
      expect(find.text('Buy Again'), findsNothing);
    });

    testWidgets('an already-rated order has no Rate Order', (tester) async {
      await pumpCard(tester, _order(3, 'completed', 'completed'));
      expect(find.text('Rate Order'), findsNothing);
      expect(find.text('Buy Again'), findsOneWidget);

      await pumpCard(tester, _order(4, 'delivered', 'completed'));
      expect(find.text('Rate Order'), findsNothing);
    });

    testWidgets('orders that cannot be rated yet have no Rate Order', (tester) async {
      await pumpCard(tester, _order(5, 'at_sorting_center', 'in_transit'));
      expect(find.text('Rate Order'), findsNothing);
      expect(find.text('Track Order'), findsOneWidget);

      await pumpCard(tester, _order(6, 'cancelled', 'cancelled'));
      expect(find.text('Rate Order'), findsNothing);
      expect(find.text('Buy Again'), findsOneWidget);
    });
  });

  testWidgets('To Rate: Rate Order opens the existing rating sheet and submits as before', (tester) async {
    _phone(tester);
    final requests = <http.Request>[];
    var rated = false;
    ApiClient.instance = ApiClient(
      client: MockClient((r) async {
        requests.add(r);
        final path = r.url.path.replaceFirst('/api/mobile', '');
        if (r.method == 'GET' && path == '/buyer/orders') {
          return http.Response(
            jsonEncode({
              'orders': [if (!rated) _order(601, 'completed', 'to_rate')],
              'counts': {'to_rate': rated ? 0 : 1},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.method == 'POST' && path == '/buyer/orders/601/rate') {
          rated = true;
          return http.Response(
            jsonEncode({
              'order': {..._order(601, 'completed', 'completed'), 'subtotal': 850, 'shipping_fee': 0, 'events': [], 'actions': {}},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'message': 'unexpected ${r.method} $path'}), 404, headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(_app(const OrdersPage(initial: OrderTab.toRate)));
    await tester.pumpAndSettle();
    expect(find.text('Rate Order'), findsOneWidget);
    expect(find.text('Buy Again'), findsOneWidget);

    await tester.tap(find.text('Rate Order'));
    await tester.pumpAndSettle();
    expect(find.text('Rate your order'), findsOneWidget, reason: 'the existing rating sheet');

    await tester.tap(find.byIcon(Icons.star_outline_rounded).last);
    await tester.pump();
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, endsWith('/buyer/orders/601/rate'));
    expect(jsonDecode(post.body), {'rating': 5});
    expect(find.text('Rate Order'), findsNothing, reason: 'the list reloads without the rated order');
  });
}
