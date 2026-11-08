import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/services/follow_service.dart';
import 'package:picksell/userpages/buyer/account/following_page.dart';
import 'package:picksell/userpages/buyer/shop/store_page.dart';

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

  test('FollowService follows, lists and unfollows; repeats are safe', () async {
    final service = FollowService();
    expect((await service.set(3, follow: true)).following, isTrue);
    final again = await service.set(3, follow: true);
    expect((again.following, again.followers), (true, 5));
    expect(api.calls('POST', '/buyer/sellers/3/follow'), hasLength(2));

    final list = await service.following();
    expect(list.stores.single.name, 'Island Threads');
    expect(list.stores.single.activeProducts, 2);
    expect(list.meta.total, 1);

    final off = await service.set(3, follow: false);
    expect((off.following, off.followers), (false, 4));
    expect(api.calls('DELETE', '/buyer/sellers/3/follow'), hasLength(1));
  });

  testWidgets('store page: Follow shows the count and flips to Following', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const StorePage(sellerId: 3)));
    await tester.pumpAndSettle();

    expect(find.text('Follow · 4'), findsOneWidget);
    await tester.tap(find.text('Follow · 4'));
    await tester.pumpAndSettle();

    expect(find.text('Following · 5'), findsOneWidget);
    expect(find.text('You are now following Island Threads.'), findsOneWidget);
    expect(api.following, {3});

    await tester.tap(find.text('Following · 5'));
    await tester.pumpAndSettle();
    expect(find.text('Follow · 4'), findsOneWidget);
    expect(api.following, isEmpty);
  });

  testWidgets('Following lists followed stores and unfollows after confirming', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const FollowingPage()));
    await tester.pumpAndSettle();
    expect(find.text('Not following any stores yet'), findsOneWidget);

    api.following.add(3);
    await tester.pumpWidget(_app(FollowingPage(key: UniqueKey())));
    await tester.pumpAndSettle();
    expect(find.text('Following (1)'), findsOneWidget);
    expect(find.text('Island Threads'), findsOneWidget);
    expect(find.text('Cebu City, Cebu · 2 products'), findsOneWidget);

    await tester.tap(find.text('Unfollow'));
    await tester.pumpAndSettle();
    expect(find.text('Unfollow Island Threads?'), findsOneWidget);
    await tester.tap(find.text('Unfollow').last);
    await tester.pumpAndSettle();

    expect(api.following, isEmpty);
    expect(find.text('Island Threads'), findsNothing);
  });
}
