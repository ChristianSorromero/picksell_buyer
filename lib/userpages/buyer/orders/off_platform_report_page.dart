import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';

/// "Seller asked you to pay or ship outside PickSell?" (website: order page).
/// PickSell reviews the seller; the seller isn't told who reported.
class OffPlatformReportPage extends StatefulWidget {
  const OffPlatformReportPage({super.key, required this.order});

  final OrderDetail order;

  @override
  State<OffPlatformReportPage> createState() => _OffPlatformReportPageState();
}

class _OffPlatformReportPageState extends State<OffPlatformReportPage> {
  final _details = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_details.text.trim().length < 10) {
      setState(() => _error = 'Tell us what the seller asked (at least 10 characters).');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final message = await OrderService().reportOffPlatform(widget.order.id, details: _details.text.trim());
      if (!mounted) return;
      await PsDialog.info(
        context,
        title: 'Report sent',
        message: message.isNotEmpty ? message : 'PickSell will review this seller.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.fieldError('details');
      });
      // e.g. already reported and still being reviewed.
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t send report', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.order.summary;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Report Seller'),
      footer: PsFooterActions(
        primary: PsPrimaryButton(label: 'Report seller', uppercase: false, loading: _busy, onPressed: _submit),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          PsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gpp_maybe_outlined, color: PsColors.warning),
                    const SizedBox(width: PsSpace.xs),
                    Expanded(child: Text('Stay protected on PickSell', style: PsText.heading.copyWith(fontSize: 16))),
                  ],
                ),
                const SizedBox(height: PsSpace.xs),
                Text(
                  'Payments, chats and couriers outside PickSell aren’t protected. Tell us and we’ll review the seller; they won’t see who reported.',
                  style: PsText.body,
                ),
                const SizedBox(height: PsSpace.sm),
                Text(
                  [if (s.seller != null) s.seller!.name, 'Order ID: ${s.orderNumber}'].join(' · '),
                  style: PsText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          Text('What did the seller ask?', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          TextField(
            controller: _details,
            maxLines: 4,
            maxLength: 2000,
            style: PsText.input,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: psInputDecoration(
              hint: 'e.g. Asked me to pay through GCash and ship with LBC instead.',
              hasError: _error != null,
            ),
          ),
          if (_error != null) PsFieldError(_error!),
        ],
      ),
    );
  }
}
