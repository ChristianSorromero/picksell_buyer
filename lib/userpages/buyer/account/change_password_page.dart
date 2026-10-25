import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../services/account_service.dart';

/// Change password with the same strength rules as registration. Other
/// devices are signed out by the server on success.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final Map<String, String> _errors = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = {
      'current_password': _current.text.isEmpty ? 'Enter your current password.' : null,
      'password': PsValidators.password(_password.text) ??
          (_password.text == _current.text ? 'Choose a password different from your current one.' : null),
      'password_confirmation': PsValidators.confirmPassword(_confirm.text, _password.text),
    };
    setState(() {
      _errors
        ..clear()
        ..addEntries(errors.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)));
    });
    if (_errors.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      await AccountService().changePassword(current: _current.text, password: _password.text, confirmation: _confirm.text);
      if (!mounted) return;
      await PsDialog.info(context, title: 'Password changed', message: 'You’ve been signed out on your other devices.');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        for (final f in ['current_password', 'password']) {
          final m = e.fieldError(f);
          if (m != null) _errors[f] = m;
        }
      });
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t change password', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Change Password'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Update password', uppercase: false, loading: _saving, onPressed: _save)),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(PsSpace.gutter),
          children: [
            PsTextField(label: 'Current Password', controller: _current, obscure: true, errorText: _errors['current_password'], autofillHints: const [AutofillHints.password]),
            const SizedBox(height: PsSpace.md),
            PsTextField(label: 'New Password', controller: _password, obscure: true, errorText: _errors['password'], autofillHints: const [AutofillHints.newPassword]),
            PsPasswordChecklist(password: _password.text),
            const SizedBox(height: PsSpace.md),
            PsTextField(
              label: 'Confirm New Password',
              controller: _confirm,
              obscure: true,
              errorText: _errors['password_confirmation'],
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}
