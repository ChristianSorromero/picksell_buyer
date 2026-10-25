/// Image paths used across the app.
///
/// Every image currently falls back to a placeholder. To replace one, drop your
/// file at the path below (and make sure `assets/images/` is declared in
/// pubspec.yaml) — no code changes needed. Or change the path here.
class AppAssets {
  AppAssets._();

  // Logos
  static const String splashLogo = 'assets/bpicksell_logo.png';
  static const String logo = 'assets/picksell_logo_long.png';

  /// Dark rounded-square "P" mark used in top bars.
  static const String brandMark = 'assets/picksell_bg.png';

  // Landing illustrations
  static const String landing1 = 'assets/landingpage1.png';
  static const String landing2 = 'assets/landingpage2.png';

  // Landing 3 collage tiles
  static const List<String> collage = [
    'assets/tiles/watch.jpg',
    'assets/tiles/headphones.jpg',
    'assets/tiles/bag.jpg',
    'assets/tiles/shoes.jpg',
    'assets/tiles/laptop.jpg',
    'assets/tiles/perfume.jpg',
    'assets/tiles/food.jpg',
    'assets/tiles/clothes.jpg',
    'assets/tiles/decor.jpg',
  ];
}
