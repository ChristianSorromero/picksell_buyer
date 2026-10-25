import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import 'states/ps_offline_state.dart';

/// SYS-C01 App Shell — the consistent mobile frame every screen sits in:
/// background, safe areas, top bar, optional bottom nav, sticky footer
/// actions, offline banner, and tap-outside-to-dismiss-keyboard.
class PsAppShell extends StatelessWidget {
  const PsAppShell({
    super.key,
    required this.body,
    this.topBar,
    this.bottomNav,
    this.footer,
    this.offline = false,
    this.onRetryConnection,
    this.backgroundColor = PsColors.background,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? topBar;

  /// Usually a [PsBottomNav].
  final Widget? bottomNav;

  /// Sticky action area pinned above the keyboard/bottom edge
  /// (e.g. CONTINUE + Back). Use [PsFooterActions].
  final Widget? footer;

  /// Shows [PsOfflineBanner] under the top bar.
  final bool offline;
  final VoidCallback? onRetryConnection;
  final Color backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: topBar,
        body: SafeArea(
          top: topBar == null,
          bottom: footer == null && bottomNav == null,
          child: Column(
            children: [
              AnimatedSize(
                duration: PsMotion.normal,
                child: offline
                    ? PsOfflineBanner(onRetry: onRetryConnection)
                    : const SizedBox(width: double.infinity),
              ),
              Expanded(child: body),
              if (footer != null) footer!,
            ],
          ),
        ),
        bottomNavigationBar: bottomNav,
      ),
    );
  }
}

/// Sticky footer for [PsAppShell.footer]: a top hairline, the primary
/// action and an optional secondary action under it.
class PsFooterActions extends StatelessWidget {
  const PsFooterActions({
    super.key,
    required this.primary,
    this.secondary,
    this.showDivider = true,
  });

  final Widget primary;
  final Widget? secondary;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PsColors.background,
        border: showDivider
            ? const Border(top: BorderSide(color: PsColors.divider))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.md, PsSpace.gutter, PsSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              primary,
              if (secondary != null) ...[const SizedBox(height: PsSpace.xs), secondary!],
            ],
          ),
        ),
      ),
    );
  }
}
