import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/account.dart';
import '../../../services/account_service.dart';

/// Edit name, birthday, sex and mobile. Email changes need re-verification
/// and are intentionally not editable here.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final BuyerProfile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _account = AccountService();
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
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
  void dispose() {
    _first.dispose();
    _last.dispose();
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
    if (_errors.isNotEmpty) return;

    setState(() => _saving = true);
    final b = _birthday!;
    try {
      await _account.updateProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        birthday: '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
        contactNo: PsPhoneField.toLocalFormat(digits),
        sex: _sex,
      );
      if (!mounted) return;
      PsToast.success(context, 'Profile updated');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        for (final f in ['first_name', 'last_name', 'birthday', 'contact_no']) {
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
    return PsAppShell(
      topBar: const PsTopBar(title: 'Edit Profile'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Save changes', uppercase: false, loading: _saving, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          PsTextField(label: 'First Name', controller: _first, errorText: _errors['first_name'], textCapitalization: TextCapitalization.words, maxLength: 100),
          gap,
          PsTextField(label: 'Last Name', controller: _last, errorText: _errors['last_name'], textCapitalization: TextCapitalization.words, maxLength: 100),
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
          PsTextField(
            label: 'Email',
            controller: TextEditingController(text: widget.profile.email),
            enabled: false,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('Contact support to change your email address.', style: PsText.caption),
          ),
        ],
      ),
    );
  }
}
