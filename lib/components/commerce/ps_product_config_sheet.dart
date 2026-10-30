import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import '../shared/forms/ps_text_field.dart';
import '../shared/ps_bottom_sheet.dart';
import '../shared/ps_buttons.dart';
import 'ps_price.dart';
import 'ps_product_image.dart';
import 'ps_quantity_stepper.dart';
import 'ps_variation_selector.dart';

/// What the buyer configured in [PsProductConfigSheet].
class ProductSelection {
  const ProductSelection({required this.variationIds, required this.quantity, required this.label});

  final List<int> variationIds;
  final int quantity;

  /// "Midnight Black, Pro" or null without variations.
  final String? label;
}

/// COM-C10 Add-to-Cart / COM-C11 Buy-Now configurator. A cart line holds one
/// option, as on the website, so choosing an option clears any other group.
/// Quantity stays within the product's stock (the website's stock check).
/// Runs [onSubmit] with a spinner and shows any server rejection inline.
class PsProductConfigSheet extends StatefulWidget {
  const PsProductConfigSheet({
    super.key,
    required this.detail,
    required this.actionLabel,
    required this.onSubmit,
    this.initialVariationIds = const [],
    this.initialQuantity = 1,
  });

  final ProductDetail detail;
  final String actionLabel;
  final Future<void> Function(ProductSelection selection) onSubmit;
  final List<int> initialVariationIds;
  final int initialQuantity;

  /// Resolves `true` when [onSubmit] succeeded.
  static Future<bool> show(
    BuildContext context, {
    required ProductDetail detail,
    required String actionLabel,
    required Future<void> Function(ProductSelection selection) onSubmit,
    List<int> initialVariationIds = const [],
    int initialQuantity = 1,
  }) async {
    final ok = await PsBottomSheet.show<bool>(
      context,
      builder: (_) => PsProductConfigSheet(
        detail: detail,
        actionLabel: actionLabel,
        onSubmit: onSubmit,
        initialVariationIds: initialVariationIds,
        initialQuantity: initialQuantity,
      ),
    );
    return ok ?? false;
  }

  @override
  State<PsProductConfigSheet> createState() => _PsProductConfigSheetState();
}

class _PsProductConfigSheetState extends State<PsProductConfigSheet> {
  late final Map<String, int> _selected = {
    for (final g in widget.detail.variationGroups)
      for (final o in g.options)
        if (widget.initialVariationIds.take(1).contains(o.id)) g.name: o.id,
  };
  late int _quantity = widget.initialQuantity;
  Set<String> _missing = {};
  String? _error;
  bool _busy = false;

  ProductDetail get d => widget.detail;

  int get _available => d.product.stock;

  int get _max => _available < d.maxQuantity ? _available : d.maxQuantity;

  Future<void> _submit() async {
    if (d.variationGroups.isNotEmpty && _selected.isEmpty) {
      setState(() => _missing = {for (final g in d.variationGroups) g.name});
      return;
    }
    if (_max <= 0) {
      setState(() => _error = 'This item is out of stock.');
      return;
    }

    final chosen = _selected.entries.firstOrNull;
    final ids = [if (chosen != null) chosen.value];
    final label = chosen == null
        ? null
        : '${chosen.key}: ${d.variationGroups.firstWhere((g) => g.name == chosen.key).options.firstWhere((o) => o.id == chosen.value).value}';

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(ProductSelection(variationIds: ids, quantity: _quantity, label: label));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.statusCode == 401
            ? 'Please log in to continue.'
            : (e.fieldError('quantity') ?? e.fieldError('variation_ids') ?? e.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    final max = _max;
    if (_quantity > max && max > 0) _quantity = max;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, PsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PsThumbnail(url: d.product.image, size: 80),
              const SizedBox(width: PsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.product.name, style: PsText.heading.copyWith(fontSize: 17), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    PsPriceDisplay(price: d.product.price, originalPrice: d.product.originalPrice, accent: true),
                    const SizedBox(height: 4),
                    Text(
                      available <= 0
                          ? 'Out of stock'
                          : available <= 5
                              ? 'Only $available left!'
                              : '$available in stock',
                      style: PsText.caption.copyWith(
                        color: available <= 5 ? PsColors.warning : PsColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PsSpace.lg),
          if (d.variationGroups.isNotEmpty)
            PsVariationSelector(
              groups: d.variationGroups,
              selected: _selected,
              missing: _missing,
              onChanged: (type, id) => setState(() {
                _selected
                  ..clear()
                  ..[type] = id;
                _missing = {};
                _error = null;
              }),
            ),
          Row(
            children: [
              Text('Quantity', style: PsText.label),
              const SizedBox(width: PsSpace.sm),
              if (max > 0)
                Expanded(
                  child: Text(
                    'Maximum $max ${max == 1 ? 'item' : 'items'} per order',
                    textAlign: TextAlign.right,
                    style: PsText.caption.copyWith(color: PsColors.primaryStrong, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PsSpace.xs),
          PsQuantityStepper(
            value: _quantity,
            max: max < 1 ? 1 : max,
            enabled: max > 0 && !_busy,
            onChanged: (v) => setState(() {
              _quantity = v;
              _error = null;
            }),
          ),
          if (_error != null) PsFieldError(_error!),
          const SizedBox(height: PsSpace.lg),
          PsPrimaryButton(label: widget.actionLabel, loading: _busy, onPressed: max > 0 ? _submit : null),
        ],
      ),
    );
  }
}
