import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'evidence_picker.dart';

/// "Problem with the delivery?" (website: tracking page). Goes to the
/// logistics company carrying the parcel as a logistics issue that PickSell
/// follows up — unlike Report a Problem, which is about the item or seller.
class DeliveryProblemPage extends StatefulWidget {
  const DeliveryProblemPage({super.key, required this.order});

  final OrderDetail order;

  @override
  State<DeliveryProblemPage> createState() => _DeliveryProblemPageState();
}

class _DeliveryProblemPageState extends State<DeliveryProblemPage> {
  final _orders = OrderService();
  final _description = TextEditingController();

  /// The website's buyer options; replaced by the server's list when it loads.
  List<(String, String)> _types = const [
    ('not_received', 'Marked delivered but not received'),
    ('damaged_item', 'Item arrived damaged'),
    ('late', 'Delivery very late'),
    ('rider_conduct', 'Rider conduct'),
    ('other', 'Other'),
  ];
  String? _type;
  List<String> _photos = [];
  final Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _orders
        .options()
        .then((o) {
          if (mounted && o.deliveryProblemTypes.isNotEmpty) setState(() => _types = o.deliveryProblemTypes);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errors.clear();
      if (_type == null) _errors['type'] = 'Choose what went wrong.';
      if (_description.text.trim().length < 10) {
        _errors['description'] = 'Describe what happened (at least 10 characters).';
      }
    });
    if (_errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      final message = await _orders.reportDeliveryProblem(
        widget.order.id,
        type: _type!,
        description: _description.text.trim(),
        photo: _photos.firstOrNull,
      );
      if (!mounted) return;
      await PsDialog.info(
        context,
        title: 'Report sent',
        message: message.isNotEmpty ? message : 'PickSell will follow it up with the logistics company.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        for (final f in ['type', 'description']) {
          final m = e.fieldError(f);
          if (m != null) _errors[f] = m;
        }
      });
      // e.g. already reported and still open, or no logistics company yet.
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t send report', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final s = o.summary;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Delivery Problem'),
      footer: PsFooterActions(
        primary: PsPrimaryButton(label: 'Send Report', uppercase: false, loading: _busy, onPressed: _submit),
      ),
      body: ListView(
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
                      Text('Order ID: ${s.orderNumber}', style: PsText.caption),
                      if (o.logisticsName != null) Text('Courier: ${o.logisticsName}', style: PsText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.sm),
          Text(
            'This goes to the logistics company carrying your parcel. For a wrong or faulty item, use Report a Problem instead.',
            style: PsText.caption,
          ),
          const SizedBox(height: PsSpace.lg),
          Text('What went wrong?', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          for (final (value, label) in _types) ...[
            PsSelectableCard(
              selected: _type == value,
              onTap: () => setState(() {
                _type = value;
                _errors.remove('type');
              }),
              child: Text(label, style: PsText.bodyStrong),
            ),
            const SizedBox(height: PsSpace.xs),
          ],
          if (_errors['type'] != null) PsFieldError(_errors['type']!),
          const SizedBox(height: PsSpace.md),
          Text('What happened?', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 2000,
            style: PsText.input,
            onChanged: (_) {
              if (_errors.containsKey('description')) setState(() => _errors.remove('description'));
            },
            decoration: psInputDecoration(
              hint: 'When, where and what you noticed…',
              hasError: _errors['description'] != null,
            ),
          ),
          if (_errors['description'] != null) PsFieldError(_errors['description']!),
          const SizedBox(height: PsSpace.md),
          Text('Photo (optional)', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          EvidencePicker(paths: _photos, max: 1, onChanged: (p) => setState(() => _photos = p)),
        ],
      ),
    );
  }
}
