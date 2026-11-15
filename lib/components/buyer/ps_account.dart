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
    // Always a dark block with Bone White text (raised grey in dark mode).
    final bg = PsColors.isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1B1B1B);
    const onDark = Color(0xFFF9F8F6);
    const onDarkMuted = Color(0xFFA3A3AB);
    return Semantics(
      button: onEdit != null,
      label: '${profile.name}, ${profile.email}. Edit profile',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(PsRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(PsSpace.md + 2),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text(profile.initials, style: PsText.hero.copyWith(fontSize: 22, color: PsColors.onPrimary)),
                ),
                const SizedBox(width: PsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PsText.hero.copyWith(fontSize: 20, color: onDark)),
                      const SizedBox(height: 4),
                      Text(profile.email, style: PsText.caption.copyWith(color: onDarkMuted), overflow: TextOverflow.ellipsis),
                      if (profile.memberSince != null)
                        Text('Member since ${profile.memberSince!.year}', style: PsText.caption.copyWith(fontSize: 11.5, color: onDarkMuted)),
                    ],
                  ),
                ),
                if (onEdit != null)
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(18)),
                    child: Text('Edit', style: PsText.ui.copyWith(fontWeight: FontWeight.w800, color: PsColors.onPrimary)),
                  ),
              ],
            ),
          ),
        ),
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
      trailing: InkWell(
        onTap: onViewAll,
        borderRadius: BorderRadius.circular(PsRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text('View all  ›', style: PsText.ui.copyWith(fontSize: 13)),
        ),
      ),
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
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: PsColors.primarySoft, borderRadius: BorderRadius.circular(16)),
                            child: Icon(icon, size: 24, color: PsColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(tab.label, textAlign: TextAlign.center, style: PsText.ui.copyWith(fontSize: 11.5)),
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
