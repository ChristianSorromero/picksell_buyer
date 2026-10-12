import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = false,
    this.elevated = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Adds a trailing arrow icon ("Continue →").
  final bool showArrow;

  /// Adds the soft coral glow used on the login button.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(90),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.button),
            if (showArrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
