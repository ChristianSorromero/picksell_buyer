import 'package:flutter/material.dart';

import '../../services/address_service.dart';
import '../components.dart';

/// The buyer's delivery address fields, as on the website's registration and
/// account pages: province → city / municipality → barangay from the PSGC
/// directory (official names; the server turns them into PSGC codes for
/// Pickrush), then street and house number. Falls back to typing when the
/// directory can't be reached.
///
/// Read the values through a [GlobalKey<PsAddressFieldsState>].
class PsAddressFields extends StatefulWidget {
  const PsAddressFields({
    super.key,
    this.province = '',
    this.municipality = '',
    this.barangay = '',
    this.street,
    this.houseNo,
    this.errors = const {},
  });

  final String province;
  final String municipality;
  final String barangay;
  final String? street;
  final String? houseNo;

  /// Server-side errors keyed by field (province, municipality, barangay, street, house_no).
  final Map<String, String> errors;

  @override
  State<PsAddressFields> createState() => PsAddressFieldsState();
}

class PsAddressFieldsState extends State<PsAddressFields> {
  final _psgc = AddressService();

  late final _street = TextEditingController(text: widget.street ?? '');
  late final _house = TextEditingController(text: widget.houseNo ?? '');
  late final _provinceText = TextEditingController(text: widget.province);
  late final _cityText = TextEditingController(text: widget.municipality);
  late final _barangayText = TextEditingController(text: widget.barangay);

  List<Province> _provinces = [];
  List<Municipality> _cities = [];
  List<Barangay> _barangays = [];
  Province? _province;
  Municipality? _city;
  Barangay? _barangay;
  bool _directoryLoading = true;

  /// PSGC unreachable → plain text fields.
  bool _manual = false;
  final Map<String, String> _errors = {};

  String get province => _manual ? _provinceText.text.trim() : (_province?.name ?? '');
  String get municipality => _manual ? _cityText.text.trim() : (_city?.name ?? '');
  String get barangay => _manual ? _barangayText.text.trim() : (_barangay?.name ?? '');
  String? get street => _street.text.trim().isEmpty ? null : _street.text.trim();
  String? get houseNo => _house.text.trim().isEmpty ? null : _house.text.trim();

  /// Checks the required parts and shows errors; true when complete.
  bool validate() {
    final errors = <String, String?>{
      'province': province.isEmpty ? 'Select a province.' : null,
      'municipality': municipality.isEmpty ? 'Select a city or municipality.' : null,
      'barangay': barangay.isEmpty ? 'Select a barangay.' : null,
    };
    setState(() {
      _errors
        ..clear()
        ..addEntries(errors.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)));
    });
    return _errors.isEmpty;
  }

  String? _error(String field) => _errors[field] ?? widget.errors[field];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    for (final c in [_street, _house, _provinceText, _cityText, _barangayText]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final list = await _psgc.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = list;
        _directoryLoading = false;
        _province = list.where((p) => p.name == widget.province).firstOrNull;
      });
      if (_province != null) await _loadCities(_province!, keepSelection: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _manual = true;
          _directoryLoading = false;
        });
      }
    }
  }

  Future<void> _loadCities(Province p, {bool keepSelection = false}) async {
    setState(() {
      _cities = [];
      _barangays = [];
      if (!keepSelection) {
        _city = null;
        _barangay = null;
      }
    });
    try {
      final list = await _psgc.getMunicipalities(p.code);
      if (!mounted) return;
      setState(() {
        _cities = list;
        if (keepSelection) _city = list.where((c) => c.name == widget.municipality).firstOrNull;
      });
      if (keepSelection && _city != null) await _loadBarangays(_city!, keepSelection: true);
    } catch (_) {
      if (mounted) setState(() => _manual = true);
    }
  }

  Future<void> _loadBarangays(Municipality m, {bool keepSelection = false}) async {
    setState(() {
      _barangays = [];
      if (!keepSelection) _barangay = null;
    });
    try {
      final list = await _psgc.getBarangays(m.code);
      if (!mounted) return;
      setState(() {
        _barangays = list;
        if (keepSelection) _barangay = list.where((b) => b.name == widget.barangay).firstOrNull;
      });
    } catch (_) {
      if (mounted) setState(() => _manual = true);
    }
  }

  Widget _dropdown<T>({
    required String label,
    required String field,
    required List<T> items,
    required T? value,
    required ValueChanged<T?>? onChanged,
    required String hint,
    bool loading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsFieldLabel(label),
        DropdownButtonFormField<T>(
          key: ValueKey('$field-${value ?? ''}-${items.length}'),
          initialValue: value,
          isExpanded: true,
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text('$i', overflow: TextOverflow.ellipsis))],
          onChanged: onChanged,
          style: PsText.input,
          icon: loading
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: psInputDecoration(hint: hint, hasError: _error(field) != null, enabled: onChanged != null),
        ),
        if (_error(field) != null) PsFieldError(_error(field)!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: PsSpace.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_manual) ...[
          PsCard(
            color: PsColors.warningSoft,
            borderColor: PsColors.warningSoft,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: PsColors.warning),
                const SizedBox(width: PsSpace.xs),
                Expanded(child: Text('Couldn’t load the address directory. Type your address instead.', style: PsText.caption.copyWith(color: PsColors.warning))),
              ],
            ),
          ),
          gap,
          PsTextField(label: 'Province', controller: _provinceText, errorText: _error('province'), maxLength: 100),
          gap,
          PsTextField(label: 'City / Municipality', controller: _cityText, errorText: _error('municipality'), maxLength: 100),
          gap,
          PsTextField(label: 'Barangay', controller: _barangayText, errorText: _error('barangay'), maxLength: 100),
        ] else ...[
          _dropdown<Province>(
            label: 'Province',
            field: 'province',
            hint: _directoryLoading ? 'Loading…' : 'Select province',
            loading: _directoryLoading,
            items: _provinces,
            value: _province,
            onChanged: _directoryLoading
                ? null
                : (p) {
                    if (p == null) return;
                    setState(() => _province = p);
                    _loadCities(p);
                  },
          ),
          gap,
          _dropdown<Municipality>(
            label: 'City / Municipality',
            field: 'municipality',
            hint: _province == null ? 'Select a province first' : 'Select city / municipality',
            loading: _province != null && _cities.isEmpty,
            items: _cities,
            value: _city,
            onChanged: _cities.isEmpty
                ? null
                : (c) {
                    if (c == null) return;
                    setState(() => _city = c);
                    _loadBarangays(c);
                  },
          ),
          gap,
          _dropdown<Barangay>(
            label: 'Barangay',
            field: 'barangay',
            hint: _city == null ? 'Select a city first' : 'Select barangay',
            loading: _city != null && _barangays.isEmpty,
            items: _barangays,
            value: _barangay,
            onChanged: _barangays.isEmpty ? null : (b) => setState(() => _barangay = b),
          ),
        ],
        gap,
        PsTextField(label: 'Street', hint: 'Optional, e.g. Rizal Avenue', controller: _street, errorText: _error('street'), maxLength: 255, autofillHints: const [AutofillHints.streetAddressLine1]),
        gap,
        PsTextField(label: 'House / Unit No.', hint: 'Optional', controller: _house, errorText: _error('house_no'), maxLength: 100),
      ],
    );
  }
}
