import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/components.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import 'email_verification_page.dart';
import 'login.dart';

/// Buyer registration (Figma "Buyer Registration" 1–3):
///   1. Personal Information — first/last name, date of birth (18+)
///   2. Contact Information  — email + PH mobile, checked against the API
///   3. Security and Consent — password rules, confirmation, terms
/// then hands off to [EmailVerificationPage] for the six-digit code.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

enum _Step {
  personal('Personal Information', 'Create your account', 'Let’s start with your personal information.'),
  contact('Contact Information', 'Your contact details', 'We’ll use these details to verify your account.'),
  security('Security and Consent', 'Secure your account', 'Create a strong password to protect your account.');

  const _Step(this.label, this.title, this.subtitle);

  final String label;
  final String title;
  final String subtitle;

  /// Which step owns each API field, so server errors land on the right screen.
  static _Step ofField(String field) {
    switch (field) {
      case 'first_name':
      case 'last_name':
      case 'birthday':
        return personal;
      case 'email':
      case 'contact_no':
        return contact;
      default:
        return security;
    }
  }
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = AuthService();

  _Step _step = _Step.personal;
  bool _forward = true;
  bool _busy = false;

  /// Steps the user has tried to submit; their fields revalidate live.
  final Set<_Step> _attempted = {};

  /// Error per API field name (client or server).
  final Map<String, String> _errors = {};

  // Step 1
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _birthday;

  // Step 2
  final _email = TextEditingController();
  final _mobile = TextEditingController();

  // Step 3
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acceptedTerms = false;

