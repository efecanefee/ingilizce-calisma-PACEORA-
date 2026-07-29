import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/constants.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/providers.dart';
import 'data/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: PaceoraApp(onboardingDone: onboardingDone),
    ),
  );
}

class PaceoraApp extends ConsumerStatefulWidget {
  const PaceoraApp({super.key, required this.onboardingDone});

  final bool onboardingDone;

  @override
  ConsumerState<PaceoraApp> createState() => _PaceoraAppState();
}

class _PaceoraAppState extends ConsumerState<PaceoraApp>
    with WidgetsBindingObserver {
  late final _router = createRouter(onboardingDone: widget.onboardingDone);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka planda gece yarısını geçmiş olabilir; öne geldiğinde
    // "bugün" yeniden hesaplanmazsa dünün planı ekranda kalır.
    if (state == AppLifecycleState.resumed) {
      ref.read(weekPlanProvider.notifier).refreshIfDayChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
