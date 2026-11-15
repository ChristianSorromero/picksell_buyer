import 'package:flutter/material.dart';

import 'core/theme/ps_colors.dart';
import 'core/theme/ps_theme.dart';
import 'core/theme/theme_prefs.dart';
import 'userpages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemePrefs.load();
  runApp(const PickSellApp());
}

/// Light or dark from the buyer's Appearance setting (default: the phone's).
/// Signed-out pages (welcome, log in, sign up) are always light.
/// Colors are read from [PsColors] while each screen builds, so a switch
/// repaints every open screen in place (navigation and form input are kept).
class PickSellApp extends StatefulWidget {
  const PickSellApp({super.key});

  @override
  State<PickSellApp> createState() => _PickSellAppState();
}

class _PickSellAppState extends State<PickSellApp> with WidgetsBindingObserver {
  bool get _wantDark => ThemePrefs.signedOutLight.value
      ? false
      : switch (ThemePrefs.mode.value) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemePrefs.mode.addListener(_apply);
    ThemePrefs.signedOutLight.addListener(_apply);
    PsColors.isDark = _wantDark;
  }

  @override
  void dispose() {
    ThemePrefs.mode.removeListener(_apply);
    ThemePrefs.signedOutLight.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  void _apply() {
    if (PsColors.isDark == _wantDark) return;
    setState(() => PsColors.isDark = _wantDark);
    // Screens built from const widgets don't rebuild on their own: mark every one.
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickSell',
      debugShowCheckedModeBanner: false,
      theme: PsColors.isDark ? PsTheme.dark : PsTheme.light,
      home: const SplashPage(),
    );
  }
}
