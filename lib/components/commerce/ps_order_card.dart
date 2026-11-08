import 'package:flutter/material.dart';

import '../../core/status/order_status.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/order.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_status_badge.dart';
import 'ps_order_summary.dart';

/// COM-C20 Order Card — seller, status badge, item, total and the contextual
/// actions for the order's current state.
class PsOrderCard extends StatelessWidget {
  const PsOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onTrack,
    this.onRate,
    this.onReceived,
    this.onBuyAgain,
  });

  final OrderSummaryItem order;
  final VoidCallback onTap;
  final VoidCallback? onTrack;
  final VoidCallback? onRate;
  final VoidCallback? onReceived;
  final VoidCallback? onBuyAgain;

  List<Widget> _actions() {
    // The API puts an order in "To Rate" exactly when it can still be rated (completed after
    // "Order Received", no rating yet — the same rule as the rate endpoint), so the card follows it.
    final canRate = order.tab == OrderTab.toRate;
    final ended = switch (order.status) {
      OrderStatus.completed ||
      OrderStatus.cancelled ||
      OrderStatus.returned => true,
      _ => false,
    };
    final inProgress = !ended && order.status != OrderStatus.delivered;

    return [
      if (order.status == OrderStatus.delivered && onReceived != null)
        PsPrimaryButton(label: 'Order Received', uppercase: false, expand: false, height: 44, onPressed: onReceived),
      if (canRate && onRate != null)
        PsSecondaryButton.outlined(label: 'Rate Order', onPressed: onRate),
      if (ended && onBuyAgain != null)
        PsSecondaryButton.outlined(label: 'Buy Again', onPressed: onBuyAgain),
      if (inProgress && onTrack != null)
        PsPrimaryButton(
          label: 'Track Order',
          uppercase: false,
          expand: false,
          height: 44,
          onPressed: onTrack,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions();
    final totals = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(order.orderNumber, style: PsText.caption),
        const SizedBox(height: 2),
        Text('TOTAL AMOUNT', style: PsText.overline.copyWith(fontSize: 11)),
        Text(formatPesoFixed(order.total), style: PsText.price),
      ],
    );
    return Semantics(
      button: true,
      label:
          '${order.productName}, ${order.status.buyerLabel}, ${formatPesoFixed(order.total)}',
      child: GestureDetector(
        onTap: onTap,
        child: PsOrderSummary(
          sellerName: order.seller?.name ?? 'Picksell seller',
          verified: order.seller?.verified ?? false,
          headerTrailing: PsStatusBadge.order(order.status),
          lines: [
            PsOrderLineRow(
              name: order.productName,
              image: order.image,
              quantity: order.quantity,
              unitPrice: order.unitPrice,
              variationLabel: order.variationLabel,
              onTap: onTap,
            ),
          ],
          // One action sits beside the total; two get their own row so neither is squeezed.
          footer: actions.length < 2
              ? Row(
                  children: [
                    Expanded(child: totals),
                    ...actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    totals,
                    const SizedBox(height: PsSpace.sm),
                    Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: PsSpace.xs),
                          Expanded(child: actions[i]),
                        ],
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
