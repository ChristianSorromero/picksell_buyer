import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  /// Poppins headline used on landing pages and login.
  static TextStyle get heading => GoogleFonts.montserrat(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  /// Big "PICK. SELL. REPEAT." title (set fontSize where used).
  static TextStyle get hero => GoogleFonts.montserrat(
        fontWeight: FontWeight.w800,
        height: 0.98,
        letterSpacing: -1,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.openSans(
        fontSize: 13.5,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get skip => GoogleFonts.openSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get button => GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get fieldLabel => GoogleFonts.openSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      );

  static TextStyle get input => GoogleFonts.openSans(
        fontSize: 14,
        color: AppColors.textPrimary,
      );

  static TextStyle get hint => GoogleFonts.openSans(
        fontSize: 14,
        color: AppColors.textHint,
      );

  static TextStyle get caption => GoogleFonts.openSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: AppColors.textHint,
      );

  static TextStyle get small => GoogleFonts.openSans(
        fontSize: 12,
        color: AppColors.textSecondary,
      );

  static TextStyle get link => GoogleFonts.openSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );

  static TextStyle get linkSmall => GoogleFonts.openSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );
}
