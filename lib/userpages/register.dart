import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/components.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import 'buyer/orders/evidence_picker.dart';
import 'email_verification_page.dart';
import 'login.dart';

/// Buyer registration, the same flow as the website's sign-up:
///   1. Personal Information — name, date of birth (18+), sex
///   2. Contact Information  — email + PH mobile; the email is proven with
///      a six-digit code ([EmailVerificationPage]) before going on
///   3. Address and ID       — delivery address (PSGC) and a valid ID photo
///   4. Security and Consent — password rules, terms, accuracy confirmation
/// The account is then created as pending until an admin approves it.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

enum _Step {
  personal('Personal Information', 'Create your account', 'Let’s start with your personal information.'),
  contact('Contact Information', 'Your contact details', 'We’ll send a code to verify your email.'),
  address('Address and ID', 'Address and valid ID', 'We deliver to this address. Admins check your ID before approving your account.'),
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
      case 'middle_initial':
      case 'birthday':
      case 'sex':
        return personal;
      case 'email':
      case 'contact_no':
      case 'registration_token':
        return contact;
      case 'province':
      case 'municipality':
      case 'barangay':
      case 'street':
      case 'house_no':
      case 'id_upload':
        return address;
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
  final _middleInitial = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _birthday;
  String? _sex;

  // Step 2
  final _email = TextEditingController();
  final _mobile = TextEditingController();

  /// From the verified email code; tied to [_verifiedEmail].
  String? _registrationToken;
  String? _verifiedEmail;

  // Step 3 — kept here because the step's widgets are rebuilt when it reappears.
  final _addressKey = GlobalKey<PsAddressFieldsState>();
  String _province = '';
  String _municipality = '';
  String _barangay = '';
  String? _street;
  String? _houseNo;
  List<String> _idPhoto = [];

