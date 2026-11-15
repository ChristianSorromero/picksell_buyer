import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/buyer/account/delete_account_page.dart';
import 'package:picksell/userpages/welcome_page.dart';

import 'support/fake_api.dart';

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const DeleteAccountPage()));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account')); // the confirm dialog
    // Fixed pumps: the welcome page's product carousel never settles.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a wrong password or an open order is explained and nothing is deleted', (tester) async {
    await open(tester);

    await submit(tester, 'wrong');
    expect(find.text('The password is incorrect.'), findsOneWidget);

    await submit(tester, 'busy');
    expect(find.textContaining('1 order in progress'), findsOneWidget);
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), 'test-token');
  });

  testWidgets('cancelling the confirmation sends nothing', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Password1!');
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep account'));
    await tester.pumpAndSettle();
    expect(api.calls('DELETE', '/buyer/account'), isEmpty);
  });

  testWidgets('deleting signs out and returns to the welcome page', (tester) async {
    await open(tester);
    await submit(tester, 'Password1!');
    expect(api.calls('DELETE', '/buyer/account'), hasLength(1));
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
  });
}
