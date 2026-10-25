import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'evidence_picker.dart';

/// BUY-C10 Report a Problem — creates a ticket in the admin disputes queue.
class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key, required this.order});

  final OrderDetail order;

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _orders = OrderService();
  final _details = TextEditingController();
  List<String> _categories = const ['Damaged Item', 'Missing Item', 'Wrong Item', 'Quality Issue', 'Delivery Delay', 'Other'];
  String? _category;
  List<String> _photos = [];
  final Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _orders.options().then((o) {
      if (mounted && o.reportCategories.isNotEmpty) setState(() => _categories = o.reportCategories);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errors.clear();
      if (_category == null) _errors['category'] = 'Choose what the issue is about.';
      if (_details.text.trim().length < 10) _errors['details'] = 'Please describe the issue in at least 10 characters.';
    });
    if (_errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      final ref = await _orders.report(widget.order.id, category: _category!, details: _details.text.trim(), photos: _photos);
      if (!mounted) return;
      await PsDialog.info(
        context,
        title: 'Report submitted',
        message: 'Ticket $ref is with our support team. We’ll get back to you within 24–48 hours.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        for (final f in ['category', 'details']) {
          final m = e.fieldError(f);
          if (m != null) _errors[f] = m;
        }
      });
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t submit report', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.order.summary;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Report a Problem'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Submit Report', uppercase: false, loading: _busy, onPressed: _submit)),
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
                      if (s.seller != null) Text(s.seller!.name, style: PsText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          Text('What is the issue?', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          Wrap(
            spacing: PsSpace.xs,
            runSpacing: PsSpace.xs,
            children: [
              for (final c in _categories)
                PsOptionChip(label: c, selected: _category == c, onTap: () => setState(() {
                      _category = c;
                      _errors.remove('category');
                    })),
            ],
          ),
          if (_errors['category'] != null) PsFieldError(_errors['category']!),
          const SizedBox(height: PsSpace.lg),
          Text('Tell us more', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          TextField(
            controller: _details,
            maxLines: 5,
            maxLength: 2000,
            style: PsText.input,
            onChanged: (_) {
              if (_errors.containsKey('details')) setState(() => _errors.remove('details'));
            },
            decoration: psInputDecoration(hint: 'Describe the issue in detail…', hasError: _errors['details'] != null),
          ),
          if (_errors['details'] != null) PsFieldError(_errors['details']!),
          const SizedBox(height: PsSpace.md),
          Text('Upload Evidence', style: PsText.heading.copyWith(fontSize: 16)),
          const SizedBox(height: PsSpace.xs),
          EvidencePicker(paths: _photos, onChanged: (p) => setState(() => _photos = p)),
        ],
      ),
    );
  }
}
