import 'package:flutter/material.dart';

import '../../core/status/order_status.dart';
import '../../core/theme/ps_typography.dart';

/// SYS-C05 Status Badge — the current state of an order, delivery,
/// account or process. Use [PsStatusBadge.order] for anything driven by
/// the canonical [OrderStatus] so wording stays consistent.
class PsStatusBadge extends StatelessWidget {
  const PsStatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.pill = false,
  });

  PsStatusBadge.order(OrderStatus status, {Key? key, bool pill = false})
      : this(key: key, label: status.buyerLabel, tone: status.tone, pill: pill);

  final String label;
  final StatusTone tone;

  /// Rounded pill (detail headers) vs. squared tag (list cards).
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: pill ? 12 : 8, vertical: pill ? 5 : 6),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(pill ? 999 : 4),
          border: Border.all(color: tone.foreground.withAlpha(60)),
        ),
        child: Text(label.toUpperCase(), style: PsText.badge.copyWith(color: tone.foreground)),
      ),
    );
  }
}