  final _lastNameFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {})); // drives the checklist
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _mobile, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [_lastNameFocus, _mobileFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────

  String get _mobileDigits => PsPhoneField.digitsOf(_mobile.text);

  String? _validate(String field) {
    switch (field) {
      case 'first_name':
        return PsValidators.personName(_firstName.text, 'First name');
      case 'last_name':
        return PsValidators.personName(_lastName.text, 'Last name');
      case 'birthday':
        return PsValidators.birthDate(_birthday);
      case 'email':
        return PsValidators.email(_email.text);
      case 'contact_no':
        return PsValidators.phMobile(_mobileDigits);
      case 'password':
        return PsValidators.password(_password.text);
      case 'password_confirmation':
        return PsValidators.confirmPassword(_confirm.text, _password.text);
      case 'terms':
        return _acceptedTerms ? null : 'Please agree to the Terms of Service and Privacy Policy.';
    }
    return null;
  }

  static const Map<_Step, List<String>> _fields = {
    _Step.personal: ['first_name', 'last_name', 'birthday'],
    _Step.contact: ['email', 'contact_no'],
    _Step.security: ['password', 'password_confirmation', 'terms'],
  };

  /// Validates every field on [step]; returns true when all pass.
  bool _validateStep(_Step step) {
    _attempted.add(step);
    var ok = true;
    setState(() {
      for (final field in _fields[step]!) {
        final error = _validate(field);
        if (error == null) {
          _errors.remove(field);
        } else {
          _errors[field] = error;
          ok = false;
        }
      }
    });
    return ok;
  }

  /// Called on every edit: live-revalidate once the step was attempted,
  /// otherwise just clear a stale (e.g. server) error for that field.
  void _onEdited(String field) {
    setState(() {
      final error = _attempted.contains(_Step.ofField(field)) ? _validate(field) : null;
      if (error == null) {
        _errors.remove(field);
      } else {
        _errors[field] = error;
      }
      // Changing the password can fix or break the confirmation match.
      if (field == 'password' && _confirm.text.isNotEmpty && _attempted.contains(_Step.security)) {
        final c = _validate('password_confirmation');
        c == null ? _errors.remove('password_confirmation') : _errors['password_confirmation'] = c;
      }
    });
  }

  /// Puts server-side 422 errors on their fields and jumps to the earliest
  /// step that has one. Returns false when there were no field errors.
  bool _applyServerErrors(ApiResult result) {
    final fields = result.errors?.keys.toList() ?? const [];
    if (fields.isEmpty) return false;
    setState(() {
      for (final f in fields) {
        final msg = result.fieldError(f);
        if (msg != null) _errors[f] = msg;
      }
      final earliest = fields.map(_Step.ofField).reduce((a, b) => a.index <= b.index ? a : b);
      if (earliest != _step) _goTo(earliest);
    });
    return true;
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _goTo(_Step step) {
    FocusManager.instance.primaryFocus?.unfocus();
    _forward = step.index > _step.index;
    _step = step;
  }

  Future<void> _continue() async {
    if (_busy || !_validateStep(_step)) return;

    switch (_step) {
      case _Step.personal:
        setState(() => _goTo(_Step.contact));
      case _Step.contact:
        await _checkContact();
      case _Step.security:
        await _createAccount();
    }
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_step != _Step.personal) {
      setState(() => _goTo(_Step.values[_step.index - 1]));
      return;
    }
    final dirty = _firstName.text.isNotEmpty || _lastName.text.isNotEmpty || _birthday != null;
    if (dirty) {
      final leave = await PsDialog.confirm(
        context,
        title: 'Leave registration?',
        message: 'The details you’ve entered won’t be saved.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!leave || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(fadeRoute(const LoginPage()));
  }

  // ── API calls ────────────────────────────────────────────────────────────

  Future<void> _checkContact() async {
    setState(() => _busy = true);
    final result = await _auth.checkContact(
      email: _email.text.trim(),
      contactNo: PsPhoneField.toLocalFormat(_mobileDigits),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      setState(() => _goTo(_Step.security));
    } else if (!_applyServerErrors(result)) {
      await _showRequestError(result);
    }
  }

  Future<void> _createAccount() async {
    setState(() => _busy = true);
    final b = _birthday!;
    final result = await _auth.register(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      birthday: '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
      email: _email.text.trim(),
      contactNo: PsPhoneField.toLocalFormat(_mobileDigits),
      password: _password.text,
      passwordConfirmation: _confirm.text,
      acceptedTerms: _acceptedTerms,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      final data = result.data!;
      Navigator.of(context).pushReplacement(
        fadeRoute(EmailVerificationPage(
          email: data['email']?.toString() ?? _email.text.trim(),
          maskedEmail: data['masked_email']?.toString(),
          expiresIn: Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 300),
          resendIn: Duration(seconds: (data['resend_in'] as num?)?.toInt() ?? 60),
        )),
      );
    } else if (!_applyServerErrors(result)) {
      await _showRequestError(result, title: 'Couldn’t create your account');
    }
  }

  Future<void> _showRequestError(ApiResult result, {String? title}) {
    return PsDialog.error(
      context,
      title: result.isNetworkError ? 'Can’t reach Picksell' : (title ?? 'Something went wrong'),
      message: result.message,
      actionLabel: 'OK',
    );
  }

  /// Terms / Privacy text published from the admin panel.
  Future<void> _showLegal(String title) async {
    final result = await _auth.legal(title == 'Terms of Service' ? 'terms' : 'privacy');
    if (!mounted) return;
    final body = '${result.data?['body'] ?? ''}'.trim();
    PsBottomSheet.show<void>(
      context,
      title: title,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.lg),
        child: Text(
          !result.success ? result.message : (body.isEmpty ? 'The $title hasn’t been published yet.' : body),
          style: PsText.body.copyWith(height: 1.6),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AutofillGroup(
        child: PsAppShell(
          topBar: PsTopBar.brand(
            onBack: _back,
            bottom: PsStepProgress(
              step: _step.index + 1,
              total: _Step.values.length,
              label: _step.label,
            ),
          ),
          footer: PsFooterActions(
            showDivider: _step != _Step.personal,
            primary: PsPrimaryButton(
              label: _step == _Step.security ? 'Create account' : 'Continue',
              loading: _busy,
              onPressed: _continue,
            ),
            secondary: _step == _Step.personal
                ? _LoginPrompt(onLogin: _goToLogin)
                : PsSecondaryButton(label: 'Back', expand: true, onPressed: _busy ? null : _back),
          ),
          body: AnimatedSwitcher(
            duration: PsMotion.normal,
            switchInCurve: PsMotion.curve,
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(_step);
              final dx = (incoming == _forward) ? 0.08 : -0.08;
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.lg, PsSpace.gutter, PsSpace.lg),
                children: [
                  Text(_step.title, style: PsText.display),
                  const SizedBox(height: PsSpace.xs),
                  Text(_step.subtitle, style: PsText.subtitle),
                  const SizedBox(height: PsSpace.xl),
                  ..._stepFields(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepFields() {
    const gap = SizedBox(height: 22);
    switch (_step) {
      case _Step.personal:
        final now = DateTime.now();
        return [
          PsTextField(
            label: 'First Name',
            hint: 'e.g. Juan',
            controller: _firstName,
            errorText: _errors['first_name'],
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            maxLength: 100,
            onChanged: (_) => _onEdited('first_name'),
            onSubmitted: (_) => _lastNameFocus.requestFocus(),
          ),
          gap,
          PsTextField(
            label: 'Last Name',
            hint: 'e.g. Dela Cruz',
            controller: _lastName,
            focusNode: _lastNameFocus,
            errorText: _errors['last_name'],
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            textInputAction: TextInputAction.done,
            maxLength: 100,
            onChanged: (_) => _onEdited('last_name'),
          ),
          gap,
          PsDateField(
            label: 'Date of Birth',
            value: _birthday,
            errorText: _errors['birthday'],
            helpText: 'Select your date of birth',
            lastDate: now,
            initialDate: DateTime(now.year - PsValidators.minimumAge, now.month, now.day),
            onChanged: (d) {
              _birthday = d;
              // Age is checked immediately so an under-18 date is flagged
              // right away, as in the design.
              _attempted.add(_Step.personal);
              _onEdited('birthday');
            },
          ),
        ];

      case _Step.contact:
        return [
          PsTextField(
            label: 'Email',
            hint: 'name@example.com',
            controller: _email,
            errorText: _errors['email'],
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            onChanged: (_) => _onEdited('email'),
            onSubmitted: (_) => _mobileFocus.requestFocus(),
          ),
          gap,
          PsPhoneField(
            controller: _mobile,
            focusNode: _mobileFocus,
            errorText: _errors['contact_no'],
            onChanged: (_) => _onEdited('contact_no'),
            onSubmitted: (_) => _continue(),
          ),
        ];

      case _Step.security:
        return [
          PsTextField(
            label: 'Password',
            hint: 'Create a password',
            controller: _password,
            obscure: true,
            errorText: _errors['password'],
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _onEdited('password'),
            onSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          PsPasswordChecklist(password: _password.text),
          gap,
          PsTextField(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            controller: _confirm,
            focusNode: _confirmFocus,
            obscure: true,
            errorText: _errors['password_confirmation'],
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _onEdited('password_confirmation'),
          ),
          const SizedBox(height: PsSpace.md),
          PsCheckboxTile(
            value: _acceptedTerms,
            errorText: _errors['terms'],
            onChanged: (v) {
              _acceptedTerms = v;
              _onEdited('terms');
            },
            label: [
              'I agree to the ',
              PsInlineLink('Terms of Service', () => _showLegal('Terms of Service')),
              ' and ',
              PsInlineLink('Privacy Policy', () => _showLegal('Privacy Policy')),
            ],
          ),
        ];
    }
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Already have an account?', style: PsText.bodyMuted),
        PsSecondaryButton(label: 'Log in', onPressed: onLogin),
      ],
    );
  }
}
