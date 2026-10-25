import 'package:flutter/material.dart';

/// Spacing, radius and sizing rules shared by every component.
/// Frame: 390×844pt, 16pt side gutter, 44pt minimum touch target,
/// 12pt card radius, flat bordered cards.
class PsSpace {
  PsSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter.
  static const double gutter = 16;
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: gutter);
}

class PsRadius {
  PsRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius field = BorderRadius.circular(md);
  static final BorderRadius button = BorderRadius.circular(md);
  static final BorderRadius sheet =
      const BorderRadius.vertical(top: Radius.circular(20));
}

class PsSize {
  PsSize._();

  /// Minimum interactive target (Apple HIG / Material a11y).
  static const double minTap = 44;
  static const double buttonHeight = 52;
  static const double fieldHeight = 52;
  static const double topBarHeight = 56;
  static const double bottomNavHeight = 64;
  static const double iconSm = 18;
  static const double icon = 22;
}

class PsMotion {
  PsMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;
}
