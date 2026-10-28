import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/celebration.dart';
import 'app/constants.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/providers.dart';
import 'data/reminder_service.dart';
import 'data/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
  final reminders = await LocalReminderService.create();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      reminderServiceProvider.overrideWithValue(reminders),
    ],
  );
  // Saat dilimi ya da cihaz değişmiş olabilir; açık hatırlatma yeniden kurulur.
  container.read(reminderProvider.notifier).resync().ignore();

  runApp(
    UncontrolledProviderScope(
      container: container,
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
    // Titreşim tercihi uygulama genelindeki Haptics bayrağını günceller.
    ref.watch(hapticsProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      // Seviye/rozet kutlaması her ekranın üstünde gösterilebilsin.
      builder: (context, child) => CelebrationHost(child: child!),
      // Saat seçici, iletişim kutuları vb. sistem metinleri Türkçe olsun.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
