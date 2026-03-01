import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/observations_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';

class PracticeWeakScreen extends ConsumerStatefulWidget {
  const PracticeWeakScreen({super.key});

  @override
  ConsumerState<PracticeWeakScreen> createState() => _PracticeWeakScreenState();
}

class _PracticeWeakScreenState extends ConsumerState<PracticeWeakScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadAndGenerate());
  }

  Future<void> _loadAndGenerate() async {
    final progress = ref.read(progressProvider);
    final recentUsernames = ref.read(recentUsernamesProvider);

    // Get weak species taxon IDs
    final weakTaxonIds = progress.species.values
        .where((r) => r.timesSeen >= 2 && r.accuracy < 0.7)
        .map((r) => r.taxonId)
        .toSet();

    if (weakTaxonIds.isEmpty) {
      if (!mounted) return;
      context.go('/progress');
      return;
    }

    // Use most recent username
    final username = recentUsernames.isNotEmpty ? recentUsernames.first : null;
    if (username == null) {
      if (!mounted) return;
      context.go('/');
      return;
    }

    // Load observations if needed
    final obsState = ref.read(observationsProvider);
    if (obsState.status != LoadingStatus.success ||
        obsState.observations.isEmpty) {
      await ref
          .read(observationsProvider.notifier)
          .fetchForUser(username);

      if (!mounted) return;
      final newObs = ref.read(observationsProvider);
      if (newObs.status == LoadingStatus.error) return;
    }

    // Generate weak quiz
    await ref
        .read(quizProvider.notifier)
        .generateWeakQuiz(username, weakTaxonIds);

    if (!mounted) return;

    final quizState = ref.read(quizProvider);
    if (quizState.session != null) {
      context.go('/quiz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final obsState = ref.watch(observationsProvider);
    final quizState = ref.watch(quizProvider);
    final theme = Theme.of(context);

    final hasError = obsState.status == LoadingStatus.error ||
        quizState.errorMessage != null;
    final errorMessage =
        obsState.errorMessage ?? quizState.errorMessage ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/progress'),
        ),
        title: const Text('Practice Weak Species'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!hasError) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Preparing practice quiz...',
                  style: theme.textTheme.titleMedium,
                ),
              ] else ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadAndGenerate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/progress'),
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
