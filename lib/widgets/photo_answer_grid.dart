import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quiz_question.dart';

class PhotoAnswerGrid extends StatelessWidget {
  final List<AnswerChoice> choices;
  final bool isAnswered;
  final int? selectedIndex;
  final bool hapticEnabled;
  final ValueChanged<int> onTap;

  const PhotoAnswerGrid({
    super.key,
    required this.choices,
    required this.isAnswered,
    required this.selectedIndex,
    required this.hapticEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(choices.length, (index) {
        final choice = choices[index];
        return _PhotoAnswerTile(
          choice: choice,
          index: index,
          isAnswered: isAnswered,
          selectedIndex: selectedIndex,
          hapticEnabled: hapticEnabled,
          onTap: () => onTap(index),
        );
      }),
    );
  }
}

class _PhotoAnswerTile extends StatelessWidget {
  final AnswerChoice choice;
  final int index;
  final bool isAnswered;
  final int? selectedIndex;
  final bool hapticEnabled;
  final VoidCallback onTap;

  const _PhotoAnswerTile({
    required this.choice,
    required this.index,
    required this.isAnswered,
    required this.selectedIndex,
    required this.hapticEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? borderColor;
    double borderWidth = 2;
    double opacity = 1.0;

    if (isAnswered) {
      if (choice.isCorrect) {
        borderColor = Colors.green;
        borderWidth = 4;
      } else if (selectedIndex == index) {
        borderColor = Colors.red;
        borderWidth = 4;
      } else {
        opacity = 0.4;
      }
    }

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: isAnswered
            ? null
            : () {
                if (hapticEnabled) HapticFeedback.lightImpact();
                onTap();
              },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? Colors.grey.shade300,
              width: borderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: choice.photoUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 32),
                  ),
                ),
                if (isAnswered)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        choice.isCorrect
                            ? Icons.check_circle
                            : (selectedIndex == index
                                ? Icons.cancel
                                : Icons.circle_outlined),
                        color: choice.isCorrect
                            ? Colors.green
                            : (selectedIndex == index
                                ? Colors.red
                                : Colors.white70),
                        size: 28,
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
}
