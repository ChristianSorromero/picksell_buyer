import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/shared/ps_motion.dart';
import 'ps_colors.dart';
import 'ps_tokens.dart';

/// App-wide [ThemeData] built from the Picksell tokens so stock Material
/// widgets (dialogs, date pickers, snack bars) match the components.
class PsTheme {
  PsTheme._();

  /// Light theme (also switches [PsColors] to its light set).
  static ThemeData get light {
    PsColors.isDark = false;
    return current;
  }

  /// Dark theme (also switches [PsColors] to its dark set).
  static ThemeData get dark {
    PsColors.isDark = true;
    return current;
  }

  /// The theme for the palette [PsColors] is set to (light or dark).
  static ThemeData get current {
    final brightness = PsColors.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PsColors.primary,
      brightness: brightness,
      primary: PsColors.primaryStrong,
      onPrimary: PsColors.isDark ? PsColors.onPrimary : Colors.white,
      error: PsColors.error,
      surface: PsColors.surface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PsColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: PsColors.background,
        foregroundColor: PsColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: GoogleFonts.montserratTextTheme(
        base.textTheme,
      ).apply(bodyColor: PsColors.textPrimary, displayColor: PsColors.textPrimary),
      splashFactory: InkSparkle.splashFactory,
      // Every MaterialPageRoute: Picksell slide-fade on Android, the native
      // swipe-back transition on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: PsPageTransitionsBuilder(),
          TargetPlatform.linux: PsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: PsPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: PsColors.divider, thickness: 1, space: 1),
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PsColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: PsSpace.md, vertical: PsSpace.sm),
        border: OutlineInputBorder(
          borderRadius: PsRadius.field,
          borderSide: BorderSide(color: PsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PsRadius.field,
          borderSide: BorderSide(color: PsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PsRadius.field,
          borderSide: BorderSide(color: PsColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PsRadius.field,
          borderSide: BorderSide(color: PsColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: PsRadius.field,
          borderSide: BorderSide(color: PsColors.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(PsSize.minTap, PsSize.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(PsSize.minTap, PsSize.minTap),
          shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
          side: BorderSide(color: PsColors.border),
        ),
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
        side: BorderSide(color: PsColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: PsColors.textPrimary),
        secondaryLabelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: PsColors.surface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: PsColors.primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: PsColors.primaryStrong,
        selectionColor: PsColors.primarySoft,
        selectionHandleColor: PsColors.primaryStrong,
      ),
    );
  }
}
