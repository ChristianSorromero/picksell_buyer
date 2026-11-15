import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_assets.dart';
import '../app_colors.dart';
import '../page_transitions.dart';
import '../services/auth_service.dart';
import '../services/onboarding_store.dart';
import 'buyer/buyer_shell.dart';
import 'onboarding_page.dart';
import 'welcome_page.dart';

/// Animated launch screen: a coral glow blooms, the P mark scales in, the
/// PICKSELL wordmark rises letter by letter, and a thin progress line runs
/// while the session is checked. Then: signed in → shop, first launch →
/// intro slides, otherwise → welcome page.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  @override
  void initState() {
    super.initState();
    _c.forward();
    _route();
  }

  Future<void> _route() async {
    // Work out the destination while the animation plays; leave when both are done.
    final results = await Future.wait([
      SessionManager().isLoggedIn(),
      OnboardingStore.seen(),
      Future<void>.delayed(const Duration(milliseconds: 2400)),
    ]);
    if (!mounted) return;
    final loggedIn = results[0] as bool;
    final seen = results[1] as bool;
    final Widget dest = loggedIn ? const BuyerDashboardPage() : (seen ? const WelcomePage() : const OnboardingPage());
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(dest), (_) => false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load the welcome waterfall's photos during the splash, so its cards
    // arrive filled instead of popping in.
    for (final path in AppAssets.loginWaterfall) {
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _c,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final glow = _interval(0.0, 0.55);
    final mark = _interval(0.08, 0.5, Curves.easeOutBack);
    final progress = _interval(0.35, 1.0, Curves.easeInOut);
    const word = 'PICKSELL';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                // Coral glow behind the mark.
                Center(
                  child: Opacity(
                    opacity: glow.value * 0.9,
                    child: Transform.scale(
                      scale: 0.6 + glow.value * 0.6,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [AppColors.brandOrange.withAlpha(110), AppColors.brandOrange.withAlpha(0)]),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: mark.value.clamp(0, 1),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * mark.value,
                          child: Image.asset(
                            AppAssets.splashLogo,
                            width: 150,
                            height: 170,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 80, color: AppColors.brandOrange),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < word.length; i++)
                            Builder(
                              builder: (_) {
                                final t = _interval(0.3 + i * 0.045, 0.62 + i * 0.045).value;
                                return Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                    offset: Offset(0, 14 * (1 - t)),
                                    child: Text(
                                      word[i],
                                      style: GoogleFonts.montserrat(
                                        fontSize: 35,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        color: i < 4 ? Colors.white : AppColors.brandOrange,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: _interval(0.65, 0.95).value,
                        child: Text(
                          'Shop smart. Buy fast.',
                          style: GoogleFonts.openSans(fontSize: 13, color: Colors.white70, letterSpacing: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Thin progress line near the bottom.
                Positioned(
                  bottom: 64 + MediaQuery.paddingOf(context).bottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 3,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: math.max(0.02, progress.value),
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.brandOrange, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
