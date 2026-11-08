import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_assets.dart';
import '../components/components.dart';
import '../components/shared/auth/register_prompt.dart';
import '../components/shared/auth/social_button.dart';
import '../components/shared/auth/waterfall_product_carousel.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import 'buyer/buyer_shell.dart';
import 'forgot_password_page.dart';
import 'register.dart';
import 'resubmit_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _authService = AuthService();
  final _session = SessionManager();

  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _comingSoon(String what) => PsToast.show(context, '$what coming soon');

  Future<void> _login() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = PsValidators.email(email);
      _passwordError = password.isEmpty ? 'Password is required.' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    final result = await _authService.login(email: email, password: password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      await _handleLoginError(result);
      return;
    }

    final user = result.data?['user'];
    final token = result.data?['token'];
    // Never enter the shell without a credential to send.
    if (user is! Map<String, dynamic> ||
        user['id'] is! int ||
        token is! String ||
        token.isEmpty) {
      await PsDialog.error(
        context,
        title: 'Couldn’t log you in',
        message: 'Unexpected server response. Please try again.',
      );
      return;
    }
    await _session.save(
      token: token,
      userId: user['id'] as int,
      name: user['name']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
    );

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadeRoute(const BuyerDashboardPage()), (_) => false);
  }

  Future<void> _handleLoginError(ApiResult result) async {
    final data = result.data ?? const {};

    // Turned down, with a way to fix it: replace the ID and resubmit the same account.
    if (result.statusCode == 403 && data['status'] == 'disapproved' && data['resubmit_token'] != null) {
      final fix = await PsDialog.confirm(
        context,
        title: 'Sign-up not approved',
        message: data['reason'] is String && (data['reason'] as String).isNotEmpty
            ? 'Reason: ${data['reason']}\n\nYou can fix it and resubmit it for review.'
            : 'You can fix your sign-up and resubmit it for review.',
        confirmLabel: 'Fix and resubmit',
        cancelLabel: 'Later',
        icon: Icons.assignment_late_outlined,
      );
      if (fix && mounted) {
        final sent = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => ResubmitPage.fromRefusal(_emailController.text.trim(), data)),
        );
        if (sent == true && mounted) PsToast.success(context, 'Resubmitted. We’ll email you after the review.');
      }
      return;
    }

    // Signed up but not approved yet (or refused): the website's account statuses.
    if (result.statusCode == 403 && data['status'] != null) {
      await PsDialog.error(
        context,
        title: data['status'] == 'pending'
            ? 'Waiting for approval'
            : 'Can’t log in',
        message: result.message,
      );
      return;
    }

    if (result.statusCode == 401) {
      setState(() => _passwordError = result.message);
      return;
    }
    if (result.statusCode == 422) {
      setState(() {
        _emailError = result.fieldError('email');
        _passwordError = result.fieldError('password');
      });
      if (_emailError != null || _passwordError != null) return;
    }

    await PsDialog.error(
      context,
      title: result.isNetworkError
          ? 'Can’t reach Picksell'
          : 'Couldn’t log you in',
      message: result.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: PsAppShell(
        body: Stack(
          children: [
            const Positioned.fill(
              child: Opacity(opacity: 0.28, child: WaterfallProductCarousel()),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x88FFFFFF),
                      Color(0xCCFFFFFF),
                      Color(0xEEF9F8F6),
                    ],
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(
                PsSpace.gutter,
                PsSpace.xl,
                PsSpace.gutter,
                PsSpace.md,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const Center(
                  child: Image(
                    image: AssetImage(AppAssets.logo),
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: PsSpace.lg),
                Text(
                  'Welcome back!',
                  textAlign: TextAlign.center,
                  style: PsText.display,
                ),
                const SizedBox(height: PsSpace.xs),
                Text(
                  'Log in to continue shopping and manage your orders.',
                  textAlign: TextAlign.center,
                  style: PsText.subtitle,
                ),
                const SizedBox(height: PsSpace.xl),
                PsTextField(
                  label: 'Email',
                  hint: 'name@example.com',
                  controller: _emailController,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 22),
                PsTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscure: true,
                  errorText: _passwordError,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  labelTrailing: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      fadeRoute(
                        ForgotPasswordPage(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Forgot password?',
                      style: PsText.link.copyWith(fontSize: 13),
                    ),
                  ),
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: PsSpace.lg),
                PsPrimaryButton(
                  label: 'Log in',
                  loading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: PsSpace.lg),
                const OrContinueWith(),
                const SizedBox(height: PsSpace.md),
                SocialButton.google(
                  label: 'Continue with Google',
                  onPressed: () => _comingSoon('Google sign-in'),
                ),
                const SizedBox(height: PsSpace.sm),
                SocialButton.facebook(
                  label: 'Continue with Facebook',
                  onPressed: () => _comingSoon('Facebook sign-in'),
                ),
                const SizedBox(height: PsSpace.lg),
                RegisterPrompt(
                  onRegister: () => Navigator.of(
                    context,
                  ).push(fadeRoute(const RegisterPage())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
