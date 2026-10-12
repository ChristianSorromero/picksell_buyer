import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/register_prompt.dart';
import '../widgets/social_button.dart';
import 'buyer_dashboard.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _authService = AuthService();
  final _session = SessionManager();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what coming soon')));
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please enter email and password')));
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.login(email: email, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
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
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const BuyerDashboardPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                    const SizedBox(height: 32),
                    // Replace with your logo (AppAssets.logo).
                    const Center(
                      child: Image(
                        image: AssetImage(AppAssets.logo),
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          'Log in to continue shopping and manage your orders.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.small,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('EMAIL ADDRESS', style: AppTextStyles.fieldLabel),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _emailController,
                      hint: 'name@example.com',
                      icon: Icons.mail_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text('PASSWORD', style: AppTextStyles.fieldLabel),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _comingSoon('Password reset'),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'Forgot Password?',
                            style: AppTextStyles.linkSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _passwordController,
                      hint: '••••••••••••',
                      icon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        splashRadius: 18,
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Login',
                      showArrow: true,
                      elevated: true,
                      onPressed: _isLoading ? null : _login,
                    ),
                    const SizedBox(height: 22),
                    const OrContinueWith(),
                    const SizedBox(height: 16),
                    SocialButton.google(
                      label: 'Continue with Google',
                      onPressed: () => _comingSoon('Google sign-in'),
                    ),
                    const SizedBox(height: 12),
                    SocialButton.facebook(
                      label: 'Continue with Facebook',
                      onPressed: () => _comingSoon('Facebook sign-in'),
                    ),
                    const SizedBox(height: 24),
                    RegisterPrompt(
                      onRegister: () => Navigator.of(context)
                          .push(fadeRoute(const RegisterPage())),
                    ),
                    const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppTextStyles.input,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.hint,
        filled: true,
        fillColor: AppColors.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}