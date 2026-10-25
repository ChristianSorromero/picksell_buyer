import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../nav.dart';

/// SYS-C11-style success screen after checkout.
class OrderPlacedPage extends StatelessWidget {
  const OrderPlacedPage({super.key, required this.result});

  final PlacedCheckout result;

  @override
  Widget build(BuildContext context) {
    final orders = result.orders;
    return PsAppShell(
      topBar: const PsTopBar.brand(showBack: false),
      footer: PsFooterActions(
        primary: PsPrimaryButton(
          label: 'View my orders',
          uppercase: false,
          onPressed: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            openOrders(context, initial: OrderTab.toShip);
          },
        ),
        secondary: PsSecondaryButton(label: 'Continue shopping', expand: true, onPressed: () => ShellNav.goTo(context, BuyerTab.home)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          const SizedBox(height: PsSpace.lg),
          PsStateLayout(
            icon: Icons.check_circle_rounded,
            iconColor: PsColors.success,
            haloColor: PsColors.successSoft,
            title: 'Order placed!',
            message: '${result.message}\nTotal: ${formatPesoFixed(result.total)} · Cash on Delivery',
          ),
          const SizedBox(height: PsSpace.lg),
          Text(orders.length == 1 ? 'YOUR ORDER' : 'YOUR ORDERS (${orders.length} PARCELS)', style: PsText.overline),
          const SizedBox(height: PsSpace.xs),
          for (final o in orders) ...[
            PsCard(
              onTap: () => openOrder(context, o.id),
              child: Row(
                children: [
                  PsThumbnail(url: o.image, size: 52),
                  const SizedBox(width: PsSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.productName, style: PsText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${o.orderNumber} · ${o.seller?.name ?? ''}', style: PsText.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: PsSpace.xs),
          ],
        ],
      ),
    );
  }
}
