import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/components/components.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/buyer/nav.dart';
import 'package:picksell/userpages/buyer/shop/product_detail_page.dart';
import 'package:picksell/userpages/buyer/shop/product_list_page.dart';
import 'package:picksell/userpages/buyer/shop/store_page.dart';

import 'support/fake_api.dart';

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    ShellNav.discoverCategory.value = '';
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
    expect(find.text('No products match your filters'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
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

  // The detail page's own vertical list (photo and suggestion rows scroll sideways).
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

  String? lastCategory() => api.calls('GET', '/products').last.url.queryParameters['category'];

  // Home → Fashion → All used to keep "Fashion" in the header.
  testWidgets('a category list: choosing All resets the header and the results', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: PsTheme.light,
      home: const ProductListPage(title: 'Fashion', initialCategory: 'Fashion'),
    ));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('Fashion')), findsOneWidget);
    expect(lastCategory(), 'Fashion');

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('All Products')), findsOneWidget);
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('Fashion')), findsNothing);
    expect(lastCategory(), isNull);
  });

  testWidgets('Discover follows the shared category; Home’s All brings it back to everything', (tester) async {
    phone(tester);
    ShellNav.discoverCategory.value = 'Home';
    await openDiscover(tester);
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('Home')), findsOneWidget);
    expect(lastCategory(), 'Home');

    final before = api.calls('GET', '/products').length;
    ShellNav.discoverCategory.value = '';
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('Discover')), findsOneWidget);
    expect(lastCategory(), isNull);
    expect(api.calls('GET', '/products').length, before + 1, reason: 'one request per change');
  });

  testWidgets('a search with no results explains itself and can be cleared', (tester) async {
    phone(tester);
    await openDiscover(tester);
    api.catalogEmpty = true;
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No products found'), findsOneWidget);
    expect(find.textContaining('Try another keyword'), findsOneWidget);
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('“zzzz”')), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(lastCategory(), isNull);
    expect(api.calls('GET', '/products').last.url.queryParameters.containsKey('search'), isFalse);
    expect(find.descendant(of: find.byType(PsTopBar), matching: find.text('Discover')), findsOneWidget);
  });

  testWidgets('product details: same-category suggestions, without the product itself', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const ProductDetailPage(productId: 7)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('You May Also Like'), 300, scrollable: page);
    await tester.pumpAndSettle();

    expect(lastCategory(), 'Fashion');
    final row = find.byType(PsProductCarousel);
    expect(find.descendant(of: row, matching: find.text('Ceramic Mug')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Cotton Basic Tee')), findsNothing);
  });

  testWidgets('product details: the seller’s name opens the same store as View Store', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const ProductDetailPage(productId: 7)));
    await tester.pumpAndSettle();
    final name = find.descendant(of: find.byType(PsSellerCard), matching: find.text('Island Threads'));
    await tester.scrollUntilVisible(name, 200, scrollable: page);
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(find.byType(StorePage), findsOneWidget);
    expect(tester.widget<StorePage>(find.byType(StorePage)).sellerId, 3);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Store'));
    await tester.pumpAndSettle();
    expect(tester.widget<StorePage>(find.byType(StorePage)).sellerId, 3);
  });
}
