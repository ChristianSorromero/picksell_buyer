import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:picksell/components/components.dart';
import 'package:picksell/core/theme/ps_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => PsColors.isDark = false);

  testWidgets('dark set swaps surfaces and text but keeps Coral and the text on it', (tester) async {
    PsTheme.light;
    final lightSurface = PsColors.surface, lightText = PsColors.textPrimary;
    PsTheme.dark;
    expect(PsColors.surface, isNot(lightSurface));
    expect(PsColors.textPrimary, isNot(lightText));
    expect(PsColors.primary, const Color(0xFFFF6F61));
    expect(PsColors.onPrimary, const Color(0xFF1B1B1B));
    expect(StatusTone.error.foreground, PsColors.errorStrong);
  });

  testWidgets('a card and its text use the dark set', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: PsTheme.dark, home: PsAppShell(body: PsCard(child: Text('Hi', style: PsText.body)))));
    final card = tester.widget<Material>(find.descendant(of: find.byType(PsCard), matching: find.byType(Material)).first);
    expect(card.color, PsColors.surface);
    expect(tester.widget<Text>(find.text('Hi')).style?.color, PsColors.textPrimary);
    expect(Theme.of(tester.element(find.text('Hi'))).brightness, Brightness.dark);
  });
}
