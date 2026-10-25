import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/components/components.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/forgot_password_page.dart';

import 'support/fake_api.dart';

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

  testWidgets('buyer requests a code, then sets a new password with it', (tester) async {
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: PsTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Invalid email is caught before any request.
    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    expect(api.calls('POST', '/password/forgot'), isEmpty);

    await tester.enterText(find.byType(TextField).first, 'ana@test.ph');
    await tester.tap(find.text('SEND CODE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(jsonDecode(api.calls('POST', '/password/forgot').single.body), {'email': 'ana@test.ph'});
    await tester.scrollUntilVisible(find.textContaining('Resend code in'), 200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    expect(find.textContaining('Resend code in'), findsOneWidget);

    // Wrong code → inline error from the server; right code → page closes.
    Finder field(String label) => find.descendant(of: find.widgetWithText(PsTextField, label), matching: find.byType(TextField));
    final codeField = find.descendant(of: find.byType(PsOtpInput), matching: find.byType(TextField));
    for (final (finder, text) in [(codeField, '999999'), (field('New password'), 'NewPass1!'), (field('Confirm new password'), 'NewPass1!')]) {
      await tester.ensureVisible(finder);
      await tester.enterText(finder, text);
    }
    await tester.ensureVisible(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls('POST', '/password/reset'), hasLength(1));
    await tester.scrollUntilVisible(find.text('The code is incorrect or has expired. Request a new one.'), -200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    expect(find.text('The code is incorrect or has expired. Request a new one.'), findsOneWidget);

    await tester.ensureVisible(codeField);
    await tester.enterText(codeField, '123456');
    await tester.ensureVisible(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls('POST', '/password/reset'), hasLength(2));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ForgotPasswordPage), findsNothing);
  });
}
