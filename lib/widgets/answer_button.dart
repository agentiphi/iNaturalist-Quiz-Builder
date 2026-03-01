import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quiz_question.dart';
import '../models/settings.dart';

class AnswerButton extends StatelessWidget {
  final AnswerChoice choice;
  final int index;
  final bool isAnswered;
  final int? selectedIndex;
  final AnswerFormat answerFormat;
  final bool hapticEnabled;
  final VoidCallback onTap;

  const AnswerButton({
    super.key,
    required this.choice,
    required this.index,
    required this.isAnswered,
    required this.selectedIndex,
    required this.answerFormat,
    required this.hapticEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color? backgroundColor;
    Color? foregroundColor;
    double opacity = 1.0;

    if (isAnswered) {
      if (choice.isCorrect) {
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade900;
      } else if (selectedIndex == index) {
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade900;
      } else {
        opacity = 0.4;
      }
    }

    return Opacity(
      opacity: opacity,
      child: Card(
        color: backgroundColor,
        child: InkWell(
          onTap: isAnswered
              ? null
              : () {
                  if (hapticEnabled) {
                    HapticFeedback.lightImpact();
                  }
                  onTap();
                },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (isAnswered) ...[
                  Icon(
                    choice.isCorrect
                        ? Icons.check_circle
                        : (selectedIndex == index
                            ? Icons.cancel
                            : Icons.circle_outlined),
                    color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (answerFormat != AnswerFormat.scientificOnly &&
                          choice.commonName.isNotEmpty)
                        Text(
                          choice.commonName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (answerFormat != AnswerFormat.commonOnly)
                        Text(
                          choice.scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foregroundColor?.withValues(alpha: 0.8) ??
                                theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
