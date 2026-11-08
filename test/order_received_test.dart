import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/status/order_status.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/order.dart';
import 'package:picksell/services/order_service.dart';
import 'package:picksell/userpages/buyer/orders/order_details_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _delivered() => {
      'id': 501,
      'order_number': 'PS-10000001',
      'status': 'delivered',
      'tab': 'out_for_delivery',
      'seller': FakeBuyerApi.shirt['seller'],
      'product_id': 7,
      'product_name': 'Cotton Basic Tee',
      'quantity': 1,
      'unit_price': 400,
      'total': 445,
      'subtotal': 400,
      'shipping_fee': 45,
      'payment_method': 'Cash on Delivery',
      'events': [],
      'auto_confirm_at': '2026-11-13T15:00:00+08:00',
      'actions': {'can_confirm_received': true, 'can_rate': false, 'can_track': true},
    };

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  test('Order Received completes the order and opens rating', () async {
    api.orderDetail = _delivered();
    final before = await OrderService().detail(501);
    expect((before.actions.canConfirmReceived, before.actions.canRate), (true, false));

    final after = await OrderService().confirmReceived(501);
    expect(after.status, OrderStatus.completed);
    expect((after.actions.canConfirmReceived, after.actions.canRate), (false, true));
    expect(api.calls('POST', '/buyer/orders/501/received'), hasLength(1));
  });

  test('the "out_for_delivery" tab is the buyer’s To Receive', () {
    expect(OrderTab.outForDelivery.label, 'To Receive');
    expect(OrderTab.fromApi('out_for_delivery'), OrderTab.outForDelivery);
  });

  testWidgets('a delivered order: Order Received, confirm, then the rating sheet', (tester) async {
    _phone(tester);
    api.orderDetail = _delivered();
    await tester.pumpWidget(_app(const OrderDetailsPage(orderId: 501)));
    await tester.pumpAndSettle();

    expect(find.text('Rate Product'), findsNothing, reason: 'not before confirming receipt');
    await tester.scrollUntilVisible(find.textContaining('We’ll confirm it for you on Nov 13, 2026'), 200);
    await tester.scrollUntilVisible(find.text('Order Received'), 200);
    await tester.tap(find.text('Order Received'));
    await tester.pumpAndSettle();
    expect(find.text('Got your order?'), findsOneWidget);
    await tester.tap(find.text('Yes, I received it'));
    await tester.pumpAndSettle();

    expect(api.calls('POST', '/buyer/orders/501/received'), hasLength(1));
    expect(find.text('Rate your order'), findsOneWidget);
  });
}
