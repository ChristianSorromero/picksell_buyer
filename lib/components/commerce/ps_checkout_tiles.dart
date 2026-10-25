import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/cart.dart';
import '../../models/catalog.dart';
import '../shared/ps_card.dart';

/// COM-C15 Shipping Option — method, delivery window and fee.
class PsShippingOptionTile extends StatelessWidget {
  const PsShippingOptionTile({super.key, required this.option, required this.selected, required this.onTap, this.parcels = 1});

  final ShippingOption option;
  final bool selected;
  final VoidCallback onTap;

  /// Number of seller parcels the fee applies to.
  final int parcels;

  @override
  Widget build(BuildContext context) {
    return PsSelectableCard(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(option.name, style: PsText.bodyStrong.copyWith(fontSize: 15))),
              if (option.official) ...[
                const SizedBox(width: 8),
                const PsTag('OFFICIAL', icon: Icons.verified_outlined),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text('Get it by ${formatDateRange(option.estimatedFrom, option.estimatedTo)}', style: PsText.caption),
          const SizedBox(height: 8),
          Text(
            parcels > 1 ? '${formatPesoFixed(option.fee)} × $parcels parcels' : formatPesoFixed(option.fee),
            style: PsText.price,
          ),
        ],
      ),
    );
  }
}

/// COM-C16 Payment Method — unavailable methods are shown but disabled.
class PsPaymentMethodTile extends StatelessWidget {
  const PsPaymentMethodTile({super.key, required this.method, required this.selected, required this.onTap});

  final PaymentMethodOption method;
  final bool selected;
  final VoidCallback onTap;

  static IconData iconFor(String code) => switch (code) {
        'cod' => Icons.payments_outlined,
        'gcash' || 'maya' => Icons.account_balance_wallet_outlined,
        'card' => Icons.credit_card_rounded,
        _ => Icons.account_balance_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return PsSelectableCard(
      selected: selected,
      enabled: method.available,
      onTap: onTap,
      child: Row(
        children: [
          Icon(iconFor(method.code), color: method.available ? PsColors.textPrimary : PsColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(method.name, style: PsText.bodyStrong.copyWith(fontSize: 15)),
                    if (!method.available) const PsTag.muted('Coming Soon'),
                    if (method.available && method.code == 'cod') const PsTag('RECOMMENDED', icon: Icons.done_all_rounded),
                  ],
                ),
                const SizedBox(height: 2),
                Text(method.description, style: PsText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
