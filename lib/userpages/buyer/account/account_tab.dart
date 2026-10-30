import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/account.dart';
import '../../../page_transitions.dart';
import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/cart_service.dart';
import '../../../services/wishlist_service.dart';
import '../../landing_page1.dart';
import '../nav.dart';
import '../orders/reorder_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'help_support_page.dart';
import 'my_picks_page.dart';
import 'notifications_page.dart';
import 'recently_viewed_page.dart';

/// Account (BUY-A01…A12): summary, order shortcuts, saved items, delivery
/// address, payment, support and sign-out.
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _account = AccountService();
  final _view = GlobalKey<PsAsyncViewState<AccountOverview>>();

  @override
  void initState() {
    super.initState();
    ShellNav.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    ShellNav.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (ShellNav.tab.value == BuyerTab.account) _view.currentState?.reload();
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _view.currentState?.reload();
  }

  Future<void> _logout() async {
    final ok = await PsDialog.confirm(
      context,
      title: 'Log out?',
      message: 'You’ll need to log in again to shop and track orders.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay',
      icon: Icons.logout_rounded,
    );
    if (!ok) return;
    await AuthService().logout();
    CartStore.instance.reset();
    WishlistStore.instance.clear();
    NotificationBadge.instance.value = 0;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const LandingPage1()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: 'Account',
        showBack: false,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationBadge.instance,
            builder: (_, n, __) => PsIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              badgeCount: n,
              onPressed: () => _push(const NotificationsPage()),
            ),
          ),
        ],
      ),
      body: PsAsyncView<AccountOverview>(
        key: _view,
        load: _account.overview,
        errorTitle: 'Couldn’t load your account',
        builder: (context, a, _) => ListView(
          padding: const EdgeInsets.all(PsSpace.gutter),
          children: [
            PsAccountSummary(profile: a.profile, onEdit: () => _push(EditProfilePage(profile: a.profile))),
            const SizedBox(height: PsSpace.sm),
            PsOrderStatusSummary(
              counts: a.orderCounts,
              onTab: (t) => openOrders(context, initial: t).then((_) => _view.currentState?.reload()),
              onViewAll: () => openOrders(context).then((_) => _view.currentState?.reload()),
            ),
            const SizedBox(height: PsSpace.sm),
            PsCard(
              title: 'Shopping',
              child: Column(
                children: [
                  PsMenuTile(icon: Icons.favorite_border_rounded, label: 'My Picks', subtitle: '${a.wishlistCount} saved', onTap: () => _push(const MyPicksPage())),
                  const Divider(),
                  PsMenuTile(icon: Icons.history_rounded, label: 'Recently Viewed', onTap: () => _push(const RecentlyViewedPage())),
                  const Divider(),
                  PsMenuTile(icon: Icons.replay_rounded, label: 'Buy Again', subtitle: 'Reorder past purchases', onTap: () => _push(const ReorderPage())),
                ],
              ),
            ),
            const SizedBox(height: PsSpace.sm),
            PsCard(
              title: 'Settings',
              child: Column(
                children: [
                  PsMenuTile(
                    icon: Icons.location_on_outlined,
                    label: 'Delivery Address',
                    subtitle: a.deliveryAddress?.complete == true ? a.deliveryAddress!.fullAddress : 'Add your delivery address',
                    onTap: () => _push(EditProfilePage(profile: a.profile, focusAddress: true)),
                  ),
                  const Divider(),
                  PsMenuTile(
                    icon: Icons.payments_outlined,
                    label: 'Payment Method',
                    subtitle: 'Cash on Delivery',
                    trailing: const SizedBox.shrink(),
                    onTap: () => PsToast.show(context, 'PickSell orders are paid in cash when they arrive.'),
                  ),
                  const Divider(),
                  PsMenuTile(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () => _push(EditProfilePage(profile: a.profile))),
                  const Divider(),
                  PsMenuTile(icon: Icons.lock_outline_rounded, label: 'Change Password', onTap: () => _push(const ChangePasswordPage())),
                ],
              ),
            ),
            const SizedBox(height: PsSpace.sm),
            PsCard(
              child: Column(
                children: [
                  PsMenuTile(icon: Icons.support_agent_rounded, label: 'Help & Support', onTap: () => _push(const HelpSupportPage())),
                  const Divider(),
                  PsMenuTile(icon: Icons.logout_rounded, label: 'Log Out', destructive: true, trailing: const SizedBox.shrink(), onTap: _logout),
                ],
              ),
            ),
            const SizedBox(height: PsSpace.lg),
          ],
        ),
      ),
    );
  }
}

