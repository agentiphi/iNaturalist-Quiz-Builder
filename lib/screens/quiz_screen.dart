import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/quiz_question.dart';
import '../providers/progress_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/answer_button.dart';
import '../widgets/photo_answer_grid.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/score_badge.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool _completionRecorded = false;

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);
    final settings = ref.watch(settingsProvider);
    final session = quizState.session;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }

    if (session.isComplete) {
      if (!_completionRecorded) {
        _completionRecorded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await ref.read(progressProvider.notifier).recordQuizCompletion(session);
          if (context.mounted) context.go('/results');
        });
      }
      return const SizedBox.shrink();
    }

    final question = session.currentQuestion;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showQuitDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showQuitDialog(context),
          ),
          title:
              Text('${session.currentIndex + 1} / ${session.totalQuestions}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ScoreBadge(
                score: session.score,
                total: session.answeredCount,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (question.type == QuizType.nameToPhoto) ...[
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            question.correctCommonName,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          if (question.correctCommonName !=
                              question.correctScientificName)
                            Text(
                              question.correctScientificName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 4,
                    child: PhotoAnswerGrid(
                      choices: question.choices,
                      isAnswered: question.isAnswered,
                      selectedIndex: question.selectedIndex,
                      hapticEnabled: settings.hapticFeedback,
                      onTap: (index) {
                        ref.read(quizProvider.notifier).selectAnswer(index);
                      },
                    ),
                  ),
                ] else ...[
                  Expanded(
                    flex: 3,
                    child: PhotoViewer(
                      photoUrl: question.photoUrl,
                      allPhotoUrls: question.allPhotoUrls,
                      showSwipeHints: settings.photoSwipeHints,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: ListView.separated(
                      itemCount: question.choices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        return AnswerButton(
                          choice: question.choices[index],
                          index: index,
                          isAnswered: question.isAnswered,
                          selectedIndex: question.selectedIndex,
                          answerFormat: settings.answerFormat,
                          hapticEnabled: settings.hapticFeedback,
                          onTap: () {
                            ref
                                .read(quizProvider.notifier)
                                .selectAnswer(index);
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (question.isAnswered)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(quizProvider.notifier).nextQuestion();
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        session.currentIndex + 1 >= session.totalQuestions
                            ? 'See Results'
                            : 'Next',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Quiz?'),
        content: const Text('Progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }
}
