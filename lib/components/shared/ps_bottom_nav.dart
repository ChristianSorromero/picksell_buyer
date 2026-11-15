import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import 'ps_motion.dart';

/// Primary sections of the Buyer app, in bottom-bar order.
enum BuyerTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  discover('Discover', Icons.grid_view_outlined, Icons.grid_view_rounded),
  cart('Cart', Icons.shopping_cart_outlined, Icons.shopping_cart_rounded),
  messages('Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  account('Account', Icons.person_outline_rounded, Icons.person_rounded);

  const BuyerTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// SYS-C03 Bottom Navigation Bar: a floating dark bar with icon + label for
/// every section; the active tab is bright with a Coral tick under it.
/// [badges] adds a count (cart) and [dots] an unread marker (messages).
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

  /// The bar itself: Eerie Black in light mode, a raised grey in dark mode.
  static Color get barColor => PsColors.isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1B1B1B);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PsColors.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(PsRadius.xl),
              boxShadow: PsColors.isDark
                  ? null
                  : const [BoxShadow(color: Color(0x471B1B1B), blurRadius: 28, offset: Offset(0, 10))],
            ),
            child: SizedBox(
              height: 66,
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

  // Fixed for the dark bar in both themes (Bone White / soft grey, 7:1 and up).
  static const _on = Color(0xFFF9F8F6);
  static const _off = Color(0xFFA3A3AB);

  @override
  Widget build(BuildContext context) {
    final color = selected ? _on : _off;
    Widget icon = PsIconSwap(icon: Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 23));
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
      child: PsPressable(
        scale: 0.92,
        child: InkResponse(
          onTap: onTap,
          radius: 30,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: PsText.ui.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: PsMotion.duration(context, PsMotion.normal),
                curve: PsMotion.curve,
                height: 3,
                width: selected ? 16 : 0,
                decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
