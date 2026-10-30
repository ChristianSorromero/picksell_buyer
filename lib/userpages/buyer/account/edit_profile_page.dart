import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/account.dart';
import '../../../services/account_service.dart';

/// Edit name, birthday, sex, mobile and the delivery address — the same
/// fields as the website's account page. Every order is delivered to this
/// address. Email changes need re-verification and are not editable here.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.profile, this.focusAddress = false});

  /// Loaded from the server when not given.
  final BuyerProfile? profile;

  /// Opened from checkout to fix the delivery address.
  final bool focusAddress;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _account = AccountService();
  late BuyerProfile? _profile = widget.profile;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    if (_profile == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final o = await _account.overview();
      if (mounted) setState(() => _profile = o.profile);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p != null) return _ProfileForm(profile: p, focusAddress: widget.focusAddress);
    return PsAppShell(
      topBar: const PsTopBar(title: 'Edit Profile'),
      body: _loadError == null
          ? const PsSkeletonList(itemCount: 5, thumbnail: false)
          : PsErrorState(title: 'Couldn’t load your profile', message: errorMessage(_loadError!), onRetry: _load),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.profile, required this.focusAddress});

  final BuyerProfile profile;
  final bool focusAddress;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _account = AccountService();
  final _addressKey = GlobalKey<PsAddressFieldsState>();
  final _addressSection = GlobalKey();
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _middle = TextEditingController(text: widget.profile.middleInitial ?? '');
  late final _phone = TextEditingController(text: _format(widget.profile.contactNo));
  late DateTime? _birthday = widget.profile.birthday;
  late String? _sex = widget.profile.sex;
  final Map<String, String> _errors = {};
  bool _saving = false;

  static String _format(String local) {
    final d = local.startsWith('0') ? local.substring(1) : local;
    return d.length == 10 ? '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}' : d;
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _addressSection.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
      });
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _middle.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = PsPhoneField.digitsOf(_phone.text);
    final errors = {
      'first_name': PsValidators.personName(_first.text, 'First name'),
      'last_name': PsValidators.personName(_last.text, 'Last name'),
      'birthday': PsValidators.birthDate(_birthday),
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

    setState(() => _saving = true);
    final b = _birthday!;
    try {
      await _account.updateProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        middleInitial: _middle.text.trim().isEmpty ? null : _middle.text.trim(),
        birthday: '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
        contactNo: PsPhoneField.toLocalFormat(digits),
        sex: _sex,
        province: address.province,
        municipality: address.municipality,
        barangay: address.barangay,
        street: address.street,
        houseNo: address.houseNo,
      );
      if (!mounted) return;
      PsToast.success(context, 'Profile updated');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        for (final f in ['first_name', 'last_name', 'middle_initial', 'birthday', 'contact_no', 'province', 'municipality', 'barangay', 'street', 'house_no']) {
          final m = e.fieldError(f);
          if (m != null) _errors[f] = m;
        }
      });
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t save changes', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: PsSpace.md);
    final now = DateTime.now();
    final p = widget.profile;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Edit Profile'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Save changes', uppercase: false, loading: _saving, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          PsTextField(label: 'First Name', controller: _first, errorText: _errors['first_name'], textCapitalization: TextCapitalization.words, maxLength: 50),
          gap,
          PsTextField(label: 'Middle Initial', hint: 'Optional', controller: _middle, errorText: _errors['middle_initial'], textCapitalization: TextCapitalization.characters, maxLength: 5),
          gap,
          PsTextField(label: 'Last Name', controller: _last, errorText: _errors['last_name'], textCapitalization: TextCapitalization.words, maxLength: 50),
          gap,
          PsDateField(
            label: 'Date of Birth',
            value: _birthday,
            errorText: _errors['birthday'],
            lastDate: now,
            initialDate: DateTime(now.year - 18, now.month, now.day),
            onChanged: (d) => setState(() {
              _birthday = d;
              final err = PsValidators.birthDate(d);
              err == null ? _errors.remove('birthday') : _errors['birthday'] = err;
            }),
          ),
          gap,
          const PsFieldLabel('Sex (optional)'),
          Wrap(
            spacing: PsSpace.xs,
            children: [
              for (final s in const ['Male', 'Female'])
                PsOptionChip(label: s, selected: _sex == s, onTap: () => setState(() => _sex = _sex == s ? null : s)),
            ],
          ),
          gap,
          PsPhoneField(controller: _phone, errorText: _errors['contact_no']),
          gap,
          PsTextField(label: 'Email', controller: TextEditingController(text: p.email), enabled: false),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('Contact support to change your email address.', style: PsText.caption),
          ),
          const SizedBox(height: PsSpace.lg),
          Text('Delivery Address', key: _addressSection, style: PsText.bodyStrong),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: PsSpace.sm),
            child: Text('Your orders are delivered here, on the app and the website.', style: PsText.caption),
          ),
          PsAddressFields(
            key: _addressKey,
            province: p.province,
            municipality: p.municipality,
            barangay: p.barangay,
            street: p.street,
            houseNo: p.houseNo,
            errors: _errors,
          ),
        ],
      ),
    );
  }
}
