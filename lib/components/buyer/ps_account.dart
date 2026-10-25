import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/account.dart';
import '../../models/order.dart';
import '../shared/ps_card.dart';

/// BUY-A01 Account Summary.
class PsAccountSummary extends StatelessWidget {
  const PsAccountSummary({super.key, required this.profile, this.onEdit});

  final BuyerProfile profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      onTap: onEdit,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: PsColors.primary,
            child: Text(profile.initials, style: PsText.heading.copyWith(color: PsColors.onPrimary)),
          ),
          const SizedBox(width: PsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: PsText.heading),
                Text(profile.email, style: PsText.caption, overflow: TextOverflow.ellipsis),
                if (profile.memberSince != null)
                  Text('Member since ${profile.memberSince!.year}', style: PsText.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          if (onEdit != null) const Icon(Icons.edit_outlined, color: PsColors.textMuted),
        ],
      ),
    );
  }
}

/// BUY-A02 Order Status Summary — one tap into each active order group.
class PsOrderStatusSummary extends StatelessWidget {
  const PsOrderStatusSummary({super.key, required this.counts, required this.onTab, required this.onViewAll});

  final Map<OrderTab, int> counts;
  final ValueChanged<OrderTab> onTab;
  final VoidCallback onViewAll;

  static const _items = [
    (OrderTab.toShip, Icons.inventory_2_outlined),
    (OrderTab.inTransit, Icons.local_shipping_outlined),
    (OrderTab.outForDelivery, Icons.two_wheeler_rounded),
    (OrderTab.toRate, Icons.star_border_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return PsCard(
      title: 'My Orders',
      trailing: InkWell(onTap: onViewAll, child: Text('View all', style: PsText.link.copyWith(fontSize: 13))),
      child: Row(
        children: [
          for (final (tab, icon) in _items)
            Expanded(
              child: Semantics(
                button: true,
                label: '${tab.label}, ${counts[tab] ?? 0} orders',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTab(tab),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: PsSpace.xs),
                    child: Column(
                      children: [
                        Badge(
                          isLabelVisible: (counts[tab] ?? 0) > 0,
                          backgroundColor: PsColors.primary,
                          textColor: PsColors.onPrimary,
                          label: Text('${counts[tab] ?? 0}'),
                          child: Icon(icon, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(tab.label, textAlign: TextAlign.center, style: PsText.caption.copyWith(fontSize: 11.5, color: PsColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
