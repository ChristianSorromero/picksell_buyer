import 'package:flutter/material.dart';

/// Single source of truth for every color used in the app.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFFF4D4F);
  static const Color primaryLight = Color(0xFFFFEEEE);
  static const Color brandOrange = Color(0xFFE8632B); // "SELL" on splash

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color splashBackground = Color(0xFF121212);
  static const Color inputFill = Color(0xFFF3F4F6);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // ── Register page (multi-step form) ──────────────────────────────────────
  static const Color label = Color(0xFF1C1C1E);
  static const Color hint = textHint;
  static const Color progressBg = Color(0xFFFFDADB);
  static const Color cardShadow = Color(0x1A000000);

  // ── Status / ratings ─────────────────────────────────────────────────────
  static const Color star = Color(0xFFFFB400);
  static const Color success = Color(0xFF16A34A);
  static const Color verified = Color(0xFF1D9BF0);

  // ── Borders / indicators ─────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color dotInactive = Color(0xFFD1D5DB);

  // ── Social ───────────────────────────────────────────────────────────────
  static const Color facebook = Color(0xFF1877F2);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  // ── Placeholder tiles (landing page 3 collage) ───────────────────────────
  static const Color tileGrey = Color(0xFFEFEFEF);
  static const Color tileLight = Color(0xFFF7F7F7);
  static const Color tileYellow = Color(0xFFF6E7A6);
  static const Color tileCream = Color(0xFFFFF3C9);
  static const Color tileMint = Color(0xFFD5E8DB);
  static const Color tileRose = Color(0xFFF7D3D3);
}
