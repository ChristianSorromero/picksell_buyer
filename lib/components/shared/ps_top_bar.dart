import 'package:flutter/material.dart';

import '../../app_assets.dart';
import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import 'ps_buttons.dart';

/// Picksell brand mark (dark rounded square "P").
class PsBrandMark extends StatelessWidget {
  const PsBrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Picksell',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(AppAssets.brandMark, width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }
}

/// SYS-C02 Top Navigation Bar.
///
/// * default: back button + centered [title] (My Orders, Order Progress)
/// * [PsTopBar.brand]: back button + centered brand mark (auth flows)
/// * pass [actions] for notifications/cart/more shortcuts.
///
/// The back button appears automatically when the route can pop, unless
/// [showBack] says otherwise.
class PsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const PsTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.bottom,
  });

  const PsTopBar.brand({
    super.key,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.bottom,
  })  : title = null,
        titleWidget = const PsBrandMark();

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool? showBack;

  /// Overrides the default `Navigator.maybePop`, e.g. to go back a step
  /// inside a multi-step flow.
  final VoidCallback? onBack;

  /// Optional widget under the bar (segmented control, step progress…).
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(PsSize.topBarHeight + 8 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final back = showBack ?? (canPop || onBack != null);

    return Material(
      color: PsColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: PsSize.topBarHeight + 8,
              child: NavigationToolbar(
                middleSpacing: 8,
                leading: back
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: PsIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          tooltip: 'Back',
                          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                        ),
                      )
                    : const SizedBox(width: PsSpace.gutter),
                middle: titleWidget ??
                    (title == null
                        ? null
                        : Text(title!, style: PsText.title, overflow: TextOverflow.ellipsis)),
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}
