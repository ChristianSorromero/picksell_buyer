import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'evidence_picker.dart';
import 'refund_status_page.dart';

/// BUY-C11 Request Return — quantity, reason, details, photos and the GCash account for the
/// refund, as on the website. Eligibility (delivered, not yet received, within the return
/// window, once per order, seller-fault reasons only) is enforced server-side.
class ReturnRequestPage extends StatefulWidget {
  const ReturnRequestPage({super.key, required this.order});

  final OrderDetail order;

  @override
  State<ReturnRequestPage> createState() => _ReturnRequestPageState();
}

class _ReturnRequestPageState extends State<ReturnRequestPage> {
  final _orders = OrderService();
  final _details = TextEditingController();
  final _gcashNumber = TextEditingController();
  final _gcashName = TextEditingController();
  late int _quantity = widget.order.summary.quantity;
  String? _reason;
  List<String> _photos = [];
  final Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    _gcashNumber.dispose();
    _gcashName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errors.clear();
      if (_reason == null) _errors['reason'] = 'Select a reason for the return.';
      if (_details.text.trim().isEmpty) _errors['details'] = 'Describe the problem with the item.';
      if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(_gcashNumber.text.trim())) {
        _errors['gcash_number'] = 'Enter your GCash mobile number, e.g. 09171234567.';
      }
      if (_gcashName.text.trim().isEmpty) _errors['gcash_name'] = 'Enter the name on your GCash account.';
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await _orders.requestReturn(
        widget.order.id,
        quantity: _quantity,
        reason: _reason!,
        details: _details.text,
        gcashNumber: _gcashNumber.text,
        gcashName: _gcashName.text,
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
        final d = e.fieldError('details');
        if (d != null) _errors['details'] = d;
        for (final f in ['gcash_number', 'gcash_name']) {
          final g = e.fieldError(f);
          if (g != null) _errors[f] = g;
        }
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
            const PsFieldLabel('What’s wrong with the item?'),
            TextField(
              controller: _details,
              maxLines: 4,
              maxLength: 2000,
              style: PsText.input,
              decoration: psInputDecoration(hint: 'Explain the issue with the item…', hasError: _errors['details'] != null),
            ),
            if (_errors['details'] != null) PsFieldError(_errors['details']!),
            const SizedBox(height: PsSpace.xs),
            const PsFieldLabel('Upload Photos'),
            EvidencePicker(paths: _photos, max: 5, onChanged: (p) => setState(() => _photos = p)),
            const SizedBox(height: PsSpace.md),
            const PsFieldLabel('GCash Number for Your Refund'),
            TextField(
              controller: _gcashNumber,
              keyboardType: TextInputType.phone,
              style: PsText.input,
              decoration: psInputDecoration(hint: '09XXXXXXXXX', hasError: _errors['gcash_number'] != null),
            ),
            if (_errors['gcash_number'] != null) PsFieldError(_errors['gcash_number']!),
            const SizedBox(height: PsSpace.md),
            const PsFieldLabel('GCash Account Name'),
            TextField(
              controller: _gcashName,
              textCapitalization: TextCapitalization.words,
              style: PsText.input,
              decoration: psInputDecoration(hint: 'Name on your GCash account', hasError: _errors['gcash_name'] != null),
            ),
            if (_errors['gcash_name'] != null) PsFieldError(_errors['gcash_name']!),
            const SizedBox(height: PsSpace.md),
            Text(
              'Only problems with the item itself can be returned; for anything else, contact Support. '
              'The seller reviews your request first (PickSell decides if they decline). If approved, a Pickrush rider '
              'picks the item up from you. After the seller checks it, PickSell sends your refund to this GCash. '
              'Keep the item in its original packaging with all accessories.',
              style: PsText.caption,
            ),
          ],
        ),
      ),
    );
  }
}
