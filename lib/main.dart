import 'package:flutter/material.dart';

import 'app_colors.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
      ),
      home: const SplashPage(),
    );
  }
}
