import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/celebration.dart';
import 'app/constants.dart';
import 'app/error_reporting.dart';
import 'app/mascot.dart';
import 'app/motion.dart';
import 'app/router.dart';
import 'app/sounds.dart';
import 'app/splash.dart';
import 'app/theme.dart';
import 'data/gemini_service.dart';
import 'data/providers.dart';
import 'data/reminder_service.dart';
import 'data/settings_providers.dart';
import 'data/streak_freeze.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Düzen dikey telefon ekranına göre: yatayda içerik sığmıyor.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Uygulamayla gelen Inter yazı tipinin lisansı "Açık kaynak lisansları"nda.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });
  final prefs = await SharedPreferences.getInstance();
  installErrorHandlers(ErrorLog(prefs));
  Sounds.useDevicePlayer();
  final onboardingDone =
      prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
  final reminders = await LocalReminderService.create();
  const storage = FlutterSecureStorage();
  final apiKey = await loadApiKey(prefs, storage);
  final firebase = await _startFirebase();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      reminderServiceProvider.overrideWithValue(reminders),
      storedApiKeyProvider.overrideWithValue(apiKey),
      firebaseBackendProvider.overrideWithValue(firebase),
    ],
  );
  // Saat dilimi ya da cihaz değişmiş olabilir; açık hatırlatma yeniden kurulur.
  container.read(reminderProvider.notifier).resync().ignore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PaceoraApp(onboardingDone: onboardingDone, showSplash: true),
    ),
  );
}

/// Firebase'i ve App Check'i başlatır; yapay zeka istekleri anahtarsız
/// Firebase AI Logic üzerinden gider. Başlatılamazsa (desteklenmeyen
/// platform, ağ, Play hizmetleri yok) null döner; uygulama kendi anahtarıyla
/// ya da hazır derslerle çalışmaya devam eder.
Future<GeminiBackend?> _startFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options == null) return null;
  try {
    await Firebase.initializeApp(options: options);
    // Hata ayıklama derlemesinde debug sağlayıcı: ilk açılışta logcat'e bir
    // jeton yazar, Firebase konsolunda App Check > Manage debug tokens'a
    // eklenir. Yayın derlemesinde Play Integrity / App Attest.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
    return GeminiBackend.firebase(
      projectId: options.projectId,
      apiKey: options.apiKey,
      appCheckToken: () => FirebaseAppCheck.instance.getToken(),
    );
  } catch (e) {
    debugPrint('Firebase başlatılamadı: $e');
    return null;
  }
}

class PaceoraApp extends ConsumerStatefulWidget {
  const PaceoraApp({
    super.key,
    required this.onboardingDone,
    this.showSplash = false,
  });

  final bool onboardingDone;

  /// Açılış animasyonu; yalnızca gerçek açılışta (main) gösterilir.
  final bool showSplash;

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
    // Titreşim ve ses tercihleri uygulama genelindeki bayrakları günceller.
    ref
      ..watch(hapticsProvider)
      ..watch(soundsProvider);

    final accent = ref.watch(accentProvider);
    // Hatırlatma metni seriye göre; bugün çalışıldıysa bugünkü atlanır.
    ref.listen(streakDisplayProvider, (_, next) {
      ref
          .read(reminderProvider.notifier)
          .personalize(
            streak: next.streak,
            nextMilestone: streakMilestone(next.streak).to,
            doneToday: next.status == StreakStatus.done,
          )
          .ignore();
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, accent),
      darkTheme: buildTheme(Brightness.dark, accent),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      // Seviye/rozet kutlaması her ekranın üstünde gösterilebilsin.
      builder: (context, child) {
        Motion.reduced = MediaQuery.disableAnimationsOf(context);
        return SplashOverlay(
          enabled: widget.showSplash,
          child: CelebrationHost(child: MascotPrecache(child: child!)),
        );
      },
      // Saat seçici, iletişim kutuları vb. sistem metinleri Türkçe olsun.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
