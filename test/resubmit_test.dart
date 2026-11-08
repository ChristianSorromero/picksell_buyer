import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/services/auth_service.dart';
import 'package:picksell/userpages/login.dart';
import 'package:picksell/userpages/resubmit_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The login screen's carousel animates forever, so time is advanced in steps instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  test('resubmit sends the single-use token and the new ID photo', () async {
    final dir = await Directory.systemTemp.createTemp('resubmit');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File('${dir.path}/clear-id.jpg')..writeAsStringSync('jpeg-bytes');

    final result = await AuthService().resubmit(token: 'r' * 64, idPhoto: photo.path);

    expect(result.success, isTrue);
    expect(result.message, contains('pending approval again'));
    expect(api.resubmitted, allOf(contains('name="resubmit_token"'), contains('r' * 64), contains('name="id_upload"'), contains('clear-id.jpg')));
  });

  testWidgets('a rejected buyer is offered to fix their sign-up and sees why', (tester) async {
    _phone(tester);
    // The login screen's decorative product carousel overflows with the test font; only that is ignored.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    await tester.pumpWidget(_app(const LoginPage()));
    await _settle(tester);

    await tester.enterText(find.byType(TextField).at(0), 'rejected@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Password1!');
    await tester.tap(find.text('LOG IN'));
    await _settle(tester);

    expect(find.text('Sign-up not approved'), findsOneWidget);
    expect(find.textContaining('The ID photo is blurry.'), findsOneWidget);
    await tester.tap(find.text('Fix and resubmit'));
    await _settle(tester);

    expect(find.text('Fix Your Sign-up'), findsOneWidget);
    expect(find.text('rejected@example.com'), findsOneWidget);
    expect(find.text('The ID photo is blurry.'), findsOneWidget);
    expect(find.text('Government-issued ID'), findsOneWidget);

    // A photo is required before anything is sent.
    await tester.tap(find.text('Resubmit for review'));
    await _settle(tester);
    expect(find.text('Add a clear photo of your ID first.'), findsOneWidget);
    expect(api.resubmitted, isNull);
  });

  testWidgets('the fix screen builds from the login refusal', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(ResubmitPage.fromRefusal('ana@example.com', {
      'resubmit_token': 'r' * 64,
      'reason': null,
      'documents': [
        {'field': 'id_upload', 'label': 'Government-issued ID'},
      ],
    })));
    await tester.pumpAndSettle();
    expect(find.text('No reason was given. Check your ID and upload a clearer photo.'), findsOneWidget);
  });
}
