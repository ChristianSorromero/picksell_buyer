import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../page_transitions.dart';
import '../widgets/onboarding_template.dart';
import '../widgets/placeholder_image.dart';
import 'landing_page3.dart';
import 'landing_page2.dart';

class LandingPage1 extends StatelessWidget {
  const LandingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      currentIndex: 0,
      title: 'SHOP SMART.\nBUY FAST.',
      description:
          'Find the best products, deals, and sellers all in one place.',
      illustration: const PlaceholderImage(
        assetPath: AppAssets.landing1,
        icon: Icons.shopping_bag_outlined,
        label: 'Illustration',
        borderRadius: BorderRadius.all(Radius.circular(32)),
      ),
      // Skip jumps straight to the third landing page.
      onSkip: () =>
          Navigator.of(context).push(fadeRoute(const LandingPage3())),
      // Continue goes to the second landing page.
      onContinue: () =>
          Navigator.of(context).push(fadeRoute(const LandingPage2())),
    );
  }
}
