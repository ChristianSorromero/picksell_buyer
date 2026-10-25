import 'package:flutter/material.dart';

import '../../core/status/order_status.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/order.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_status_badge.dart';
import 'ps_order_summary.dart';

/// COM-C20 Order Card — seller, status badge, item, total and the one
/// contextual action for the order's current state.
class PsOrderCard extends StatelessWidget {
  const PsOrderCard({super.key, required this.order, required this.onTap, this.onTrack, this.onRate, this.onBuyAgain});

  final OrderSummaryItem order;
  final VoidCallback onTap;
  final VoidCallback? onTrack;
  final VoidCallback? onRate;
  final VoidCallback? onBuyAgain;

  Widget? _action() {
    switch (order.status) {
      case OrderStatus.delivered:
        return onRate == null ? null : PsSecondaryButton.outlined(label: 'Rate', onPressed: onRate);
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.returned:
        return onBuyAgain == null ? null : PsSecondaryButton.outlined(label: 'Buy Again', onPressed: onBuyAgain);
      default:
        return onTrack == null
            ? null
            : PsPrimaryButton(label: 'Track Order', uppercase: false, expand: false, height: 44, onPressed: onTrack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _action();
    return GestureDetector(
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
        footer: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNumber, style: PsText.caption),
                  const SizedBox(height: 2),
                  Text('TOTAL AMOUNT', style: PsText.overline.copyWith(fontSize: 11)),
                  Text(formatPesoFixed(order.total), style: PsText.price),
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}
