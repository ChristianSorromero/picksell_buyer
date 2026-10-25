import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:picksell/components/components.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/userpages/register.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void main() {
  // Tests run offline: fall back to the default font instead of fetching.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('phone field strips a leading 0 and groups 3-3-4', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_app(Scaffold(body: PsPhoneField(controller: controller))));

    await tester.enterText(find.byType(TextField), '09171234567');
    await tester.pump();

    expect(controller.text, '917 123 4567');
    expect(PsPhoneField.digitsOf(controller.text), '9171234567');
    expect(PsPhoneField.toLocalFormat('9171234567'), '09171234567');
  });

  testWidgets('step 1 shows inline errors, then advances to step 2', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const RegisterPage()));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('First name is required.'), findsOneWidget);
    expect(find.text('Last name is required.'), findsOneWidget);
    expect(find.text('Date of birth is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Juan');
    await tester.enterText(find.byType(TextField).at(1), 'Dela Cruz');
    await tester.pump();
    expect(find.text('First name is required.'), findsNothing);

    // The picker opens on the 18th birthday, which is valid.
    await tester.tap(find.byType(PsDateField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Date of birth is required.'), findsNothing);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('Your contact details'), findsOneWidget);

    // Back returns to step 1 with the data kept.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
  });

  testWidgets('step 2 validates email and PH mobile locally', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const RegisterPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Juan');
    await tester.enterText(find.byType(TextField).at(1), 'Dela Cruz');
    await tester.tap(find.byType(PsDateField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'john@');
    await tester.enterText(find.byType(TextField).at(1), '812');
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter a valid PH mobile number (e.g. 917 123 4567).'), findsOneWidget);
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
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
