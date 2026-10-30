import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/order.dart';
import 'package:picksell/userpages/buyer/orders/refund_status_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// An order whose return the seller approved on the website.
OrderDetail _orderWithReturn(Map<String, dynamic> returnRequest) => OrderDetail.fromJson({
      'id': 501,
      'order_number': 'ORD-TESTTEST',
      'status': 'delivered',
      'tab': 'to_rate',
      'product_id': 8,
      'product_name': 'Ceramic Mug',
      'quantity': 1,
      'total': 300,
      'events': [],
      'actions': {},
      'return_request': {
        'id': 9,
        'quantity': 1,
        'reason': 'Damaged item',
        'details': 'Chipped rim',
        'refund_amount': 300,
        'refund_to': 'Handled by PickSell support',
        'requested_at': '2026-10-24T10:00:00+08:00',
        ...returnRequest,
      },
    });

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  testWidgets('an approved return shows the website step, the seller note and the return shipment', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(RefundStatusPage(order: _orderWithReturn({
      'status': 'under_review',
      'stage': 'awaiting_item',
      'stage_label': 'Approved: send the item back to the seller',
      'seller_note': 'Please ship it back in the box',
      'tracking': {'carrier': 'J&T', 'number': 'JT123', 'status': 'in_transit'},
    }))));
    await tester.pumpAndSettle();

    expect(find.text('Approved: send the item back to the seller'), findsOneWidget);
    // Not refunded yet: the header is what the buyer asked for, not a promise.
    expect(find.text('AMOUNT REQUESTED'), findsOneWidget);
    expect(find.text('J&T · JT123 (in transit)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Please ship it back in the box'), 200);
    expect(find.text('Please ship it back in the box'), findsOneWidget);
    // The website has no buyer accept/decline step.
    expect(find.text('ACCEPT'), findsNothing);
    expect(find.text('Decline'), findsNothing);
  });

  testWidgets('a declined request explains that support is reviewing it', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(RefundStatusPage(order: _orderWithReturn({
      'status': 'rejected',
      'stage': 'rejected',
      'stage_label': 'The seller declined; PickSell support is reviewing it',
    }))));
    await tester.pumpAndSettle();

    expect(find.text('The seller declined; PickSell support is reviewing it'), findsOneWidget);
  });

  testWidgets('a completed refund shows the refunded amount', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(RefundStatusPage(order: _orderWithReturn({
      'status': 'refunded',
      'stage': 'completed',
      'stage_label': 'Refund completed',
    }))));
    await tester.pumpAndSettle();

    expect(find.text('REFUND AMOUNT'), findsOneWidget);
    expect(find.text('Refund completed'), findsOneWidget);
  });
}
