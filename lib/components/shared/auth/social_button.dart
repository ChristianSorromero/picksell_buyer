import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app_colors.dart';
import '../../../app_text_styles.dart';

/// Multicolor Google "G".
class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const SweepGradient(
        colors: [
          AppColors.googleBlue,
          AppColors.googleBlue,
          AppColors.googleGreen,
          AppColors.googleGreen,
          AppColors.googleYellow,
          AppColors.googleYellow,
          AppColors.googleRed,
          AppColors.googleRed,
          AppColors.googleBlue,
          AppColors.googleBlue,
        ],
        stops: [0.0, 0.17, 0.17, 0.36, 0.36, 0.55, 0.55, 0.95, 0.95, 1.0],
      ).createShader(bounds),
      child: FaIcon(FontAwesomeIcons.google, size: size, color: Colors.white),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.white,
    this.textColor = AppColors.textPrimary,
    this.borderColor,
    this.height = 46,
  });

  /// Google button (white with border).
  const SocialButton.google({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 46,
  })  : icon = const GoogleIcon(),
        backgroundColor = Colors.white,
        textColor = AppColors.textPrimary,
        borderColor = AppColors.border;

  /// Facebook button (solid blue).
  const SocialButton.facebook({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 46,
  })  : icon = const FaIcon(
          FontAwesomeIcons.facebookF,
          size: 15,
          color: Colors.white,
        ),
        backgroundColor = AppColors.facebook,
        textColor = Colors.white,
        borderColor = null;

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: backgroundColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.socialButton.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "OR CONTINUE WITH" caption used above social buttons.
class OrContinueWith extends StatelessWidget {
  const OrContinueWith({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('OR CONTINUE WITH', style: AppTextStyles.caption),
    );
  }
}
