import 'package:flutter/material.dart';

/// Picksell design-system colors, sampled from the Figma "Mobile Picksell UI"
/// exports, with a dark set for phones in dark mode. [PsColors.isDark] is set
/// by the app root from the phone's setting; every getter then answers with
/// the matching shade. New components use these; [AppColors] remains for
/// legacy screens until they are migrated.
class PsColors {
  PsColors._();

  /// Which set the getters return. Set by the app root (see main.dart).
  static bool isDark = false;

  static Color _p(int light, int dark) => Color(isDark ? dark : light);

  // ── Brand ────────────────────────────────────────────────────────────────
  /// Coral fill: primary buttons, active progress, Pick Thread. Same in both themes.
  static const Color primary = Color(0xFFFF6F61);

  /// Deep coral: text links, step labels, checked controls.
  static Color get primaryStrong => _p(0xFFBF3526, 0xFFFF8A7E);

  /// Soft coral wash: icon halos, selected chips, highlight surfaces.
  static Color get primarySoft => _p(0xFFFAEBE8, 0xFF3A2220);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static Color get background => _p(0xFFF9F8F6, 0xFF131313);
  static Color get surface => _p(0xFFFFFFFF, 0xFF1E1E1E);
  static Color get surfaceMuted => _p(0xFFF3F4F6, 0xFF2A2A2A);
  static Color get border => _p(0xFFE5E7EB, 0xFF3A3A3A);
  static Color get divider => _p(0xFFEFEFEF, 0xFF2C2C2C);
  static Color get scrim => _p(0x66000000, 0x99000000);

  // ── Text ─────────────────────────────────────────────────────────────────
  static Color get textPrimary => _p(0xFF1B1B1B, 0xFFF9F8F6);
  static Color get textSecondary => _p(0xFF4B5563, 0xFFD1D5DB);
  static Color get textMuted => _p(0xFF6B7280, 0xFFA3A3AB);
  static Color get textHint => _p(0xFF6B7280, 0xFF9A9AA2);
  static Color get textDisabled => _p(0xFFC4C7CC, 0xFF5C5F66);

  /// Text and icons on a Coral fill: always Eerie Black, in both themes.
  static const Color onPrimary = Color(0xFF1B1B1B);

  // ── Feedback ─────────────────────────────────────────────────────────────
  static Color get error => _p(0xFFDC2626, 0xFFF87171);

  /// Error text on [errorSoft] banners and badges.
  static Color get errorStrong => _p(0xFFB91C1C, 0xFFFCA5A5);
  static Color get errorSoft => _p(0xFFFEF2F2, 0xFF3B1C1C);
  static Color get success => _p(0xFF2E7D32, 0xFF6FCF73);
  static Color get successSoft => _p(0xFFE8F5E9, 0xFF1A2E1B);
  static Color get warning => _p(0xFFB45309, 0xFFFBBF24);
  static Color get warningSoft => _p(0xFFFEF3C7, 0xFF382C0E);
  static Color get info => _p(0xFF1D4ED8, 0xFF93C5FD);
  static Color get infoSoft => _p(0xFFEFF6FF, 0xFF172033);
  static Color get neutralSoft => _p(0xFFF3F4F6, 0xFF2A2A2A);

  static Color get star => _p(0xFFE8503F, 0xFFFF7A6E);
}
