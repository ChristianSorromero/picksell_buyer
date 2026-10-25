import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';
import '../../../services/account_service.dart';
import '../../../services/address_service.dart';

/// Add / edit a delivery address. Province → city → barangay come from the
/// PSGC directory; if it can't be reached the fields fall back to typing.
class AddressFormPage extends StatefulWidget {
  const AddressFormPage({super.key, this.address});

  final Address? address;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _psgc = AddressService();
  final _account = AccountService();

  late AddressLabel _label = widget.address?.label ?? AddressLabel.home;
  late final _name = TextEditingController(text: widget.address?.recipientName ?? '');
  late final _phone = TextEditingController(text: _initialPhone());
  late final _street = TextEditingController(text: widget.address?.street ?? '');
  late final _house = TextEditingController(text: widget.address?.houseNo ?? '');
  late final _postal = TextEditingController(text: widget.address?.postalCode ?? '');
  late final _landmark = TextEditingController(text: widget.address?.landmark ?? '');
  late final _provinceText = TextEditingController(text: widget.address?.province ?? '');
  late final _cityText = TextEditingController(text: widget.address?.municipality ?? '');
  late final _barangayText = TextEditingController(text: widget.address?.barangay ?? '');
  late bool _default = widget.address?.isDefault ?? false;

  List<Province> _provinces = [];
  List<Municipality> _cities = [];
  List<Barangay> _barangays = [];
  Province? _province;
  Municipality? _city;
  Barangay? _barangay;
  bool _directoryLoading = true;

  /// PSGC unreachable → plain text fields.
  bool _manual = false;
  bool _saving = false;
  final Map<String, String> _errors = {};

  String _initialPhone() {
    final p = widget.address?.phone ?? '';
    final d = p.startsWith('0') ? p.substring(1) : p;
    return d.length == 10 ? '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}' : d;
  }

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _street, _house, _postal, _landmark, _provinceText, _cityText, _barangayText]) {
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
        _province = list.where((p) => p.name == widget.address?.province).firstOrNull;
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
        if (keepSelection) _city = list.where((c) => c.name == widget.address?.municipality).firstOrNull;
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
        if (keepSelection) _barangay = list.where((b) => b.name == widget.address?.barangay).firstOrNull;
      });
    } catch (_) {
      if (mounted) setState(() => _manual = true);
    }
  }

  String get _provinceValue => _manual ? _provinceText.text.trim() : (_province?.name ?? '');
  String get _cityValue => _manual ? _cityText.text.trim() : (_city?.name ?? '');
  String get _barangayValue => _manual ? _barangayText.text.trim() : (_barangay?.name ?? '');

  bool _validate() {
    final digits = PsPhoneField.digitsOf(_phone.text);
    final errors = <String, String?>{
      'recipient_name': PsValidators.personName(_name.text, 'Recipient name'),
      'phone': PsValidators.phMobile(digits),
      'province': _provinceValue.isEmpty ? 'Select a province.' : null,
      'municipality': _cityValue.isEmpty ? 'Select a city or municipality.' : null,
      'barangay': _barangayValue.isEmpty ? 'Select a barangay.' : null,
      'street': PsValidators.requiredText(_street.text, 'Street'),
      'postal_code': _postal.text.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(_postal.text) ? 'Postal codes have 4 digits.' : null,
    };
    setState(() {
      _errors
        ..clear()
        ..addEntries(errors.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)));
    });
    return _errors.isEmpty;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    final draft = Address(
      id: widget.address?.id ?? 0,
      label: _label,
      recipientName: _name.text.trim(),
      phone: PsPhoneField.toLocalFormat(PsPhoneField.digitsOf(_phone.text)),
      province: _provinceValue,
      municipality: _cityValue,
      barangay: _barangayValue,
      street: _street.text.trim(),
      houseNo: _house.text.trim().isEmpty ? null : _house.text.trim(),
      postalCode: _postal.text.trim().isEmpty ? null : _postal.text.trim(),
      landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
      isDefault: _default,
    );
    try {
      final saved = await _account.saveAddress(draft, id: widget.address?.id);
      if (!mounted) return;
      PsToast.success(context, widget.address == null ? 'Address saved' : 'Address updated');
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        for (final f in ['recipient_name', 'phone', 'province', 'municipality', 'barangay', 'street', 'postal_code', 'landmark']) {
          final m = e.fieldError(f);
          if (m != null) _errors[f] = m;
        }
      });
      if (!e.isValidation) {
        PsDialog.error(context, title: e.isNetworkError ? 'Can’t reach Picksell' : 'Couldn’t save address', message: e.message);
      }
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
          initialValue: value,
          isExpanded: true,
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text('$i', overflow: TextOverflow.ellipsis))],
          onChanged: onChanged,
          style: PsText.input,
          icon: loading
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: psInputDecoration(hint: hint, hasError: _errors[field] != null, enabled: onChanged != null),
        ),
        if (_errors[field] != null) PsFieldError(_errors[field]!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: PsSpace.md);
    return PsAppShell(
      topBar: PsTopBar(title: widget.address == null ? 'New Address' : 'Edit Address'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Save address', uppercase: false, loading: _saving, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          const PsFieldLabel('Label'),
          Wrap(
            spacing: PsSpace.xs,
            children: [
              for (final l in AddressLabel.values)
                PsOptionChip(label: l.label, selected: _label == l, onTap: () => setState(() => _label = l)),
            ],
          ),
          gap,
          PsTextField(
            label: 'Recipient Name',
            hint: 'Full name',
            controller: _name,
            errorText: _errors['recipient_name'],
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            maxLength: 120,
          ),
          gap,
          PsPhoneField(controller: _phone, label: 'Contact Number', errorText: _errors['phone'], textInputAction: TextInputAction.next),
          gap,
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
            PsTextField(label: 'Province', controller: _provinceText, errorText: _errors['province'], maxLength: 120),
            gap,
            PsTextField(label: 'City / Municipality', controller: _cityText, errorText: _errors['municipality'], maxLength: 120),
            gap,
            PsTextField(label: 'Barangay', controller: _barangayText, errorText: _errors['barangay'], maxLength: 120),
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
          PsTextField(label: 'Street', hint: 'e.g. Rizal Avenue', controller: _street, errorText: _errors['street'], maxLength: 255, autofillHints: const [AutofillHints.streetAddressLine1]),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PsTextField(label: 'House / Unit No.', hint: 'Optional', controller: _house, maxLength: 60)),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: PsTextField(
                  label: 'Postal Code',
                  hint: 'Optional',
                  controller: _postal,
                  errorText: _errors['postal_code'],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                ),
              ),
            ],
          ),
          gap,
          PsTextField(label: 'Landmark', hint: 'e.g. Near SM North EDSA (optional)', controller: _landmark, errorText: _errors['landmark'], maxLength: 160, textInputAction: TextInputAction.done),
          gap,
          PsCard(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _default,
              activeTrackColor: PsColors.primary,
              title: Text('Set as default address', style: PsText.bodyStrong),
              onChanged: (v) => setState(() => _default = v),
            ),
          ),
        ],
      ),
    );
  }
}
