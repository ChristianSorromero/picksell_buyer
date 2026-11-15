import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../services/account_service.dart';
import '../../services/cart_service.dart';
import 'account/notifications_page.dart';
import 'nav.dart';
import 'shop/search_page.dart';

/// SYS-C02 Top Navigation Bar for shopping screens: a search bar that fills
/// the row (no logo here), notifications (unread dot) and cart (count badge)
/// as rounded square buttons.
class ShopHeader extends StatelessWidget implements PreferredSizeWidget {
  const ShopHeader({super.key, this.hint = 'Search Picksell…', this.showBack = false, this.bottom});

  final String hint;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(PsSize.topBarHeight + 8 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PsColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: PsSize.topBarHeight + 8,
              child: Padding(
                padding: EdgeInsets.only(left: showBack ? PsSpace.xs : PsSpace.gutter, right: PsSpace.gutter),
                child: Row(
                  children: [
                    if (showBack) ...[
                      PsIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 20, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: PsSpace.xxs),
                    ],
                    Expanded(
                      child: PsSearchBar(
                        hint: hint,
                        readOnly: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
                      ),
                    ),
                    const SizedBox(width: PsSpace.xs),
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationBadge.instance,
                      builder: (_, unread, __) => HeaderSquareButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
                        dot: unread > 0,
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
                      ),
                    ),
                    const SizedBox(width: PsSpace.xs),
                    ListenableBuilder(
                      listenable: CartStore.instance,
                      builder: (_, __) {
                        final n = CartStore.instance.count;
                        return HeaderSquareButton(
                          icon: Icons.shopping_cart_outlined,
                          tooltip: n > 0 ? 'Cart, $n items' : 'Cart',
                          count: n,
                          dark: true,
                          onPressed: () => ShellNav.goTo(context, BuyerTab.cart),
                        );
                      },
                    ),
                  ],
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

/// Cart icon bound to [CartStore.count].
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (_, __) {
        final n = CartStore.instance.count;
        return PsIconButton(
          icon: Icons.shopping_cart_outlined,
          tooltip: n > 0 ? 'Cart, $n items' : 'Cart',
          badgeCount: n,
          onPressed: onPressed,
        );
      },
    );
  }
}

/// Rounded square header button (48×48): light with a border, or dark (cart).
/// [dot] marks unread; [count] shows a Coral count badge.
class HeaderSquareButton extends StatelessWidget {
  const HeaderSquareButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.dot = false, this.count = 0, this.dark = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool dot;
  final int count;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // The dark button stays dark in dark mode too (raised grey there).
    final bg = dark ? (PsColors.isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1B1B1B)) : PsColors.surface;
    final fg = dark ? const Color(0xFFF9F8F6) : PsColors.textPrimary;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: dark ? BorderSide.none : BorderSide(color: PsColors.border),
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 22, color: fg),
                  if (dot)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: PsColors.primary, shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
                      ),
                    ),
                  if (count > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PsColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PsColors.background, width: 2),
                        ),
                        child: Text(count > 99 ? '99+' : '$count', style: PsText.badge.copyWith(color: PsColors.onPrimary)),
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
