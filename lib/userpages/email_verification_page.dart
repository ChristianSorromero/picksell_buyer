import 'dart:async';

import 'package:flutter/material.dart';

import '../components/components.dart';
import '../services/auth_service.dart';

/// Figma "Buyer Registration" — enter the six-digit code emailed during
/// sign-up. As on the website, a correct code only proves the email: the
/// page pops with the registration token and the form continues.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.firstName,
    this.maskedEmail,
    this.expiresIn = const Duration(minutes: 5),
    this.resendIn = const Duration(seconds: 60),
  });

  final String email;
  final String? firstName;

  /// "j***e@gmail.com" from the API; falls back to [email].
  final String? maskedEmail;
  final Duration expiresIn;
  final Duration resendIn;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  static const _codeLength = 6;

  final _auth = AuthService();
  final _code = TextEditingController();

  late DateTime _expiresAt = DateTime.now().add(widget.expiresIn);
  late DateTime _resendAt = DateTime.now().add(widget.resendIn);
  Timer? _ticker;

  String? _error;
  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Duration get _expiresLeft => _remaining(_expiresAt);
  Duration get _resendLeft => _remaining(_resendAt);

  static Duration _remaining(DateTime t) {
    final d = t.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  static String _clock(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  bool get _expired => _expiresLeft == Duration.zero;

  Future<void> _verify() async {
    if (_verifying) return;
    final invalid = PsValidators.otp(_code.text, length: _codeLength);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    if (_expired) {
      setState(() => _error = 'This code has expired. Tap Resend Code to get a new one.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });

    final result = await _auth.verifyRegistrationCode(email: widget.email, code: _code.text);
    if (!mounted) return;

    final token = result.data?['registration_token'] as String?;
    if (!result.success || token == null) {
      setState(() => _verifying = false);
      if (result.isNetworkError) {
        await PsDialog.error(context, title: 'Can’t reach Picksell', message: result.message);
      } else {
        setState(() => _error = result.fieldError('code') ?? result.message);
      }
      return;
    }

    PsToast.success(context, 'Email verified');
    Navigator.of(context).pop(token);
  }

  Future<void> _resend() async {
    if (_resending || _resendLeft > Duration.zero) return;
    setState(() => _resending = true);

    final result = await _auth.sendRegistrationCode(email: widget.email, firstName: widget.firstName);
    if (!mounted) return;
    setState(() => _resending = false);

    final resendIn = (result.data?['resend_in'] as num?)?.toInt();
    if (result.success) {
      setState(() {
        _code.clear();
        _error = null;
        _expiresAt = DateTime.now().add(Duration(seconds: (result.data?['expires_in'] as num?)?.toInt() ?? 300));
        _resendAt = DateTime.now().add(Duration(seconds: resendIn ?? 60));
      });
      PsToast.success(context, result.message);
    } else if (result.statusCode == 429 && resendIn != null) {
      setState(() => _resendAt = DateTime.now().add(Duration(seconds: resendIn)));
      PsToast.show(context, result.message);
    } else if (result.isNetworkError) {
      await PsDialog.error(context, title: 'Can’t reach Picksell', message: result.message);
    } else {
      await PsDialog.error(context, title: 'Couldn’t resend the code', message: result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar.brand(showBack: false),
      footer: PsFooterActions(
        primary: PsPrimaryButton(
          label: 'Verify',
          loading: _verifying,
          onPressed: _code.text.length == _codeLength ? _verify : null,
        ),
        secondary: PsSecondaryButton(
          label: 'Change email',
          expand: true,
          onPressed: _verifying ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.lg, PsSpace.gutter, PsSpace.lg),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: PsColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_rounded, size: 44, color: PsColors.primary),
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          Text('Verify your email', textAlign: TextAlign.center, style: PsText.display),
          const SizedBox(height: PsSpace.sm),
          Text.rich(
            TextSpan(
              text: 'We’ve sent a six-digit verification code to\n',
              children: [
                TextSpan(
                  text: widget.maskedEmail ?? widget.email,
                  style: PsText.bodyStrong,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: PsText.subtitle,
          ),
          const SizedBox(height: PsSpace.xl),
          PsOtpInput(
            controller: _code,
            length: _codeLength,
            hasError: _error != null,
            enabled: !_verifying,
            onChanged: (_) => setState(() => _error = null),
            onCompleted: (_) => _verify(),
          ),
          if (_error != null) PsFieldError(_error!),
          const SizedBox(height: PsSpace.lg),
          _ExpiryRow(expired: _expired, left: _clock(_expiresLeft)),
          const SizedBox(height: PsSpace.xs),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Didn’t receive the code?', style: PsText.bodyMuted),
              TextButton(
                onPressed: _resendLeft > Duration.zero || _resending ? null : _resend,
                style: TextButton.styleFrom(
                  foregroundColor: PsColors.primaryStrong,
                  disabledForegroundColor: PsColors.textHint,
                  minimumSize: const Size(PsSize.minTap, PsSize.minTap),
                  textStyle: PsText.link.copyWith(decoration: TextDecoration.underline),
                ),
                child: Text(
                  _resending
                      ? 'Sending…'
                      : _resendLeft > Duration.zero
                          ? 'Resend in ${_clock(_resendLeft)}'
                          : 'Resend Code',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.expired, required this.left});

  final bool expired;
  final String left;

  @override
  Widget build(BuildContext context) {
    final color = expired ? PsColors.error : PsColors.textSecondary;
    return Semantics(
      liveRegion: expired,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(expired ? Icons.timer_off_outlined : Icons.schedule_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Text.rich(
            expired
                ? const TextSpan(text: 'Code expired')
                : TextSpan(
                    text: 'Code expires in ',
                    children: [TextSpan(text: left, style: PsText.bodyStrong)],
                  ),
            style: PsText.body.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
