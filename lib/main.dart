import 'package:flutter/material.dart';

import 'core/theme/ps_theme.dart';
import 'userpages/splash_page.dart';

void main() {
  runApp(const PickSellApp());
}

class PickSellApp extends StatelessWidget {
  const PickSellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickSell',
      debugShowCheckedModeBanner: false,
      theme: PsTheme.light,
      home: const SplashPage(),
    );
  }
}
