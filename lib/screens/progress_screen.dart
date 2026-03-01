import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/progress.dart';
import '../providers/progress_provider.dart';

enum _SortMode { weakest, mostSeen, recent }

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  _SortMode _sortMode = _SortMode.weakest;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    final speciesList = progress.species.values.toList();
    _sortSpecies(speciesList);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Progress'),
      ),
      body: speciesList.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No progress yet',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete a quiz to start tracking your species knowledge.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _SummaryHeader(progress: progress),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${speciesList.length} species',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_SortMode>(
                          segments: const [
                            ButtonSegment(
                              value: _SortMode.weakest,
                              label: Text('Weakest'),
                            ),
                            ButtonSegment(
                              value: _SortMode.mostSeen,
                              label: Text('Most seen'),
                            ),
                            ButtonSegment(
                              value: _SortMode.recent,
                              label: Text('Recent'),
                            ),
                          ],
                          selected: {_sortMode},
                          onSelectionChanged: (selection) {
                            setState(() => _sortMode = selection.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStatePropertyAll(
                              theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: speciesList.length,
                    itemBuilder: (context, index) {
                      return _SpeciesTile(record: speciesList[index]);
                    },
                  ),
                ),
                if (_hasWeakSpecies(progress))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () => context.go('/practice-weak'),
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('Practice Weak Species'),
                    ),
                  ),
              ],
            ),
    );
  }

  void _sortSpecies(List<SpeciesRecord> list) {
    switch (_sortMode) {
      case _SortMode.weakest:
        list.sort((a, b) => a.accuracy.compareTo(b.accuracy));
      case _SortMode.mostSeen:
        list.sort((a, b) => b.timesSeen.compareTo(a.timesSeen));
      case _SortMode.recent:
        list.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    }
  }

  bool _hasWeakSpecies(ProgressData progress) {
    return progress.species.values
        .any((r) => r.timesSeen >= 2 && r.accuracy < 0.7);
  }
}

class _SummaryHeader extends StatelessWidget {
  final ProgressData progress;

  const _SummaryHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatColumn(
              label: 'Quizzes',
              value: '${progress.totalQuizzesTaken}',
              icon: Icons.quiz,
            ),
            _StatColumn(
              label: 'Species',
              value: '${progress.speciesSeenCount}',
              icon: Icons.eco,
            ),
            _StatColumn(
              label: 'Accuracy',
              value: '${(progress.overallAccuracy * 100).round()}%',
              icon: Icons.gps_fixed,
            ),
            _StatColumn(
              label: 'Streak',
              value: '${progress.currentStreak}',
              secondaryValue:
                  progress.bestStreak > 0 ? 'Best: ${progress.bestStreak}' : null,
              icon: Icons.local_fire_department,
              iconColor:
                  progress.currentStreak > 0 ? Colors.orange : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String? secondaryValue;
  final IconData icon;
  final Color? iconColor;

  const _StatColumn({
    required this.label,
    required this.value,
    this.secondaryValue,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor ?? theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (secondaryValue != null)
          Text(
            secondaryValue!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
      ],
    );
  }
}

class _SpeciesTile extends StatelessWidget {
  final SpeciesRecord record;

  const _SpeciesTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracyPercent = (record.accuracy * 100).round();
    final masteryColor = _masteryColor(record.accuracy);

    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: record.photoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: record.photoUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.eco,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
      title: Text(
        record.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: record.accuracy,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: masteryColor,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$accuracyPercent%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: masteryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      trailing: Text(
        '${record.timesSeen}x',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _masteryColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
