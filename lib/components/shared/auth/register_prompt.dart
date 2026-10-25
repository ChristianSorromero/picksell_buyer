import 'package:flutter/material.dart';

import '../../../app_text_styles.dart';

/// "Don't have an account? Register here"
class RegisterPrompt extends StatelessWidget {
  const RegisterPrompt({super.key, required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: AppTextStyles.small),
        GestureDetector(
          onTap: onRegister,
          behavior: HitTestBehavior.opaque,
          child: Text('Register here', style: AppTextStyles.link),
        ),
      ],
    );
  }
}
