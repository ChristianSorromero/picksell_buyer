import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/cart.dart';
import '../shared/ps_card.dart';

/// COM-C17 Order Cost Breakdown — subtotal + shipping − discounts + fees
/// = total, exactly as priced by the server.
class PsCostBreakdown extends StatelessWidget {
  const PsCostBreakdown({super.key, required this.totals, this.voucherCode, this.title = 'Payment Details'});

  final CostTotals totals;
  final String? voucherCode;
  final String? title;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {Widget? tag, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [Text(label, style: PsText.bodyMuted), if (tag != null) tag],
                ),
              ),
              const SizedBox(width: PsSpace.xs),
              Text(value, style: PsText.body.copyWith(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        );

    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[Text(title!, style: PsText.heading.copyWith(fontSize: 16)), const SizedBox(height: PsSpace.xs)],
          row('Merchandise Subtotal', formatPesoFixed(totals.merchandiseSubtotal)),
          row('Shipping Subtotal', formatPesoFixed(totals.shippingTotal)),
          if (totals.discountTotal > 0)
            row(
              'Voucher Discount',
              '-${formatPesoFixed(totals.discountTotal)}',
              color: PsColors.primaryStrong,
              tag: voucherCode == null ? null : PsTag(voucherCode!, icon: Icons.done_all_rounded),
            ),
          if (totals.serviceFee > 0) row('Service Fee', formatPesoFixed(totals.serviceFee)),
          const Divider(height: PsSpace.lg),
          Row(
            children: [
              Expanded(child: Text('Total Payment', style: PsText.heading.copyWith(fontSize: 17))),
              Text(formatPesoFixed(totals.total), style: PsText.price.copyWith(fontSize: 19, color: PsColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}
