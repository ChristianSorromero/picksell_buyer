import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ps_colors.dart';
import 'ps_tokens.dart';

/// App-wide [ThemeData] built from the Picksell tokens so stock Material
/// widgets (dialogs, date pickers, snack bars) match the components.
class PsTheme {
  PsTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PsColors.primary,
      primary: PsColors.primaryStrong,
      onPrimary: Colors.white,
      error: PsColors.error,
      surface: PsColors.surface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PsColors.background,
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme).apply(
        bodyColor: PsColors.textPrimary,
        displayColor: PsColors.textPrimary,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: PsColors.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PsColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PsRadius.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PsColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: PsRadius.sheet),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: PsColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: PsColors.primarySoft,
        headerForegroundColor: PsColors.textPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PsColors.surface,
        selectedColor: PsColors.textPrimary,
        disabledColor: PsColors.surfaceMuted,
        side: const BorderSide(color: PsColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: PsColors.textPrimary),
        secondaryLabelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PsColors.primary,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: PsColors.primaryStrong,
        selectionColor: PsColors.primarySoft,
        selectionHandleColor: PsColors.primaryStrong,
      ),
    );
  }
}
