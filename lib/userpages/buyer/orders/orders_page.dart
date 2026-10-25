import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import '../nav.dart';
import 'order_actions.dart';

/// My Orders (COM-C20 + SYS-C19): status tabs with counts, order cards
/// with the contextual action for each state.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, this.initial = OrderTab.all});

  final OrderTab initial;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _orders = OrderService();
  late OrderTab _tab = widget.initial;
  Map<OrderTab, int> _counts = {};
  Key _key = UniqueKey();

  Future<List<OrderSummaryItem>> _load() async {
    final list = await _orders.list(tab: _tab);
    if (mounted) setState(() => _counts = list.counts);
    return list.orders;
  }

  void _refresh() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: 'My Orders',
        bottom: PsSegmentedControl<OrderTab>(
          selected: _tab,
          onChanged: (t) => setState(() {
            _tab = t;
            _key = UniqueKey();
          }),
          segments: [
            for (final t in OrderTab.values)
              PsSegment(t, t.label, count: t == OrderTab.all || (_counts[t] ?? 0) == 0 ? null : _counts[t]),
          ],
        ),
      ),
      body: PsAsyncView<List<OrderSummaryItem>>(
        key: _key,
        load: _load,
        isEmpty: (l) => l.isEmpty,
        empty: PsEmptyState(
          icon: Icons.receipt_long_outlined,
          title: _tab == OrderTab.all ? 'No orders yet' : 'No orders in “${_tab.label}”',
          message: _tab == OrderTab.all ? 'When you place an order, you can track it here.' : null,
          actionLabel: _tab == OrderTab.all ? 'Start shopping' : null,
          onAction: _tab == OrderTab.all ? () => ShellNav.goTo(context, BuyerTab.home) : null,
        ),
        builder: (context, orders, reload) => ListView.separated(
          padding: const EdgeInsets.all(PsSpace.gutter),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
          itemBuilder: (_, i) {
            final o = orders[i];
            Future<void> afterward(Future<void> f) async {
              await f;
              _refresh();
            }

            return PsOrderCard(
              order: o,
              onTap: () => afterward(openOrder(context, o.id)),
              onTrack: () => afterward(openTracking(context, o.id)),
              onRate: () => afterward(rateOrder(context, o.id, o.productName)),
              onBuyAgain: () => buyAgain(context, o.id),
            );
          },
        ),
      ),
    );
  }
}
