import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';

/// SYS-C20 Pull-to-Refresh — manual refresh of operational data.
/// [child] must be scrollable (the state views already are).
class PsRefreshable extends StatelessWidget {
  const PsRefreshable({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: PsColors.primaryStrong,
      backgroundColor: PsColors.surface,
      strokeWidth: 2.5,
      child: child,
    );
  }
}
