import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ps_colors.dart';

/// Type scale from the Figma exports: Open Sans for page titles,
/// Montserrat for everything else.
class PsText {
  PsText._();

  /// "Create your account", "Verify your email".
  static TextStyle get display => GoogleFonts.openSans(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.25,
        color: PsColors.textPrimary,
      );

  /// Top-bar titles ("My Orders", "Order Progress").
  static TextStyle get title => GoogleFonts.openSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: PsColors.textPrimary,
      );

  /// Section headings ("Recommended for You", status header).
  static TextStyle get heading => GoogleFonts.openSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: PsColors.textPrimary,
      );

  static TextStyle get subtitle => GoogleFonts.openSans(
        fontSize: 14.5,
        height: 1.45,
        color: PsColors.textSecondary,
      );

  static TextStyle get bodyStrong => GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: PsColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.montserrat(
        fontSize: 14,
        height: 1.45,
        color: PsColors.textPrimary,
      );

  static TextStyle get bodyMuted => GoogleFonts.montserrat(
        fontSize: 13.5,
        height: 1.45,
        color: PsColors.textMuted,
      );

  static TextStyle get label => GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: PsColors.textPrimary,
      );

  static TextStyle get input => GoogleFonts.montserrat(
        fontSize: 15,
        color: PsColors.textPrimary,
      );

  static TextStyle get hint => GoogleFonts.montserrat(
        fontSize: 15,
        color: PsColors.textHint,
      );

  static TextStyle get caption => GoogleFonts.montserrat(
        fontSize: 12.5,
        height: 1.4,
        color: PsColors.textMuted,
      );

  /// "STEP 1 OF 3", "TOTAL AMOUNT".
  static TextStyle get overline => GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: PsColors.textMuted,
      );

  /// Uppercase button label ("CONTINUE", "CREATE ACCOUNT").
  static TextStyle get button => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: PsColors.onPrimary,
      );

  static TextStyle get link => GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: PsColors.primaryStrong,
      );

  static TextStyle get error => GoogleFonts.montserrat(
        fontSize: 12.5,
        height: 1.4,
        color: PsColors.error,
      );

  static TextStyle get badge => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      );

  static TextStyle get price => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: PsColors.textPrimary,
      );

  /// One large digit inside the OTP boxes.
  /// Big promo numbers and hero headlines ("-24%", "Flash Picks").
  static TextStyle get hero => GoogleFonts.openSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -0.8,
        color: PsColors.textPrimary,
      );

  /// Short UI labels: chips, nav, tags.
  static TextStyle get ui => GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: PsColors.textPrimary,
      );

  static TextStyle get otpDigit => GoogleFonts.montserrat(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: PsColors.textPrimary,
      );
}
