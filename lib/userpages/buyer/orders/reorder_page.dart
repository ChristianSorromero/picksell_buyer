import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../nav.dart';

/// BUY-C13 Reorder — recently ordered items with current price and stock.
class ReorderPage extends StatefulWidget {
  const ReorderPage({super.key});

  @override
  State<ReorderPage> createState() => _ReorderPageState();
}

class _ReorderPageState extends State<ReorderPage> {
  final _orders = OrderService();
  final Set<int> _selected = {};
  bool _busy = false;

  Future<void> _addSelected(List<ReorderItem> items) async {
    setState(() => _busy = true);
    var added = 0;
    String? failure;
    for (final item in items.where((i) => _selected.contains(i.orderId))) {
      try {
        await _orders.reorder(item.orderId);
        added++;
      } catch (e) {
        failure = errorMessage(e);
      }
    }
    CartStore.instance.refreshCount();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    if (added > 0) {
      PsToast.show(context, '$added ${added == 1 ? 'item' : 'items'} added to cart', type: PsToastType.success, actionLabel: 'View Cart', onAction: () => ShellNav.goTo(context, BuyerTab.cart));
    }
    if (failure != null) PsToast.error(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    return PsAsyncView<List<ReorderItem>>(
      load: _orders.reorderCandidates,
      loading: const Scaffold(backgroundColor: PsColors.background, body: PsSkeletonList()),
      isEmpty: (l) => l.isEmpty,
      empty: const Scaffold(
        backgroundColor: PsColors.background,
        appBar: PsTopBar(title: 'Buy Again'),
        body: PsEmptyState(icon: Icons.replay_rounded, title: 'Nothing to reorder yet', message: 'Items from your past orders appear here.'),
      ),
      refreshable: false,
      builder: (context, items, _) {
        final total = items.where((i) => _selected.contains(i.orderId)).fold<double>(0, (s, i) => s + (i.currentPrice ?? 0));
        return PsAppShell(
          topBar: const PsTopBar(title: 'Buy Again'),
          footer: PsFooterActions(
            primary: PsPrimaryButton(
              label: 'Add selected to cart',
              loading: _busy,
              onPressed: _selected.isEmpty ? null : () => _addSelected(items),
            ),
            secondary: Row(
              children: [
                Text('${_selected.length} selected', style: PsText.bodyMuted),
                const Spacer(),
                Text(formatPesoFixed(total), style: PsText.price),
              ],
            ),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(PsSpace.gutter),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
            itemBuilder: (_, i) {
              if (i == 0) return Text('RECENTLY ORDERED', style: PsText.overline);
              final item = items[i - 1];
              return PsCard(
                padding: const EdgeInsets.fromLTRB(0, PsSpace.sm, PsSpace.sm, PsSpace.sm),
                child: Opacity(
                  opacity: item.available ? 1 : 0.6,
                  child: Row(
                    children: [
                      PsCheck(
                        value: _selected.contains(item.orderId),
                        label: 'Select ${item.productName}',
                        onChanged: item.available ? (v) => setState(() => v ? _selected.add(item.orderId) : _selected.remove(item.orderId)) : null,
                      ),
                      PsThumbnail(url: item.product?.image, size: 72),
                      const SizedBox(width: PsSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName, style: PsText.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (item.sellerName != null) Text(item.sellerName!, style: PsText.caption),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(formatPesoFixed(item.currentPrice ?? item.lastPrice), style: PsText.bodyStrong),
                                const SizedBox(width: 6),
                                if (!item.available)
                                  const PsTag.muted('OUT OF STOCK')
                                else if (item.priceChanged)
                                  const PsTag('PRICE UPDATED', color: PsColors.info, background: PsColors.infoSoft),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (item.available)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  await buyAgainSilently(context, item.orderId);
                                  if (mounted) setState(() => _busy = false);
                                },
                          child: const Text('Reorder'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Future<void> buyAgainSilently(BuildContext context, int orderId) async {
  try {
    final r = await OrderService().reorder(orderId);
    CartStore.instance.refreshCount();
    if (context.mounted) PsToast.show(context, r.message, type: PsToastType.success, actionLabel: 'View Cart', onAction: () => ShellNav.goTo(context, BuyerTab.cart));
  } catch (e) {
    if (context.mounted) PsToast.error(context, errorMessage(e));
  }
}
