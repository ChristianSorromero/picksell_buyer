import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';

/// The website's browse filters: price range, rating and store location.
/// Resolves to the new filters, or null when dismissed.
Future<ProductFilters?> showProductFilters(
  BuildContext context, {
  required ProductFilters current,
  required List<String> provinces,
}) => PsBottomSheet.show<ProductFilters>(
  context,
  title: 'Filters',
  builder: (_) => _FiltersForm(current: current, provinces: provinces),
);

class _FiltersForm extends StatefulWidget {
  const _FiltersForm({required this.current, required this.provinces});

  final ProductFilters current;
  final List<String> provinces;

  @override
  State<_FiltersForm> createState() => _FiltersFormState();
}

class _FiltersFormState extends State<_FiltersForm> {
  late final _min = TextEditingController(text: _price(widget.current.minPrice));
  late final _max = TextEditingController(text: _price(widget.current.maxPrice));
  late int? _rating = widget.current.minRating;
  late String? _location = widget.current.location;
  String? _priceError;

  static String _price(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    if (min != null && max != null && min > max) {
      setState(() => _priceError = 'The minimum is higher than the maximum.');
      return;
    }
    Navigator.of(context).pop(ProductFilters(minPrice: min, maxPrice: max, minRating: _rating, location: _location));
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: PsSpace.md, bottom: PsSpace.xs),
    child: Text(title, style: PsText.bodyStrong),
  );

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('Price (₱)'),
          Row(
            children: [
              Expanded(
                child: PsTextField(
                  label: 'Min',
                  controller: _min,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: digits,
                  onChanged: (_) => setState(() => _priceError = null),
                ),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: PsTextField(
                  label: 'Max',
                  controller: _max,
                  hint: 'Any',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: digits,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _priceError = null),
                ),
              ),
            ],
          ),
          if (_priceError != null) PsFieldError(_priceError!),
          _section('Rating'),
          Wrap(
            spacing: PsSpace.xs,
            runSpacing: PsSpace.xs,
            children: [
              for (final (value, label) in const [(null, 'Any'), (4, '4★ & up'), (3, '3★ & up')])
                PsOptionChip(label: label, selected: _rating == value, onTap: () => setState(() => _rating = value)),
            ],
          ),
          _section('Store location'),
          Wrap(
            spacing: PsSpace.xs,
            runSpacing: PsSpace.xs,
            children: [
              PsOptionChip(
                label: 'Anywhere',
                selected: _location == null,
                onTap: () => setState(() => _location = null),
              ),
              PsOptionChip(
                label: 'Near me',
                selected: _location == ProductFilters.near,
                onTap: () => setState(() => _location = ProductFilters.near),
              ),
              for (final p in widget.provinces)
                PsOptionChip(label: p, selected: _location == p, onTap: () => setState(() => _location = p)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: PsSpace.xs),
            child: Text(
              'Near me: stores in your province, usually the cheapest and fastest to ship.',
              style: PsText.caption,
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          Row(
            children: [
              Expanded(
                child: PsSecondaryButton.outlined(
                  label: 'Clear',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(const ProductFilters()),
                ),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: PsPrimaryButton(label: 'Show results', onPressed: _apply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
