import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/services/order_service.dart';
import 'package:picksell/userpages/buyer/orders/order_details_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _order({required bool delivered}) => {
      'id': 501,
      'order_number': 'PS-10000001',
      'status': delivered ? 'delivered' : 'out_for_delivery',
      'tab': delivered ? 'completed' : 'to_receive',
      'seller': FakeBuyerApi.shirt['seller'],
      'product_id': 7,
      'product_name': 'Cotton Basic Tee',
      'quantity': 1,
      'unit_price': 400,
      'total': 445,
      'subtotal': 400,
      'shipping_fee': 45,
      'payment_method': 'Cash on Delivery',
      'payment_status': delivered ? 'paid' : 'unpaid',
      'courier': {'name': 'Rico Santos', 'vehicle': 'Motorcycle · NBC 1234', 'phone': delivered ? null : '09181234567'},
      'has_proof_of_delivery': delivered,
      'delivered_at': delivered ? '2026-11-08T15:30:00+08:00' : null,
      'events': [],
      'actions': {},
    };

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  test('the delivery photo downloads with the buyer’s login; none means 404', () async {
    api.orderDetail = _order(delivered: true);
    final bytes = await OrderService().proofOfDelivery(501);
    expect(bytes, isNotEmpty);
    expect(api.calls('GET', '/buyer/orders/501/proof-of-delivery').single.headers['Authorization'], 'Bearer test-token');

    api.orderDetail = _order(delivered: false);
    expect(() => OrderService().proofOfDelivery(501), throwsA(predicate((e) => e.toString().contains('404'))));
  });

  testWidgets('order details: rider and payment while on the way, then the delivery photo', (tester) async {
    _phone(tester);
    api.orderDetail = _order(delivered: false);
    await tester.pumpWidget(_app(const OrderDetailsPage(orderId: 501)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('To pay on delivery'), 200);
    expect(find.text('Rico Santos · Motorcycle · NBC 1234'), findsOneWidget);
    expect(find.text('Proof of Delivery'.toUpperCase()), findsNothing);

    api.orderDetail = _order(delivered: true);
    await tester.pumpWidget(_app(OrderDetailsPage(key: UniqueKey(), orderId: 501)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Photo taken by Rico Santos'), 200);
    expect(find.text('Tap to view full photo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Paid'), 200);

    await tester.scrollUntilVisible(find.text('Tap to view full photo'), -200);
    await tester.tap(find.text('Tap to view full photo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
