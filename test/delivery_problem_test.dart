import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/buyer/orders/delivery_problem_page.dart';
import 'package:picksell/userpages/buyer/orders/off_platform_report_page.dart';
import 'package:picksell/userpages/buyer/orders/order_details_page.dart';

import 'support/fake_api.dart';

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
    api.orderDetail = {
      'id': 502,
      'order_number': 'PS-10000002',
      'status': 'out_for_delivery',
      'tab': 'to_receive',
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
      'actions': {'can_track': true, 'can_report': true, 'can_report_delivery': true},
    };
  });

  // The button keeps spinning under the result dialog, so pump frames
  // instead of waiting for everything to settle.
  Future<void> settleUpload(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Order details → "Problem with the delivery?".
  Future<void> openFromOrder(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const OrderDetailsPage(orderId: 502)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Problem with the delivery?'), 200);
    await tester.ensureVisible(find.text('Problem with the delivery?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Problem with the delivery?'));
    await tester.pumpAndSettle();
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('order details offers a delivery report apart from Report a Problem', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const OrderDetailsPage(orderId: 502)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Problem with the delivery?'), 200);
    await tester.ensureVisible(find.text('Problem with the delivery?'));
    await tester.pumpAndSettle();
    expect(find.text('Report a Problem'), findsOneWidget);

    await tester.tap(find.text('Problem with the delivery?'));
    await tester.pumpAndSettle();
    expect(find.byType(DeliveryProblemPage), findsOneWidget);
    // The server's list of buyer problem types.
    expect(find.text('Rider conduct'), findsOneWidget);
  });

  testWidgets('a type and a description are required, then the report is sent once', (tester) async {
    phone(tester);
    await openFromOrder(tester);

    await tester.tap(find.text('Send Report'));
    await tester.pumpAndSettle();
    expect(find.text('Choose what went wrong.'), findsOneWidget);
    expect(api.deliveryProblems, isEmpty);

    await tester.tap(find.text('Delivery very late'));
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Still not here after a week.');
    await tester.tap(find.text('Send Report'));
    await settleUpload(tester);

    expect(api.deliveryProblems, hasLength(1));
    expect(api.deliveryProblems.single.body, contains('late'));
    expect(find.text('Report sent'), findsOneWidget);
  });

  testWidgets('a report already open is refused with the reason, and the form stays', (tester) async {
    phone(tester);
    api.deliveryProblemOpen = true;
    await openFromOrder(tester);

    await tester.tap(find.text('Rider conduct'));
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'The rider asked for an extra fee.');
    await tester.tap(find.text('Send Report'));
    await settleUpload(tester);

    expect(find.text('Couldn’t send report'), findsOneWidget);
    expect(find.textContaining('already reported'), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.byType(DeliveryProblemPage), findsOneWidget);
  });

  testWidgets('reporting a seller who asked to pay outside PickSell', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const OrderDetailsPage(orderId: 502)));
    await tester.pumpAndSettle();
    final entry = find.text('Seller asked to pay outside PickSell?');
    await tester.scrollUntilVisible(entry, 200);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(OffPlatformReportPage), findsOneWidget);

    await tester.tap(find.text('Report seller').last);
    await tester.pumpAndSettle();
    expect(find.text('Tell us what the seller asked (at least 10 characters).'), findsOneWidget);
    expect(api.offPlatformReports, isEmpty);

    await tester.enterText(find.byType(TextField), 'Asked me to pay by GCash instead.');
    await tester.tap(find.text('Report seller').last);
    await settleUpload(tester);
    expect(api.offPlatformReports, ['Asked me to pay by GCash instead.']);
    expect(find.text('Report sent'), findsOneWidget);
  });
}
