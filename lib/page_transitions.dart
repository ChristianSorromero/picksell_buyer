import 'package:flutter/material.dart';

import 'components/shared/ps_motion.dart';
import 'core/theme/ps_tokens.dart';

/// Fade for flow changes that replace the screen (splash → welcome, sign
/// in/out, registration steps): no sideways slide, since there's no "back".
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: PsMotion.page,
    reverseTransitionDuration: PsMotion.pageBack,
    transitionsBuilder: (context, animation, secondary, child) =>
        psPageTransition(context, animation, secondary, child, slide: false),
  );
}