  // Step 4
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acceptedTerms = false;
  bool _confirmedAccurate = false;

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
    for (final c in [_firstName, _middleInitial, _lastName, _email, _mobile, _password, _confirm]) {
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
      case 'sex':
        return _sex == null ? 'Select your sex.' : null;
      case 'email':
        return PsValidators.email(_email.text);
      case 'contact_no':
        return PsValidators.phMobile(_mobileDigits);
      case 'id_upload':
        return _idPhoto.isEmpty ? 'Upload a photo of a valid ID.' : null;
      case 'password':
        return PsValidators.password(_password.text);
      case 'password_confirmation':
        return PsValidators.confirmPassword(_confirm.text, _password.text);
      case 'terms':
        return _acceptedTerms ? null : 'Please agree to the Terms of Service and Privacy Policy.';
      case 'confirmed':
        return _confirmedAccurate ? null : 'Confirm that your information and ID are accurate.';
    }
    return null;
  }

  static const Map<_Step, List<String>> _fields = {
    _Step.personal: ['first_name', 'last_name', 'birthday', 'sex'],
    _Step.contact: ['email', 'contact_no'],
    _Step.address: ['id_upload'],
    _Step.security: ['password', 'password_confirmation', 'terms', 'confirmed'],
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
    if (step == _Step.address) {
      final addressOk = _addressKey.currentState?.validate() ?? false;
      ok = ok && addressOk;
    }
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
        if (msg == null) continue;
        // A stale or used code token: verify the email again.
        if (f == 'registration_token' || (f == 'email' && msg.contains('6-digit code'))) {
          _registrationToken = null;
          _errors['email'] = 'Verify your email again to continue.';
        } else {
          _errors[f] = msg;
        }
      }
      final earliest = fields.map(_Step.ofField).reduce((a, b) => a.index <= b.index ? a : b);
      if (earliest != _step) _goTo(earliest);
    });
    return true;
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _goTo(_Step step) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == _Step.address) _keepAddress();
    _forward = step.index > _step.index;
    _step = step;
  }

  void _keepAddress() {
    final a = _addressKey.currentState;
    if (a == null) return;
    _province = a.province;
    _municipality = a.municipality;
    _barangay = a.barangay;
    _street = a.street;
    _houseNo = a.houseNo;
  }

  Future<void> _continue() async {
    if (_busy || !_validateStep(_step)) return;

    switch (_step) {
      case _Step.personal:
        setState(() => _goTo(_Step.contact));
      case _Step.contact:
        await _checkContactAndVerify();
      case _Step.address:
        setState(() => _goTo(_Step.security));
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

  Future<void> _checkContactAndVerify() async {
    final email = _email.text.trim().toLowerCase();
    setState(() => _busy = true);
    final check = await _auth.checkContact(email: email, contactNo: PsPhoneField.toLocalFormat(_mobileDigits));
    if (!mounted) return;
    if (!check.success) {
      setState(() => _busy = false);
      if (!_applyServerErrors(check)) await _showRequestError(check);
      return;
    }

    // Already proven in this sign-up: don't send another code.
    if (_registrationToken != null && _verifiedEmail == email) {
      setState(() {
        _busy = false;
        _goTo(_Step.address);
      });
      return;
    }

    final sent = await _auth.sendRegistrationCode(email: email, firstName: _firstName.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!sent.success && sent.statusCode != 429) {
      if (!_applyServerErrors(sent)) await _showRequestError(sent, title: 'Couldn’t send the code');
      return;
    }

    final data = sent.data ?? const {};
    final token = await Navigator.of(context).push<String>(fadeRoute(EmailVerificationPage(
      email: email,
      firstName: _firstName.text.trim(),
      maskedEmail: data['masked_email']?.toString(),
      expiresIn: Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 300),
      resendIn: Duration(seconds: (data['resend_in'] as num?)?.toInt() ?? 60),
    )));
    if (!mounted || token == null) return;
    setState(() {
      _registrationToken = token;
      _verifiedEmail = email;
      _errors.remove('email');
      _goTo(_Step.address);
    });
  }

  Future<void> _createAccount() async {
    final token = _registrationToken;
    if (token == null || _verifiedEmail != _email.text.trim().toLowerCase()) {
      setState(() {
        _errors['email'] = 'Verify your email to continue.';
        _goTo(_Step.contact);
      });
      return;
    }
    setState(() => _busy = true);
    final b = _birthday!;
    final middle = _middleInitial.text.trim();
    final result = await _auth.register(
      registrationToken: token,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      middleInitial: middle.isEmpty ? null : middle,
      sex: _sex!,
      birthday: '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
      email: _verifiedEmail!,
      contactNo: PsPhoneField.toLocalFormat(_mobileDigits),
      province: _province,
      municipality: _municipality,
      barangay: _barangay,
      street: _street,
      houseNo: _houseNo,
      idPhoto: _idPhoto.first,
      password: _password.text,
      passwordConfirmation: _confirm.text,
      acceptedTerms: _acceptedTerms,
      confirmedAccurate: _confirmedAccurate,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(fadeRoute(_RegistrationSubmittedPage(message: result.message)));
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
              label: switch (_step) {
                _Step.contact => _registrationToken != null && _verifiedEmail == _email.text.trim().toLowerCase() ? 'Continue' : 'Send code',
                _Step.security => 'Submit registration',
                _ => 'Continue',
              },
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
            maxLength: 50,
            onChanged: (_) => _onEdited('first_name'),
            onSubmitted: (_) => _lastNameFocus.requestFocus(),
          ),
          gap,
          PsTextField(
            label: 'Middle Initial',
            hint: 'Optional',
            controller: _middleInitial,
            errorText: _errors['middle_initial'],
            textCapitalization: TextCapitalization.characters,
            maxLength: 5,
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
            maxLength: 50,
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
              // Age is checked immediately so an under-18 date is flagged right away.
              _attempted.add(_Step.personal);
              _onEdited('birthday');
            },
          ),
          gap,
          const PsFieldLabel('Sex'),
          Wrap(
            spacing: PsSpace.xs,
            children: [
              for (final s in const ['Male', 'Female'])
                PsOptionChip(
                  label: s,
                  selected: _sex == s,
                  onTap: () {
                    _sex = s;
                    _onEdited('sex');
                  },
                ),
            ],
          ),
          if (_errors['sex'] != null) PsFieldError(_errors['sex']!),
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
          if (_registrationToken != null && _verifiedEmail == _email.text.trim().toLowerCase())
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: PsColors.success),
                  const SizedBox(width: 4),
                  Text('Email verified', style: PsText.caption.copyWith(color: PsColors.success, fontWeight: FontWeight.w600)),
                ],
              ),
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

      case _Step.address:
        return [
          PsAddressFields(
            key: _addressKey,
            province: _province,
            municipality: _municipality,
            barangay: _barangay,
            street: _street,
            houseNo: _houseNo,
            errors: _errors,
          ),
          gap,
          const PsFieldLabel('Valid ID'),
          Padding(
            padding: const EdgeInsets.only(bottom: PsSpace.xs),
            child: Text('A clear photo of a government-issued ID. Only PickSell admins see it.', style: PsText.caption),
          ),
          EvidencePicker(
            paths: _idPhoto,
            max: 1,
            onChanged: (p) {
              _idPhoto = p;
              _onEdited('id_upload');
            },
          ),
          if (_errors['id_upload'] != null) PsFieldError(_errors['id_upload']!),
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
          const SizedBox(height: PsSpace.xs),
          PsCheckboxTile(
            value: _confirmedAccurate,
            errorText: _errors['confirmed'],
            onChanged: (v) {
              _confirmedAccurate = v;
              _onEdited('confirmed');
            },
            label: const ['I confirm that my information and ID are accurate.'],
          ),
        ];
    }
  }
}

/// Shown after sign-up: like the website, the account waits for an admin.
class _RegistrationSubmittedPage extends StatelessWidget {
  const _RegistrationSubmittedPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar.brand(showBack: false),
      footer: PsFooterActions(
        primary: PsPrimaryButton(
          label: 'Back to log in',
          onPressed: () => Navigator.of(context).pushReplacement(fadeRoute(const LoginPage())),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xl, PsSpace.gutter, PsSpace.lg),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: PsColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded, size: 44, color: PsColors.primary),
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          Text('Registration submitted', textAlign: TextAlign.center, style: PsText.display),
          const SizedBox(height: PsSpace.sm),
          Text(
            message.isEmpty ? 'Please wait for admin approval. You will be notified via email.' : message,
            textAlign: TextAlign.center,
            style: PsText.subtitle,
          ),
          const SizedBox(height: PsSpace.md),
          Text(
            'An admin checks your ID first. Once approved, log in with your email and password.',
            textAlign: TextAlign.center,
            style: PsText.caption,
          ),
        ],
      ),
    );
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
