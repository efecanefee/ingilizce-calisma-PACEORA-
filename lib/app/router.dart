import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';

GoRouter createRouter({required bool onboardingDone}) {
  return GoRouter(
    initialLocation: onboardingDone ? '/' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'lesson',
            builder: (context, state) => const LessonScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
