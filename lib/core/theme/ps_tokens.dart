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
  static const double lg = 20;

  /// Hero tiles, promo bands and sheets.
  static const double xl = 24;
  static const double pill = 999;

  /// Soft, rounded cards (modern look): 20 for cards, 14 for buttons and fields.
  static final BorderRadius card = BorderRadius.circular(lg);
  static final BorderRadius field = BorderRadius.circular(14);
  static final BorderRadius button = BorderRadius.circular(14);
  static final BorderRadius sheet = const BorderRadius.vertical(top: Radius.circular(28));
}

class PsSize {
  PsSize._();

  /// Minimum interactive target (Apple HIG / Material a11y).
  static const double minTap = 44;
  static const double buttonHeight = 52;
  static const double fieldHeight = 52;
  static const double topBarHeight = 56;
  static const double bottomNavHeight = 58;
  static const double iconSm = 18;
  static const double icon = 22;
}

/// Motion rules: the duration follows what moves (a press is quicker than a
/// page), entering uses ease-out, leaving ease-in. Every animation goes
/// through [duration] so the phone's "remove animations" setting turns it off.
class PsMotion {
  PsMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  /// Button and card press feedback.
  static const Duration press = Duration(milliseconds: 120);

  /// Icon swaps (heart, nav icons, spinner ↔ label).
  static const Duration icon = Duration(milliseconds: 200);

  /// Small state changes: numbers, badges, selection.
  static const Duration small = Duration(milliseconds: 220);

  /// Cards and content replacing a loading state.
  static const Duration content = Duration(milliseconds: 280);

  /// Page pushes; back is a little quicker.
  static const Duration page = Duration(milliseconds: 300);
  static const Duration pageBack = Duration(milliseconds: 250);

  /// Bottom sheets and dialogs.
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration sheetBack = Duration(milliseconds: 220);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve change = Curves.easeInOutCubic;

  /// The phone asked for reduced motion (Android "Remove animations",
  /// iOS "Reduce Motion").
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero under reduced motion.
  static Duration duration(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
