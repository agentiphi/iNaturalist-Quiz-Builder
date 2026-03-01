import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/observations_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  final List<String> usernames;

  const LoadingScreen({super.key, required this.usernames});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to avoid modifying providers during the widget tree build phase.
    Future.microtask(() => _loadAndGenerate());
  }

  Future<void> _loadAndGenerate() async {
    // Save usernames to recents
    for (final username in widget.usernames) {
      ref.read(recentUsernamesProvider.notifier).addUsername(username);
    }

    // Fetch observations
    if (widget.usernames.length == 1) {
      await ref.read(observationsProvider.notifier).fetchForUser(widget.usernames.first);
    } else {
      await ref.read(observationsProvider.notifier).fetchForUsers(widget.usernames);
    }

    if (!mounted) return;

    final obsState = ref.read(observationsProvider);
    if (obsState.status == LoadingStatus.error) return;

    // Generate quiz
    await ref.read(quizProvider.notifier).generateQuiz(widget.usernames.join(', '));

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
          onPressed: () => context.go('/'),
        ),
        title: Text(widget.usernames.length == 1 ? widget.usernames.first : '${widget.usernames.length} users'),
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
                if (obsState.status == LoadingStatus.loading)
                  Text(
                    obsState.totalUsers > 1
                        ? 'Loading user ${obsState.currentUserIndex + 1}/${obsState.totalUsers}...'
                        : 'Loading observations...',
                    style: theme.textTheme.titleMedium,
                  )
                else if (quizState.isGenerating) ...[
                  Text(
                    '${obsState.loadedCount} observations found',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generating quiz...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                  onPressed: () => context.go('/'),
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
