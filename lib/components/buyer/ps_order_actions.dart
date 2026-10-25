import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/order.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_card.dart';

/// A chevron row inside an action group or account menu.
class PsMenuTile extends StatelessWidget {
  const PsMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? PsColors.error : PsColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PsSpace.xs),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: PsColors.surfaceMuted, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: PsText.bodyStrong.copyWith(color: color)),
                    if (subtitle != null) Text(subtitle!, style: PsText.caption),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: onTap == null ? PsColors.textDisabled : PsColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// BUY-C14 Order Action Group — exactly the actions the backend allows for
/// the order's current state (BUY-C09 cancel, C10 report, C11 return,
/// C13 buy again, rate, track).
class PsOrderActionGroup extends StatelessWidget {
  const PsOrderActionGroup({
    super.key,
    required this.order,
    this.onRate,
    this.onBuyAgain,
    this.onTrack,
    this.onCancel,
    this.onReturn,
    this.onRefundStatus,
    this.onReport,
  });

  final OrderDetail order;
  final VoidCallback? onRate;
  final VoidCallback? onBuyAgain;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final VoidCallback? onReturn;
  final VoidCallback? onRefundStatus;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final a = order.actions;
    final buttons = <Widget>[
      if (a.canRate && onRate != null) PsPrimaryButton(label: 'Rate Product', icon: Icons.star_rounded, uppercase: false, onPressed: onRate),
      if (a.canTrack && onTrack != null && !a.canRate)
        PsPrimaryButton(label: 'Track Order', icon: Icons.local_shipping_outlined, uppercase: false, onPressed: onTrack),
      if (a.canReorder && onBuyAgain != null)
        PsSecondaryButton.outlined(label: 'Buy Again', icon: Icons.refresh_rounded, expand: true, onPressed: onBuyAgain),
    ];
    final rows = <Widget>[
      if (a.canTrack && onTrack != null && a.canRate) PsMenuTile(icon: Icons.local_shipping_outlined, label: 'Shipment history', onTap: onTrack),
      if (order.returnRequest != null && onRefundStatus != null)
        PsMenuTile(icon: Icons.currency_exchange_rounded, label: 'Return / Refund status', onTap: onRefundStatus)
      else if (a.canReturn && onReturn != null)
        PsMenuTile(icon: Icons.inventory_2_outlined, label: 'Return / Refund', onTap: onReturn),
      if (a.canReport && onReport != null) PsMenuTile(icon: Icons.report_problem_outlined, label: 'Report a Problem', onTap: onReport),
      if (a.canCancel && onCancel != null) PsMenuTile(icon: Icons.cancel_outlined, label: 'Cancel Order', destructive: true, onTap: onCancel),
    ];
    if (buttons.isEmpty && rows.isEmpty) return const SizedBox.shrink();

    return PsCard(
      title: 'Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: PsSpace.xs), buttons[i]],
          if (buttons.isNotEmpty && rows.isNotEmpty) const SizedBox(height: PsSpace.sm),
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]],
        ],
      ),
    );
  }
}
