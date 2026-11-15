import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/services/onboarding_store.dart';
import 'package:picksell/userpages/onboarding_page.dart';
import 'package:picksell/userpages/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The intro slides run 1 → 2 → 3, then the welcome page, and show once.
void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // The slides and the waterfall animate forever, so step time instead of pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Next walks the three slides, then Get started opens the welcome page', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const OnboardingPage()));
    await settle(tester);

    expect(find.text('SHOP SMART.\nBUY FAST.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next slide'));
    await settle(tester);
    expect(find.text('DISCOVER\nUNIQUE FINDS.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next slide'));
    await settle(tester);
    expect(find.text('TRACK EVERY\nORDER.'), findsOneWidget);
    expect(await OnboardingStore.seen(), isFalse);

    await tester.tap(find.bySemanticsLabel('Get started'));
    await settle(tester);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(await OnboardingStore.seen(), isTrue, reason: 'the slides show once per install');

    await tester.pumpWidget(const SizedBox()); // stop the waterfall
  });

  testWidgets('swiping moves between slides, and Skip goes straight to the welcome page', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: PsTheme.light, home: const OnboardingPage()));
    await settle(tester);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await settle(tester);
    expect(find.text('DISCOVER\nUNIQUE FINDS.'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(await OnboardingStore.seen(), isTrue);

    await tester.pumpWidget(const SizedBox());
  });
}
