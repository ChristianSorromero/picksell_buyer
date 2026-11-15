import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/components/components.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/buyer/shop/product_list_page.dart';

import 'support/fake_api.dart';

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openDiscover(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PsTheme.light,
        home: const ProductListPage(embedded: true, title: 'Discover'),
      ),
    );
    await tester.pumpAndSettle();
  }

  // An empty result used to throw during layout (the state was measured inside
  // SliverFillRemaining), which blanks the screen on a phone.
  testWidgets('Discover: an empty result shows its state, not a blank screen', (tester) async {
    phone(tester);
    api.catalogEmpty = true;
    await openDiscover(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(PsEmptyState), findsOneWidget);

    // Picking a filter reloads into the same state without throwing.
    await tester.tap(find.text('On sale'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No matches found'), findsOneWidget);
  });

  testWidgets('Discover filters send the website’s rating, location and price filters', (tester) async {
    phone(tester);
    await openDiscover(tester);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    // Provinces come from the server.
    expect(find.text('Laguna'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '0'), '100');
    await tester.tap(find.text('4★ & up'));
    await tester.tap(find.text('Near me'));
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    final q = api.calls('GET', '/products').last.url.queryParameters;
    expect([q['rating'], q['location'], q['min_price']], ['4', 'near', '100.0']);
    expect(find.byTooltip('Filters, 3 on'), findsOneWidget);

    await tester.tap(find.byTooltip('Filters, 3 on'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(api.calls('GET', '/products').last.url.queryParameters.containsKey('rating'), isFalse);
  });

  testWidgets('a search lists matching stores above the products', (tester) async {
    phone(tester);
    await openDiscover(tester);
    expect(find.text('Stores'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'island');
    await tester.pumpAndSettle();
    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('Island Threads'), findsWidgets);
  });
}
