import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

/// Primary sections of the Buyer app, in bottom-bar order.
enum BuyerTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  discover('Discover', Icons.explore_outlined, Icons.explore_rounded),
  cart('Cart', Icons.shopping_cart_outlined, Icons.shopping_cart_rounded),
  messages('Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  account('Account', Icons.person_outline_rounded, Icons.person_rounded);

  const BuyerTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// SYS-C03 Bottom Navigation Bar — persistent access to the primary
/// sections. Active tab is coral with an underline; [badges] adds a count
/// (cart) and [dots] an unread marker (messages).
class PsBottomNav extends StatelessWidget {
  const PsBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
    this.badges = const {},
    this.dots = const {},
  });

  final BuyerTab current;
  final ValueChanged<BuyerTab> onSelected;
  final Map<BuyerTab, int> badges;
  final Set<BuyerTab> dots;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PsColors.surface,
        border: Border(top: BorderSide(color: PsColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: PsSize.bottomNavHeight,
          child: Row(
            children: [
              for (final tab in BuyerTab.values)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    badge: badges[tab] ?? 0,
                    dot: dots.contains(tab),
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.badge,
    required this.dot,
    required this.onTap,
  });

  final BuyerTab tab;
  final bool selected;
  final int badge;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PsColors.primary : PsColors.textMuted;
    Widget icon = Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 24);
    if (badge > 0 || dot) {
      icon = Badge(
        backgroundColor: PsColors.primary,
        textColor: PsColors.onPrimary,
        smallSize: 8,
        label: badge > 0 ? Text(badge > 99 ? '99+' : '$badge') : null,
        child: icon,
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0 ? '${tab.label}, $badge items' : tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: PsText.caption.copyWith(
                fontSize: 11.5,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: PsMotion.normal,
              curve: PsMotion.curve,
              height: 3,
              width: selected ? 18 : 0,
              decoration: BoxDecoration(
                color: PsColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
