import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/components.dart';
import '../services/auth_service.dart';

/// Password reset: email → six-digit code + new password. The server answers
/// the same whether or not the email has an account, and a successful reset
/// signs the buyer out of every device.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _auth = AuthService();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  final Map<String, String?> _errors = {};
  DateTime? _resendAt;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _resendIn => _resendAt == null ? 0 : _resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 999);

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    setState(() => _errors['email'] = PsValidators.email(email));
    if (_errors['email'] != null || _busy) return;

    setState(() => _busy = true);
    final result = await _auth.forgotPassword(email: email);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _errors['email'] = result.fieldError('email'));
      if (_errors['email'] == null) {
        await PsDialog.error(context, title: result.isNetworkError ? 'Can’t reach Picksell' : 'Couldn’t send the code', message: result.message);
      }
      return;
    }

    final wait = (result.data?['resend_in'] as num?)?.toInt() ?? 60;
    setState(() {
      _codeSent = true;
      _resendAt = DateTime.now().add(Duration(seconds: wait));
    });
    _ticker?.cancel();
    // The page text now explains the code was sent; no toast over the form.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _reset() async {
    setState(() {
      _errors['code'] = PsValidators.otp(_code.text);
      _errors['password'] = PsValidators.password(_password.text);
      _errors['password_confirmation'] = PsValidators.confirmPassword(_confirm.text, _password.text);
    });
    if (_errors.values.any((e) => e != null) || _busy) return;

    setState(() => _busy = true);
    final result = await _auth.resetPassword(
      email: _email.text.trim(),
      code: _code.text,
      password: _password.text,
      passwordConfirmation: _confirm.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() {
        _errors['code'] = result.fieldError('code');
        _errors['password'] = result.fieldError('password');
      });
      if (_errors['code'] == null && _errors['password'] == null) {
        await PsDialog.error(context, title: result.isNetworkError ? 'Can’t reach Picksell' : 'Couldn’t reset your password', message: result.message);
      }
      return;
    }

    PsToast.success(context, 'Password changed. Log in with your new password.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Reset Password'),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          Text(
            _codeSent
                ? 'If a PickSell account uses ${_email.text.trim()}, we emailed it a six-digit code. Enter it below with your new password.'
                : 'Enter the email you use for PickSell and we’ll send you a code to reset your password.',
            style: PsText.subtitle,
          ),
          const SizedBox(height: PsSpace.lg),
          PsTextField(
            label: 'Email',
            hint: 'name@example.com',
            controller: _email,
            enabled: !_codeSent,
            errorText: _errors['email'],
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            onChanged: (_) => setState(() => _errors['email'] = null),
          ),
          if (!_codeSent) ...[
            const SizedBox(height: PsSpace.lg),
            PsPrimaryButton(label: 'Send code', loading: _busy, onPressed: _busy ? null : _sendCode),
          ] else ...[
            const SizedBox(height: PsSpace.lg),
            const PsFieldLabel('Six-digit code'),
            PsOtpInput(controller: _code, hasError: _errors['code'] != null, onChanged: (_) => setState(() => _errors['code'] = null)),
            if (_errors['code'] != null) PsFieldError(_errors['code']!),
            const SizedBox(height: PsSpace.lg),
            PsTextField(
              label: 'New password',
              hint: 'At least 8 characters',
              controller: _password,
              obscure: true,
              errorText: _errors['password'],
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _errors['password'] = null),
            ),
            PsPasswordChecklist(password: _password.text),
            const SizedBox(height: PsSpace.md),
            PsTextField(
              label: 'Confirm new password',
              hint: 'Re-enter your new password',
              controller: _confirm,
              obscure: true,
              textInputAction: TextInputAction.done,
              errorText: _errors['password_confirmation'],
              onChanged: (_) => setState(() => _errors['password_confirmation'] = null),
              onSubmitted: (_) => _reset(),
            ),
            const SizedBox(height: PsSpace.lg),
            PsPrimaryButton(label: 'Reset password', loading: _busy, onPressed: _busy ? null : _reset),
            const SizedBox(height: PsSpace.sm),
            Center(
              child: PsSecondaryButton(
                label: _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
                onPressed: _resendIn > 0 || _busy ? null : _sendCode,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
