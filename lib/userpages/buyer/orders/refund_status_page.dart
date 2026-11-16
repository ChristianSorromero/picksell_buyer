import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import '../nav.dart';

/// BUY-C12 Refund Status, following the website's return workflow: the
/// seller approves or declines; a declined request goes to PickSell support;
/// once the item is back and inspected, PickSell approves the refund.
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
                      Text(r.isAgreed ? 'REFUND AMOUNT' : 'AMOUNT REQUESTED', style: PsText.overline),
                      Text(formatPesoFixed(r.refundAmount), style: PsText.display.copyWith(fontSize: 32, fontWeight: FontWeight.w700)),
                      if (r.stageLabel != null) Text(r.stageLabel!, style: PsText.bodyStrong.copyWith(color: PsColors.primaryStrong)),
                      const Divider(height: PsSpace.lg),
                      Row(
                        children: [
                          Expanded(child: PsInfoColumn(label: 'REFUND', value: r.refundTo)),
                          Expanded(child: PsInfoColumn(label: 'ORDER ID', value: s.orderNumber)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (r.returnShipment != null) ...[
                  const SizedBox(height: PsSpace.sm),
                  PsCard(
                    title: 'Return shipment',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(r.returnShipment!, style: PsText.body),
                        const SizedBox(height: PsSpace.xs),
                        Text('Print the waybill and stick it on the package so the rider can scan it.', style: PsText.caption),
                        const SizedBox(height: PsSpace.sm),
                        _PrintWaybillButton(orderId: order.id),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: PsSpace.lg),
                Text('Tracking Details', style: PsText.heading),
                const SizedBox(height: PsSpace.md),
                PsRefundTimeline(request: r),
                if (r.sellerNote != null) ...[
                  PsCard(title: 'Note from the seller', child: Text(r.sellerNote!, style: PsText.body)),
                  const SizedBox(height: PsSpace.sm),
                ],
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
                      Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Downloads the Pickrush 4×6 return label and opens the system print / save-as-PDF sheet.
class _PrintWaybillButton extends StatefulWidget {
  const _PrintWaybillButton({required this.orderId});

  final int orderId;

  @override
  State<_PrintWaybillButton> createState() => _PrintWaybillButtonState();
}

class _PrintWaybillButtonState extends State<_PrintWaybillButton> {
  bool _busy = false;

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final pdf = await OrderService().returnWaybill(widget.orderId);
      final name = 'return-waybill-${widget.orderId}.pdf';
      try {
        await Printing.layoutPdf(name: name, format: PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch), onLayout: (_) async => pdf);
      } catch (_) {
        // No print service on this phone: share / save the PDF instead.
        await Printing.sharePdf(bytes: pdf, filename: name);
      }
    } on ApiException catch (e) {
      if (mounted) PsDialog.error(context, title: 'Couldn’t load waybill', message: e.message);
    } catch (e) {
      if (mounted) PsDialog.error(context, title: 'Couldn’t open waybill', message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      PsPrimaryButton(label: 'Print Waybill', uppercase: false, loading: _busy, onPressed: _print);
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
