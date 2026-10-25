import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'evidence_picker.dart';
import 'refund_status_page.dart';

/// BUY-C11 Request Return — quantity, reason, refund destination, details
/// and photos. Eligibility (window, once per order) is enforced server-side.
class ReturnRequestPage extends StatefulWidget {
  const ReturnRequestPage({super.key, required this.order});

  final OrderDetail order;

  @override
  State<ReturnRequestPage> createState() => _ReturnRequestPageState();
}

class _ReturnRequestPageState extends State<ReturnRequestPage> {
  final _orders = OrderService();
  final _details = TextEditingController();
  late int _quantity = widget.order.summary.quantity;
  String? _reason;
  String _refundTo = 'gcash';
  List<String> _photos = [];
  final Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errors.clear();
      if (_reason == null) _errors['reason'] = 'Select a reason for the return.';
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await _orders.requestReturn(
        widget.order.id,
        quantity: _quantity,
        reason: _reason!,
        refundTo: _refundTo,
        details: _details.text,
        photos: _photos,
      );
      final fresh = await _orders.detail(widget.order.id);
      if (!mounted) return;
      PsToast.success(context, 'Return request submitted');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RefundStatusPage(order: fresh)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        final m = e.fieldError('reason') ?? e.fieldError('quantity');
        if (m != null) _errors['reason'] = m;
      });
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t submit return', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.order.summary;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Request Return'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Submit Return Request', uppercase: false, loading: _busy, onPressed: _submit)),
      body: PsAsyncView<OrderOptions>(
        load: _orders.options,
        refreshable: false,
        builder: (context, options, _) => ListView(
          padding: const EdgeInsets.all(PsSpace.gutter),
          children: [
            PsCard(
              child: Row(
                children: [
                  PsThumbnail(url: s.image, size: 72),
                  const SizedBox(width: PsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.productName, style: PsText.bodyStrong),
                        if (s.seller != null) Text('Seller: ${s.seller!.name}', style: PsText.caption),
                        Text(formatPesoFixed(s.unitPrice), style: PsText.price),
                      ],
                    ),
                  ),
                  if (s.quantity > 1)
                    PsQuantityStepper(compact: true, value: _quantity, max: s.quantity, onChanged: (q) => setState(() => _quantity = q)),
                ],
              ),
            ),
            const SizedBox(height: PsSpace.lg),
            const PsFieldLabel('Reason for Return'),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              items: [for (final r in options.returnReasons) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (r) => setState(() {
                _reason = r;
                _errors.remove('reason');
              }),
              style: PsText.input,
              decoration: psInputDecoration(hint: 'Select a reason', hasError: _errors['reason'] != null),
            ),
            if (_errors['reason'] != null) PsFieldError(_errors['reason']!),
            const SizedBox(height: PsSpace.md),
            const PsFieldLabel('Refund to'),
            Wrap(
              spacing: PsSpace.xs,
              runSpacing: PsSpace.xs,
              children: [
                for (final (code, name) in options.refundMethods)
                  PsOptionChip(label: name, selected: _refundTo == code, onTap: () => setState(() => _refundTo = code)),
              ],
            ),
            const SizedBox(height: PsSpace.md),
            const PsFieldLabel('Additional Details'),
            TextField(
              controller: _details,
              maxLines: 4,
              maxLength: 2000,
              style: PsText.input,
              decoration: psInputDecoration(hint: 'Explain the issue with the item…'),
            ),
            const SizedBox(height: PsSpace.xs),
            const PsFieldLabel('Upload Photos'),
            EvidencePicker(paths: _photos, max: 4, onChanged: (p) => setState(() => _photos = p)),
            const SizedBox(height: PsSpace.md),
            Text(
              'Returns can be requested within ${options.returnWindowDays} days of receiving the order. '
              'Please keep the item in its original packaging with all accessories.',
              style: PsText.caption,
            ),
          ],
        ),
      ),
    );
  }
}
