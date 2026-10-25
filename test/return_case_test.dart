import 'dart:convert';

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

/// An order whose return has a seller proposal waiting for the buyer.
OrderDetail _orderWithProposal() => OrderDetail.fromJson({
      'id': 501,
      'order_number': 'PS-10000001',
      'status': 'delivered',
      'tab': 'to_rate',
      'product_id': 8,
      'product_name': 'Ceramic Mug',
      'quantity': 1,
      'total': 345,
      'events': [],
      'actions': {},
      'return_request': {
        'id': 9,
        'status': 'under_review',
        'stage': 'proposed',
        'stage_label': 'Seller proposed a resolution',
        'awaiting': 'decide',
        'proposal': {'type': 'return_and_refund', 'label': 'Return item for a refund', 'amount': 300, 'item_must_return': true, 'note': 'Sorry about that'},
        'quantity': 1,
        'reason': 'Damaged or defective item',
        'refund_amount': 300,
        'refund_to': 'Cash, handed over by a Picksell rider',
        'requested_at': '2026-10-24T10:00:00+08:00',
      },
    });

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  testWidgets('buyer declines a seller proposal with a reason, sending it to Picksell', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(RefundStatusPage(order: _orderWithProposal())));
    await tester.pumpAndSettle();

    expect(find.text('Seller proposed a resolution'), findsOneWidget);
    expect(find.text('Return item for a refund'), findsOneWidget);
    expect(find.textContaining('refunded to you in cash'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEND TO PICKSELL'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us why you don’t accept.'), findsOneWidget);
    expect(api.calls('POST', '/buyer/returns/9/decline'), isEmpty);

    await tester.enterText(find.byType(TextField), 'Refund is too low');
    await tester.tap(find.text('SEND TO PICKSELL'));
    await tester.pumpAndSettle();

    expect(jsonDecode(api.calls('POST', '/buyer/returns/9/decline').single.body), {'reason': 'Refund is too low'});
    expect(find.text('Picksell is deciding'), findsOneWidget);
    expect(find.text('Seller’s proposal'), findsNothing);
  });

  testWidgets('buyer accepts a seller proposal', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(RefundStatusPage(order: _orderWithProposal())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACCEPT'));
    await tester.pumpAndSettle();

    expect(api.calls('POST', '/buyer/returns/9/accept'), hasLength(1));
    expect(find.text('Resolution agreed — in progress'), findsOneWidget);
  });
}
