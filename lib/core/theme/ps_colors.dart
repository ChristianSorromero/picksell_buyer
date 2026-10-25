import 'package:flutter/material.dart';

/// Picksell design-system colors, sampled from the Figma "Mobile Picksell UI"
/// exports. New components use these; [AppColors] remains for legacy screens
/// until they are migrated.
class PsColors {
  PsColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  /// Coral fill: primary buttons, active progress, Pick Thread.
  static const Color primary = Color(0xFFFF6F61);

  /// Deep coral: text-on-light links, step labels, checked controls.
  static const Color primaryStrong = Color(0xFFC93A2B);

  /// Soft coral wash: icon halos, selected chips, highlight surfaces.
  static const Color primarySoft = Color(0xFFFAEBE8);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF9F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEFEFEF);
  static const Color scrim = Color(0x66000000);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFC4C7CC);
  static const Color onPrimary = Color(0xFF1B1B1B);

  // ── Feedback ─────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF2E7D32);
  static const Color successSoft = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFEFF6FF);
  static const Color neutralSoft = Color(0xFFF3F4F6);

  static const Color star = Color(0xFFFF6F61);
}
