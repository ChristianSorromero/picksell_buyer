import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that the intro slides were seen, so they show once per install;
/// after that (and after logging out) the app opens on the welcome page.
class OnboardingStore {
  OnboardingStore._();

  static const _key = 'onboarding_seen';

  static Future<bool> seen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {}
  }
}
