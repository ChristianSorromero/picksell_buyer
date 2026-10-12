import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import 'page_dots.dart';
import 'primary_button.dart';

/// Shared layout for landing pages 1 and 2:
/// Skip → illustration → title → description → dots → Continue.
class OnboardingTemplate extends StatelessWidget {
  const OnboardingTemplate({
    super.key,
    required this.illustration,
    required this.title,
    required this.description,
    required this.currentIndex,
    required this.onSkip,
    required this.onContinue,
  });

  final Widget illustration;
  final String title;
  final String description;

  /// Zero-based index used to highlight the active progress dot.
  final int currentIndex;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(48, 36),
                  ),
                  child: Text('Skip', style: AppTextStyles.skip),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: illustration,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Text(description, style: AppTextStyles.body),
                  ),
                  const SizedBox(height: 28),
                  PageDots(currentIndex: currentIndex),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Continue',
                    showArrow: true,
                    onPressed: onContinue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
