import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../nav.dart';

/// BUY-C12 Refund Status.
class RefundStatusPage extends StatelessWidget {
  const RefundStatusPage({super.key, required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final r = order.returnRequest;
    final s = order.summary;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Refund Status'),
      body: r == null
          ? const PsEmptyState(icon: Icons.currency_exchange_rounded, title: 'No return requested', message: 'This order has no return or refund request.')
          : ListView(
              padding: const EdgeInsets.all(PsSpace.gutter),
              children: [
                PsCard(
                  padding: const EdgeInsets.all(PsSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REFUND AMOUNT', style: PsText.overline),
                      Text(formatPesoFixed(r.refundAmount), style: PsText.display.copyWith(fontSize: 32, fontWeight: FontWeight.w700)),
                      const Divider(height: PsSpace.lg),
                      Row(
                        children: [
                          Expanded(child: PsInfoColumn(label: 'REFUND TO', value: r.refundTo)),
                          Expanded(child: PsInfoColumn(label: 'ORDER ID', value: s.orderNumber)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PsSpace.lg),
                Text('Tracking Details', style: PsText.heading),
                const SizedBox(height: PsSpace.md),
                PsRefundTimeline(request: r),
                if (r.resolutionNote != null) ...[
                  PsCard(title: 'Note from support', child: Text(r.resolutionNote!, style: PsText.body)),
                  const SizedBox(height: PsSpace.sm),
                ],
                PsCard(
                  title: 'Return details',
                  child: Column(
                    children: [
                      PsInfoRow(label: 'Reason', value: r.reason),
                      PsInfoRow(label: 'Quantity', value: '${r.quantity}'),
                      if (r.details != null) PsInfoRow(label: 'Details', value: r.details!),
                    ],
                  ),
                ),
                const SizedBox(height: PsSpace.sm),
                PsCard(
                  onTap: s.productId == null ? null : () => openProduct(context, s.productId!),
                  child: Row(
                    children: [
                      PsThumbnail(url: s.image, size: 60),
                      const SizedBox(width: PsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.productName, style: PsText.bodyStrong),
                            if (s.seller != null) Text('Sold by ${s.seller!.name}', style: PsText.caption.copyWith(color: PsColors.primaryStrong)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Stacked "LABEL / value" pair.
class PsInfoColumn extends StatelessWidget {
  const PsInfoColumn({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label, style: PsText.overline.copyWith(fontSize: 11)), Text(value, style: PsText.bodyStrong)],
      );
}
