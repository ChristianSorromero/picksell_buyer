import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_assets.dart';
import '../components/components.dart';
import '../components/shared/auth/waterfall_product_carousel.dart';
import '../page_transitions.dart';
import 'login.dart';
import 'register.dart';

/// Where a signed-out buyer chooses: log in or create an account. Behind
/// everything, three columns of product cards flow continuously (the login
/// page's waterfall, in its card style); a fade keeps the actions readable.
/// The content rises in once on arrival.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _rise(double begin, Widget child) {
    final a = CurvedAnimation(parent: _intro, curve: Interval(begin, (begin + 0.5).clamp(0, 1), curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (_, c) => Opacity(opacity: a.value, child: Transform.translate(offset: Offset(0, 24 * (1 - a.value)), child: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroSize = (size.width * 0.115).clamp(34.0, 52.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PsColors.background,
        body: Stack(
          children: [
            // Three continuous columns of product cards, a little wider than
            // the screen so the outer columns peek in from the edges.
            Positioned(
              top: -40,
              left: -28,
              right: -28,
              height: size.height * 0.72,
              child: const WaterfallProductCarousel(
                laneCount: 3,
                style: WaterfallTileStyle.card,
                duration: Duration(seconds: 30),
              ),
            ),
            // Fade from the waterfall into the page.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        PsColors.background.withAlpha(0),
                        PsColors.background.withAlpha(0),
                        PsColors.background.withAlpha(235),
                        PsColors.background,
                      ],
                      stops: const [0, 0.32, 0.56, 0.66],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Brand at the top, on a soft white pill so it reads over the cards.
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.sm),
                    child: _rise(
                      0,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: PsColors.surface.withAlpha(235),
                          borderRadius: BorderRadius.circular(PsRadius.pill),
                          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
                        ),
                        child: Image.asset(AppAssets.logo, height: 26, errorBuilder: (_, __, ___) => const Text('PickSell')),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter + 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rise(
                          0.1,
                          Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'PICK. SELL.\n'),
                              TextSpan(text: 'REPEAT.', style: TextStyle(color: PsColors.primary)),
                            ]),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontSize: heroSize, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1, color: PsColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: PsSpace.md),
                        _rise(
                          0.2,
                          Text(
                            'Shop from sellers across the Philippines, pay cash on delivery, and track every parcel.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.openSans(fontSize: 14, height: 1.5, color: PsColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: PsSpace.xl),
                        _rise(
                          0.3,
                          PsPrimaryButton(
                            label: 'Log in',
                            onPressed: () => Navigator.of(context).push(fadeRoute(const LoginPage())),
                          ),
                        ),
                        const SizedBox(height: PsSpace.md),
                        _rise(
                          0.36,
                          SizedBox(
                            height: PsSize.buttonHeight,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).push(fadeRoute(const RegisterPage())),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PsColors.textPrimary,
                                backgroundColor: PsColors.surface,
                                side: BorderSide(color: PsColors.textPrimary, width: 1.4),
                                shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
                              ),
                              child: Text('Create an account', style: PsText.button.copyWith(letterSpacing: 0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: PsSpace.xl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
