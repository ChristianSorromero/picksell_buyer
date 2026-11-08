import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';
import '../../../services/address_book_service.dart';
import 'map_pin_page.dart';

/// Add or edit an address-book entry (website: account page "Other Addresses").
/// Pops the updated [AddressBook] after saving.
class AddressFormPage extends StatefulWidget {
  const AddressFormPage({super.key, this.address, this.defaultName, this.defaultPhone});

  /// Null to add a new address.
  final SavedAddress? address;

  /// Pre-filled recipient for a new address: the buyer's own name and number.
  final String? defaultName;
  final String? defaultPhone;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  static const _labels = ['Home', 'Work', 'Other'];

  final _book = AddressBookService();
  final _addressKey = GlobalKey<PsAddressFieldsState>();
  late final _name = TextEditingController(text: widget.address?.recipientName ?? widget.defaultName ?? '');
  late final _phone = TextEditingController(text: _format(widget.address?.phone ?? widget.defaultPhone ?? ''));
  late final _customLabel = TextEditingController(text: _isPreset(widget.address?.label) ? '' : (widget.address?.label ?? ''));
  late String? _label = widget.address == null ? 'Home' : (_isPreset(widget.address!.label) ? widget.address!.label : (widget.address!.label == null ? null : 'Other'));
  late GeoPin? _pin = widget.address?.pin;
  final Map<String, String> _errors = {};
  bool _saving = false;

  bool get _editing => widget.address != null;

  static bool _isPreset(String? label) => label == 'Home' || label == 'Work';

  static String _format(String local) {
    final d = local.replaceAll(RegExp(r'\D'), '');
    final n = d.startsWith('0') ? d.substring(1) : d;
    return n.length == 10 ? '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}' : n;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _customLabel.dispose();
    super.dispose();
  }

  String? get _labelValue {
    if (_label == 'Other') {
      final custom = _customLabel.text.trim();
      return custom.isEmpty ? 'Other' : custom;
    }
    return _label;
  }

  Future<void> _pickPin() async {
    final address = _addressKey.currentState;
    final line = [address?.houseNo, address?.street, address?.barangay, address?.municipality, address?.province]
        .where((p) => p != null && p.isNotEmpty)
        .join(', ');
    final pin = await Navigator.of(context).push<GeoPin>(MaterialPageRoute(
      builder: (_) => MapPinPage(initial: _pin, title: 'Pin this address', addressLine: line),
    ));
    if (pin != null && mounted) setState(() => _pin = pin);
  }

  Future<void> _save() async {
    final digits = PsPhoneField.digitsOf(_phone.text);
    final errors = {
      'recipient_name': _name.text.trim().isEmpty ? 'Enter who will receive the parcel.' : null,
      'contact_no': PsValidators.phMobile(digits),
    };
    setState(() {
      _errors
        ..clear()
        ..addEntries(errors.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)));
    });
    final address = _addressKey.currentState!;
    final addressOk = address.validate();
    if (_errors.isNotEmpty || !addressOk) return;

    final input = AddressInput(
      label: _labelValue,
      recipientName: _name.text.trim(),
      contactNo: PsPhoneField.toLocalFormat(digits),
      province: address.province,
      municipality: address.municipality,
      barangay: address.barangay,
      street: address.street,
      houseNo: address.houseNo,
      pin: _pin, // sent back on edits so the pin is kept
    );
    setState(() => _saving = true);
    try {
      final book = _editing ? await _book.update(widget.address!.id, input) : await _book.add(input);
      if (!mounted) return;
      PsToast.success(context, _editing ? 'Address updated' : 'Address saved');
      Navigator.of(context).pop(book);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        for (final f in ['label', 'recipient_name', 'contact_no', 'province', 'municipality', 'barangay', 'street', 'house_no', 'lat', 'lng']) {
          final m = e.fieldError(f);
          if (m != null) _errors[f] = m;
        }
      });
      final limit = e.fieldError('address');
      final pinError = e.fieldError('lat') ?? e.fieldError('lng');
      if (limit != null || pinError != null) {
        PsDialog.error(context, title: 'Couldn’t save this address', message: limit ?? pinError!);
      } else if (!e.isValidation) {
        PsDialog.error(context, title: 'Couldn’t save this address', message: e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: PsSpace.md);
    final a = widget.address;
    return PsAppShell(
      topBar: PsTopBar(title: _editing ? 'Edit Address' : 'New Address'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Save address', uppercase: false, loading: _saving, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          const PsFieldLabel('Label'),
          Wrap(
            spacing: PsSpace.xs,
            children: [
              for (final l in _labels)
                PsOptionChip(label: l, selected: _label == l, onTap: () => setState(() => _label = _label == l ? null : l)),
            ],
          ),
          if (_label == 'Other') ...[
            const SizedBox(height: PsSpace.sm),
            PsTextField(label: 'Name this address', hint: 'e.g. Mom’s house', controller: _customLabel, errorText: _errors['label'], maxLength: 40),
          ],
          gap,
          PsTextField(label: 'Recipient Name', controller: _name, errorText: _errors['recipient_name'], textCapitalization: TextCapitalization.words, maxLength: 120),
          gap,
          PsPhoneField(controller: _phone, errorText: _errors['contact_no'], textInputAction: TextInputAction.next),
          const SizedBox(height: PsSpace.lg),
          Text('Address', style: PsText.bodyStrong),
          const SizedBox(height: PsSpace.sm),
          PsAddressFields(
            key: _addressKey,
            province: a?.province ?? '',
            municipality: a?.municipality ?? '',
            barangay: a?.barangay ?? '',
            street: a?.street,
            houseNo: a?.houseNo,
            errors: _errors,
          ),
          const SizedBox(height: PsSpace.lg),
          _PinCard(pin: _pin, onPick: _pickPin, onRemove: _pin == null ? null : () => setState(() => _pin = null)),
        ],
      ),
    );
  }
}

/// Optional door pin for an address, so riders find the exact spot.
class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin, required this.onPick, this.onRemove});

  final GeoPin? pin;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = pin;
    return PsCard(
      title: 'Map Pin (optional)',
      onTap: onPick,
      child: Row(
        children: [
          Icon(p == null ? Icons.add_location_alt_outlined : Icons.where_to_vote_rounded, color: PsColors.primaryStrong),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p == null ? 'Pin this address on the map' : 'Pinned', style: p == null ? PsText.link : PsText.bodyStrong),
                Text(
                  p == null ? 'Helps the rider find your door.' : '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)} · tap to move',
                  style: PsText.caption,
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(tooltip: 'Remove pin', onPressed: onRemove, icon: const Icon(Icons.close_rounded, color: PsColors.textMuted))
          else
            const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
        ],
      ),
    );
  }
}
