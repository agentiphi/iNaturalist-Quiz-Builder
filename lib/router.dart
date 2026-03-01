import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/import_playlist_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/practice_weak_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/results_screen.dart';
import 'screens/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/loading/:usernames',
      builder: (context, state) {
        final raw = state.pathParameters['usernames']!;
        final usernames = raw.split(',').where((s) => s.isNotEmpty).toList();
        return LoadingScreen(usernames: usernames);
      },
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressScreen(),
    ),
    GoRoute(
      path: '/practice-weak',
      builder: (context, state) => const PracticeWeakScreen(),
    ),
    GoRoute(
      path: '/import-playlist',
      builder: (context, state) {
        final name = state.uri.queryParameters['name'] ?? 'Shared Playlist';
        final users = (state.uri.queryParameters['users'] ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
        return ImportPlaylistScreen(name: name, usernames: users);
      },
    ),
  ],
);
