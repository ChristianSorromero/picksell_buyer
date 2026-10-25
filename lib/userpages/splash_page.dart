import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';

import '../app_assets.dart';
import '../app_colors.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import '../components/shared/placeholder_image.dart';
import 'buyer/buyer_shell.dart';
import 'landing_page1.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final isLoggedIn = await SessionManager().isLoggedIn();
    if (!mounted) return;
    final dest = isLoggedIn ? const BuyerDashboardPage() : const LandingPage1();
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(dest), (_) => false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Replace with your logo mark (AppAssets.splashLogo).
              const PlaceholderImage(
                assetPath: AppAssets.splashLogo,
                icon: Icons.storefront_rounded,
                width: 160,
                height: 180,
                backgroundColor: Colors.white10,
                iconColor: AppColors.brandOrange,
                iconSize: 70,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              const SizedBox(height: 8),
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(
                      text: 'PICK',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'SELL',
                      style: TextStyle(color: AppColors.brandOrange),
                    ),
                  ],
                ),
                style: GoogleFonts.poppins(
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
