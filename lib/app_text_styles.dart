import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  /// Poppins headline used on landing pages and login.
  static TextStyle get heading => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  /// Big "PICK. SELL. REPEAT." title (set fontSize where used).
  static TextStyle get hero => GoogleFonts.poppins(
        fontWeight: FontWeight.w800,
        height: 0.98,
        letterSpacing: -1,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 13.5,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get skip => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get socialButton => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get fieldLabel => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      );

  static TextStyle get input => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textPrimary,
      );

  static TextStyle get hint => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textHint,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: AppColors.textHint,
      );

  static TextStyle get small => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textSecondary,
      );

  static TextStyle get link => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );

  static TextStyle get linkSmall => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );
}
