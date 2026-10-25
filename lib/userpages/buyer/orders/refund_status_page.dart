import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import '../nav.dart';

/// BUY-C12 Refund Status. Picksell reviews a return first, then the seller
/// proposes a resolution; the buyer answers questions and accepts or
/// declines (declining sends it to Picksell for a final decision).
class RefundStatusPage extends StatefulWidget {
  const RefundStatusPage({super.key, required this.order});

  final OrderDetail order;

  @override
  State<RefundStatusPage> createState() => _RefundStatusPageState();
}

class _RefundStatusPageState extends State<RefundStatusPage> {
  final _orders = OrderService();
  final _text = TextEditingController();
  late ReturnRequest? _request = widget.order.returnRequest;
  bool _busy = false;
  bool _declining = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ReturnRequest> Function() call, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await call();
      if (!mounted) return;
      setState(() {
        _request = updated;
        _busy = false;
        _declining = false;
        _text.clear();
      });
      PsToast.success(context, success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorMessage(e);
      });
    }
  }

  void _needsText(String message, VoidCallback then) {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = message);
      return;
    }
    then();
  }

  Widget _actionCard(ReturnRequest r) {
    final error = _error == null ? null : PsFieldError(_error!);
    final field = TextField(
      controller: _text,
      maxLines: 3,
      maxLength: 1000,
      style: PsText.input,
      decoration: psInputDecoration(hint: r.awaiting == 'reply' ? 'Your answer…' : 'Why don’t you accept this?'),
    );

    if (r.awaiting == 'reply') {
      return PsCard(
        title: 'Picksell needs more information',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (r.infoRequest != null) Text(r.infoRequest!, style: PsText.body),
            const SizedBox(height: PsSpace.sm),
            field,
            ?error,
            PsPrimaryButton(
              label: 'Send reply',
              loading: _busy,
              onPressed: _busy
                  ? null
                  : () => _needsText('Write your answer first.', () => _run(() => _orders.replyToReturn(r.id, details: _text.text), 'Reply sent')),
            ),
          ],
        ),
      );
    }

    final p = r.proposal!;
    return PsCard(
      title: 'Seller’s proposal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.label, style: PsText.bodyStrong),
          if (p.amount > 0) Text('${formatPesoFixed(p.amount)} refunded to you in cash by a Picksell rider', style: PsText.body),
          if (p.itemMustReturn) Text('The item goes back to the seller.', style: PsText.caption),
          if (p.note != null) ...[const SizedBox(height: PsSpace.xs), Text('“${p.note}”', style: PsText.body)],
          const SizedBox(height: PsSpace.md),
          if (_declining) ...[field, ?error],
          PsPrimaryButton(
            label: _declining ? 'Send to Picksell' : 'Accept',
            loading: _busy,
            onPressed: _busy
                ? null
                : _declining
                    ? () => _needsText('Tell us why you don’t accept.',
                        () => _run(() => _orders.declineReturnProposal(r.id, reason: _text.text), 'Sent to Picksell for a decision'))
                    : () => _run(() => _orders.acceptReturnProposal(r.id), 'Resolution accepted'),
          ),
          PsSecondaryButton(
            label: _declining ? 'Back' : 'Decline',
            onPressed: _busy ? null : () => setState(() {
              _declining = !_declining;
              _error = null;
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    final s = widget.order.summary;
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
                          Expanded(child: PsInfoColumn(label: 'REFUND TO', value: r.refundTo)),
                          Expanded(child: PsInfoColumn(label: 'ORDER ID', value: s.orderNumber)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (r.awaiting == 'reply' || (r.awaiting == 'decide' && r.proposal != null)) ...[
                  const SizedBox(height: PsSpace.md),
                  _actionCard(r),
                ],
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
