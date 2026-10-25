import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../page_transitions.dart';
import '../components/shared/placeholder_image.dart';
import '../components/shared/ps_buttons.dart';
import '../components/shared/auth/register_prompt.dart';
import '../components/shared/auth/social_button.dart';
import 'login.dart';
import 'register.dart';

class LandingPage3 extends StatelessWidget {
  const LandingPage3({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final heroSize = size.width * 0.125;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Product collage (top ~62% of the screen).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.62,
            child: const _Collage(),
          ),
          // White fade so the title stays readable over the collage.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(0),
                    Colors.white.withAlpha(215),
                    Colors.white,
                  ],
                  stops: const [0.2, 0.45, 0.66],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 3),
                        Text(
                          'PICK.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.hero.copyWith(fontSize: heroSize),
                        ),
                        Text(
                          'SELL.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.hero.copyWith(fontSize: heroSize),
                        ),
                        Text(
                          'REPEAT.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.hero.copyWith(
                            fontSize: heroSize,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              'Join PickSell and start shopping smarter today.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        PsPrimaryButton(
                          label: 'Login',
                          onPressed: () => Navigator.of(context)
                              .push(fadeRoute(const LoginPage())),
                        ),
                        const SizedBox(height: 20),
                        const OrContinueWith(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: SocialButton.google(
                                label: 'Google',
                                height: 44,
                                onPressed: () =>
                                    _comingSoon(context, 'Google sign-in'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SocialButton.facebook(
                                label: 'Facebook',
                                height: 44,
                                onPressed: () =>
                                    _comingSoon(context, 'Facebook sign-in'),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        RegisterPrompt(
                          onRegister: () => Navigator.of(context)
                              .push(fadeRoute(const RegisterPage())),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3-column staggered grid of product placeholders.
/// Swap images by adding files to AppAssets.collage.
class _Collage extends StatelessWidget {
  const _Collage();

  Widget _tile(int flex, int index) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: PlaceholderImage(
          assetPath: AppAssets.collage[index],
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _tile(3, 0),
              _tile(4, 1),
              _tile(3, 2),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _tile(5, 3),
              _tile(5, 4),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _tile(3, 5),
              _tile(4, 6),
              _tile(3, 7),
            ],
          ),
        ),
      ],
    );
  }
}