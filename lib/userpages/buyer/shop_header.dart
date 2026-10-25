import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../services/account_service.dart';
import '../../services/cart_service.dart';
import 'account/notifications_page.dart';
import 'nav.dart';
import 'shop/search_page.dart';

/// SYS-C02 Top Navigation Bar for shopping screens: brand, search entry,
/// notifications bell (unread dot) and cart (count badge).
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
                padding: const EdgeInsets.symmetric(horizontal: PsSpace.xs),
                child: Row(
                  children: [
                    if (showBack)
                      PsIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 20, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop())
                    else
                      const Padding(padding: EdgeInsets.symmetric(horizontal: PsSpace.xs), child: PsBrandMark(size: 38)),
                    const SizedBox(width: PsSpace.xs),
                    Expanded(
                      child: PsSearchBar(
                        hint: hint,
                        readOnly: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationBadge.instance,
                      builder: (_, unread, __) => PsIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
                        badgeCount: unread,
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
                      ),
                    ),
                    CartIconButton(onPressed: () => ShellNav.goTo(context, BuyerTab.cart)),
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
