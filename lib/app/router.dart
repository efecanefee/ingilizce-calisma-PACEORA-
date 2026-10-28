import 'package:go_router/go_router.dart';

import '../features/flashcards/flashcards_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/mistakes/mistakes_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/program/program_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/review/weekly_review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/story/story_screen.dart';
import 'motion.dart';
import 'shell.dart';

GoRouter createRouter({required bool onboardingDone}) {
  GoRoute fullScreen(String path, GoRouterWidgetBuilder builder) => GoRoute(
        path: path,
        pageBuilder: (context, state) =>
            motionPage(state, builder(context, state)),
      );

  return GoRouter(
    initialLocation: onboardingDone ? '/' : '/onboarding',
    routes: [
      fullScreen('/onboarding', (_, _) => const OnboardingScreen()),
      // Sekmeler: alt gezinme çubuğu altında, durumları korunur.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/program', builder: (_, _) => const ProgramScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/progress',
              builder: (_, _) => const ProgressScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      // Çalışma ekranları sekmelerin üstünde tam ekran açılır.
      fullScreen('/lesson', (_, _) => const LessonScreen()),
      fullScreen('/flashcards', (_, _) => const FlashcardsScreen()),
      fullScreen('/story', (_, _) => const StoryScreen()),
      fullScreen('/review', (_, _) => const WeeklyReviewScreen()),
      fullScreen('/mistakes', (_, _) => const MistakesScreen()),
    ],
  );
}
