import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

enum PsToastType { success, error, info }

/// SYS-C11 Toast / Feedback Message — short, non-blocking confirmation that
/// an action succeeded or failed. Replaces any toast already showing.
class PsToast {
  PsToast._();

  static void show(
    BuildContext context,
    String message, {
    PsToastType type = PsToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (icon, color) = switch (type) {
      PsToastType.success => (Icons.check_circle_rounded, PsColors.success),
      PsToastType.error => (Icons.error_rounded, PsColors.error),
      PsToastType.info => (Icons.info_rounded, PsColors.primary),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.md),
          backgroundColor: PsColors.textPrimary,
          elevation: 0,
          duration: Duration(seconds: type == PsToastType.error ? 4 : 3),
          shape: RoundedRectangleBorder(borderRadius: PsRadius.card),
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Text(message, style: PsText.body.copyWith(color: Colors.white)),
              ),
            ],
          ),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: PsColors.primary,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: PsToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: PsToastType.error);
}
