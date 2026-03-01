import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/progress_provider.dart';
import '../providers/quiz_provider.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizProvider);
    final session = quizState.session;
    final theme = Theme.of(context);

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }

    final progress = ref.watch(progressProvider);
    final missed = session.missedQuestions;
    final percentage = session.scorePercentage.round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    '$percentage%',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: percentage >= 70
                          ? Colors.green.shade700
                          : percentage >= 40
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.score} / ${session.totalQuestions} correct',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            if (missed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Review missed (${missed.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: missed.length,
                  itemBuilder: (context, index) {
                    final question = missed[index];
                    final selected = question.selectedIndex != null
                        ? question.choices[question.selectedIndex!]
                        : null;
                    final speciesRecord =
                        progress.species[question.taxonId];
                    final isStruggling = speciesRecord != null &&
                        speciesRecord.timesSeen >= 3 &&
                        speciesRecord.accuracy < 0.5;
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: question.photoUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 24),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                question.correctCommonName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isStruggling)
                              Tooltip(
                                message: 'Needs practice — ${(speciesRecord.accuracy * 100).round()}% accuracy',
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 20,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question.correctScientificName,
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                            if (selected != null)
                              Text(
                                'You picked: ${selected.displayName}',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, size: 64, color: Colors.amber.shade600),
                      const SizedBox(height: 16),
                      Text('Perfect score!', style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home),
                      label: const Text('Main Menu'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Re-encode usernames with comma-only (no spaces)
                        // to match the router's split(',') parsing.
                        final encoded = session.username
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .join(',');
                        context.go('/loading/$encoded');
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
