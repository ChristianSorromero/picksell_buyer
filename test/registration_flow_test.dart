import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/components/components.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/register.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The registration page's own list (text fields have scrollables too).
final _page = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

/// Fills step 1 (personal) and continues to step 2.
Future<void> _personalStep(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Juan');
  await tester.enterText(find.byType(TextField).at(2), 'Dela Cruz');
  // The picker opens on the 18th birthday, which is valid.
  await tester.tap(find.byType(PsDateField));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Male'), 200, scrollable: _page);
  await tester.tap(find.text('Male'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
}

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  testWidgets('phone field strips a leading 0 and groups 3-3-4', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_app(Scaffold(body: PsPhoneField(controller: controller))));

    await tester.enterText(find.byType(TextField), '09171234567');
    await tester.pump();

    expect(controller.text, '917 123 4567');
    expect(PsPhoneField.digitsOf(controller.text), '9171234567');
    expect(PsPhoneField.toLocalFormat('9171234567'), '09171234567');
  });

  testWidgets('step 1 needs name, date of birth and sex, like the website', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const RegisterPage()));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('First name is required.'), findsOneWidget);
    expect(find.text('Last name is required.'), findsOneWidget);
    expect(find.text('Date of birth is required.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Select your sex.'), 200, scrollable: _page);
    expect(find.text('Select your sex.'), findsOneWidget);
  });

  testWidgets('step 1 advances to step 2 and Back keeps the data', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const RegisterPage()));
    await tester.pumpAndSettle();

    await _personalStep(tester);
    expect(find.text('STEP 2 OF 4'), findsOneWidget);

    // Back returns to step 1 with the data kept.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
  });

  testWidgets('the email is proven with a code before the address and ID step', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const RegisterPage()));
    await tester.pumpAndSettle();
    await _personalStep(tester);

    // Local checks first.
    await tester.enterText(find.byType(TextField).at(0), 'john@');
    await tester.enterText(find.byType(TextField).at(1), '812');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(api.calls('POST', '/register/email-code'), isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'juan@example.com');
    await tester.enterText(find.byType(TextField).at(1), '9171234567');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    expect(jsonDecode(api.calls('POST', '/register/email-code').single.body), containsPair('email', 'juan@example.com'));
    expect(find.text('Verify your email'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 4'), findsOneWidget);
    expect(find.text('Address and valid ID'), findsOneWidget);

    // No account is created yet, and the ID photo is required.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Upload a photo of a valid ID.'), 200, scrollable: _page);
    expect(find.text('Upload a photo of a valid ID.'), findsOneWidget);
    expect(api.calls('POST', '/register'), isEmpty);

    // Going back to the email shows it is already verified: no second code.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Email verified'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 4'), findsOneWidget);
    expect(api.calls('POST', '/register/email-code'), hasLength(1));
  });

  testWidgets('a taken email is flagged before any code is sent', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const RegisterPage()));
    await tester.pumpAndSettle();
    await _personalStep(tester);

    await tester.enterText(find.byType(TextField).at(0), 'taken@example.com');
    await tester.enterText(find.byType(TextField).at(1), '9171234567');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered. Try logging in instead.'), findsOneWidget);
    expect(api.calls('POST', '/register/email-code'), isEmpty);
  });

  testWidgets('Pick Thread derives done/current/upcoming from status', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: PsPickThread.forOrder(
        current: OrderStatus.atSortingCenter,
        timestamps: const {OrderStatus.placed: 'Oct 12, 2023 · 10:30 AM'},
      ),
    )));

    expect(find.text('Order Placed'), findsOneWidget);
    expect(find.text('At Sorting Center'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^At Sorting Center, current step$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Delivered, upcoming$')), findsOneWidget);
  });
}
