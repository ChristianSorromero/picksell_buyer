import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../ps_buttons.dart';
import 'ps_state_layout.dart';

/// SYS-C14 Error State — human-readable problem plus a recovery action.
class PsErrorState extends StatelessWidget {
  const PsErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We couldn’t load this right now. Please try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return PsCenteredScrollable(
      child: PsStateLayout(
        icon: Icons.error_outline_rounded,
        iconColor: PsColors.error,
        haloColor: PsColors.errorSoft,
        title: title,
        message: message,
        action: onRetry == null
            ? null
            : PsPrimaryButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                uppercase: false,
                expand: false,
              ),
      ),
    );
  }
}
