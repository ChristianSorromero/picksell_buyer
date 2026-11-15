import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/buyer/shop/search_page.dart';
import 'package:picksell/userpages/buyer/shop/store_page.dart';

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

  testWidgets('the store page shows the seller’s banner, logo and about text', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const StorePage(sellerId: 3)));
    await tester.pumpAndSettle();

    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((n) => n.url);
    expect(urls, containsAll(['https://example.test/banner.jpg', 'https://example.test/logo.png']));
    expect(find.text('Island-made tees and homeware.'), findsOneWidget);
  });

  testWidgets('searching a seller’s name offers their store profile', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const SearchPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'island');
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pumpAndSettle();
    expect(find.text('Store · Cebu City, Cebu'), findsOneWidget);

    await tester.tap(find.text('Island Threads'));
    await tester.pumpAndSettle();
    expect(find.byType(StorePage), findsOneWidget);
  });
}
