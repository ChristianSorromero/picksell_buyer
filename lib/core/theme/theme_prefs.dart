import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The buyer's appearance choice (Account › Appearance): follow the phone,
/// or always light / always dark. Saved on the device.
class ThemePrefs {
  ThemePrefs._();

  static const _key = 'appearance';

  /// Listened to by the app root, which repaints every screen on change.
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// True while the buyer is signed out (welcome, log in, sign up, password
  /// reset): those pages are always light so the product waterfall looks
  /// right. The signed-in shell turns it off; [mode] applies from there.
  static final ValueNotifier<bool> signedOutLight = ValueNotifier(true);

  static Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      mode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      // No saved choice (or storage unavailable): follow the phone.
    }
  }

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  static String label(ThemeMode m) => switch (m) {
        ThemeMode.system => 'Same as phone',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
