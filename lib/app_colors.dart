import 'package:flutter/material.dart';

import 'core/theme/ps_colors.dart';

/// Single source of truth for every color used in the app.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = PsColors.primary;
  static Color get primaryLight => PsColors.primarySoft;
  static const Color brandOrange = Color(0xFFE8632B); // "SELL" on splash

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static Color get background => PsColors.background;
  static const Color splashBackground = Color(0xFF121212);
  static const Color inputFill = Color(0xFFF3F4F6);

  // ── Text ─────────────────────────────────────────────────────────────────
  static Color get textPrimary => PsColors.textPrimary;
  static Color get textSecondary => PsColors.textMuted;
  static Color get textHint => PsColors.textHint;

  // ── Register page (multi-step form) ──────────────────────────────────────
  static const Color label = Color(0xFF1C1C1E);
  static Color get hint => PsColors.textHint;
  static const Color progressBg = Color(0xFFFFDADB);
  static const Color cardShadow = Color(0x1A000000);

  // ── Status / ratings ─────────────────────────────────────────────────────
  static const Color star = Color(0xFFFFB400);
  static const Color success = Color(0xFF16A34A);
  static const Color verified = Color(0xFF1D9BF0);

  // ── Borders / indicators ─────────────────────────────────────────────────
  static Color get border => PsColors.border;
  static const Color dotInactive = Color(0xFFD1D5DB);

  // ── Placeholder tiles (landing page 3 collage) ───────────────────────────
  static const Color tileGrey = Color(0xFFEFEFEF);
  static const Color tileLight = Color(0xFFF7F7F7);
  static const Color tileYellow = Color(0xFFF6E7A6);
  static const Color tileCream = Color(0xFFFFF3C9);
  static const Color tileMint = Color(0xFFD5E8DB);
  static const Color tileRose = Color(0xFFF7D3D3);
}
