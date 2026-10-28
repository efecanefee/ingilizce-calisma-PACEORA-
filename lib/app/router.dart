import 'package:go_router/go_router.dart';

import '../features/flashcards/flashcards_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/review/weekly_review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/story/story_screen.dart';
import 'motion.dart';

GoRouter createRouter({required bool onboardingDone}) {
  return GoRouter(
    initialLocation: onboardingDone ? '/' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            motionPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => motionPage(state, const HomeScreen()),
        routes: [
          GoRoute(
            path: 'lesson',
            pageBuilder: (context, state) =>
                motionPage(state, const LessonScreen()),
          ),
          GoRoute(
            path: 'flashcards',
            pageBuilder: (context, state) =>
                motionPage(state, const FlashcardsScreen()),
          ),
          GoRoute(
            path: 'story',
            pageBuilder: (context, state) =>
                motionPage(state, const StoryScreen()),
          ),
          GoRoute(
            path: 'progress',
            pageBuilder: (context, state) =>
                motionPage(state, const ProgressScreen()),
          ),
          GoRoute(
            path: 'review',
            pageBuilder: (context, state) =>
                motionPage(state, const WeeklyReviewScreen()),
          ),
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) =>
                motionPage(state, const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
}
