import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/network/api_client.dart';
import '../../page_transitions.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/wishlist_service.dart';
import '../chats_page.dart';
import '../login.dart';
import 'account/account_tab.dart';
import 'cart/cart_tab.dart';
import 'nav.dart';
import 'shop/home_tab.dart';
import 'shop/product_list_page.dart';

/// SYS-C01 App Shell for the signed-in buyer: five persistent tabs with
/// their own state, a cart badge, and a session-expiry guard.
class BuyerDashboardPage extends StatefulWidget {
  const BuyerDashboardPage({super.key, this.initialTab = BuyerTab.home});

  final BuyerTab initialTab;

  @override
  State<BuyerDashboardPage> createState() => _BuyerDashboardPageState();
}

class _BuyerDashboardPageState extends State<BuyerDashboardPage> {
  final Set<BuyerTab> _visited = {};

  @override
  void initState() {
    super.initState();
    ShellNav.tab.value = widget.initialTab;
    _visited.add(widget.initialTab);
    ShellNav.tab.addListener(_onTab);
    ApiClient.sessionExpired.addListener(_onSessionExpired);

    CartStore.instance.refreshCount();
    WishlistStore.instance.load().catchError((_) => <Never>[]);
    AccountService().notifications().catchError((_) => const <Never>[]);
  }

  @override
  void dispose() {
    ShellNav.tab.removeListener(_onTab);
    ApiClient.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _onTab() => setState(() => _visited.add(ShellNav.tab.value));

  Future<void> _onSessionExpired() async {
    await SessionManager().clear();
    CartStore.instance.reset();
    WishlistStore.instance.clear();
    if (!mounted) return;
    PsToast.show(context, 'Your session has expired. Please log in again.');
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const LoginPage()), (_) => false);
  }

  Widget _page(BuyerTab tab) => switch (tab) {
        BuyerTab.home => const HomeTab(),
        BuyerTab.discover => const ProductListPage(embedded: true, title: 'Discover'),
        BuyerTab.cart => const CartTab(),
        BuyerTab.messages => const ChatsPage(),
        BuyerTab.account => const AccountTab(),
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BuyerTab>(
      valueListenable: ShellNav.tab,
      builder: (context, current, _) => PopScope(
        canPop: current == BuyerTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) ShellNav.tab.value = BuyerTab.home;
        },
        child: Scaffold(
          backgroundColor: PsColors.background,
          body: IndexedStack(
            index: current.index,
            children: [
              // Tabs are built on first visit, then kept alive.
              for (final tab in BuyerTab.values) _visited.contains(tab) ? _page(tab) : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: CartStore.instance,
            builder: (_, __) => PsBottomNav(
              current: current,
              badges: {BuyerTab.cart: CartStore.instance.count},
              onSelected: (tab) => ShellNav.tab.value = tab,
            ),
          ),
        ),
      ),
    );
  }
}
