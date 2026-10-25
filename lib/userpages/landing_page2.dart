import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../page_transitions.dart';
import '../components/shared/onboarding_template.dart';
import '../components/shared/placeholder_image.dart';
import 'landing_page3.dart';

class LandingPage2 extends StatelessWidget {
  const LandingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    void goToThree() =>
        Navigator.of(context).push(fadeRoute(const LandingPage3()));

    return OnboardingTemplate(
      currentIndex: 1,
      title: 'DISCOVER.\nUNIQUE FINDS.',
      description:
          'Explore a curated selection of products from top sellers around the Philippines.',
      illustration: const PlaceholderImage(
        assetPath: AppAssets.landing2,
        icon: Icons.shopping_cart_outlined,
        label: 'Illustration',
        borderRadius: BorderRadius.all(Radius.circular(32)),
      ),
      onSkip: goToThree,
      onContinue: goToThree,
    );
  }
}
