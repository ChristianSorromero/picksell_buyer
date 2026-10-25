import 'dart:async';

import 'package:flutter/material.dart';

import '../components/components.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import 'buyer/buyer_shell.dart';
import 'login.dart';

/// Figma "Buyer Registration" 4 — enter the six-digit code emailed after
/// sign-up (or after logging in to an unverified account). A correct code
/// activates the buyer account and signs them in.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.maskedEmail,
    this.expiresIn = const Duration(minutes: 5),
    this.resendIn = const Duration(seconds: 60),
  });

  final String email;

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
  final _session = SessionManager();
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

    final result = await _auth.verifyEmail(email: widget.email, code: _code.text);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _verifying = false);
      if (result.isNetworkError) {
        await PsDialog.error(context, title: 'Can’t reach Picksell', message: result.message);
      } else {
        setState(() => _error = result.fieldError('code') ?? result.message);
      }
      return;
    }

    final user = result.data?['user'] as Map<String, dynamic>?;
    final token = result.data?['token'] as String?;
    if (user != null && token != null) {
      await _session.save(
        token: token,
        userId: user['id'] as int,
        name: user['name']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
      );
    }
    if (!mounted) return;

    PsToast.success(context, result.message);
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const BuyerDashboardPage()), (_) => false);
  }

  Future<void> _resend() async {
    if (_resending || _resendLeft > Duration.zero) return;
    setState(() => _resending = true);

    final result = await _auth.resendCode(email: widget.email);
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
      await PsDialog.error(
        context,
        title: 'Couldn’t resend the code',
        message: result.message,
        secondaryLabel: 'Return to login',
        onSecondary: _returnToLogin,
      );
    }
  }

  void _returnToLogin() {
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const LoginPage()), (_) => false);
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
          label: 'Return to login',
          expand: true,
          onPressed: _verifying ? null : _returnToLogin,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
