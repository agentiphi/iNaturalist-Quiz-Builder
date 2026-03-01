import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/locale_data.dart';
import '../models/quiz_question.dart' show QuizType;
import '../models/settings.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Default quiz type'),
            leading: const Icon(Icons.category),
            subtitle: Text(_quizTypeLabel(settings.quizType)),
            trailing: DropdownButton<QuizType>(
              value: settings.quizType,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: QuizType.photoToName, child: Text('Photo → Name')),
                DropdownMenuItem(value: QuizType.nameToPhoto, child: Text('Name → Photo')),
                DropdownMenuItem(value: QuizType.familyId, child: Text('Family ID')),
              ],
              onChanged: (value) {
                if (value != null) notifier.updateQuizType(value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Questions per quiz'),
            subtitle: Text(
              settings.questionsPerQuiz == 0
                  ? 'All available'
                  : '${settings.questionsPerQuiz}',
            ),
            leading: const Icon(Icons.quiz),
            trailing: DropdownButton<int>(
              value: settings.questionsPerQuiz,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
                DropdownMenuItem(value: 30, child: Text('30')),
                DropdownMenuItem(value: 50, child: Text('50')),
                DropdownMenuItem(value: 0, child: Text('All')),
              ],
              onChanged: (value) {
                if (value != null) notifier.updateQuestionsPerQuiz(value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Quality grade filter'),
            leading: const Icon(Icons.verified),
            subtitle: Text(_qualityGradeLabel(settings.qualityGrade)),
            trailing: DropdownButton<QualityGrade>(
              value: settings.qualityGrade,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: QualityGrade.research,
                  child: Text('Research'),
                ),
                DropdownMenuItem(
                  value: QualityGrade.needsId,
                  child: Text('Needs ID'),
                ),
                DropdownMenuItem(
                  value: QualityGrade.both,
                  child: Text('Both'),
                ),
              ],
              onChanged: (value) {
                if (value != null) notifier.updateQualityGrade(value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Answer display'),
            leading: const Icon(Icons.text_fields),
            subtitle: Text(_answerFormatLabel(settings.answerFormat)),
            trailing: DropdownButton<AnswerFormat>(
              value: settings.answerFormat,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: AnswerFormat.both,
                  child: Text('Both'),
                ),
                DropdownMenuItem(
                  value: AnswerFormat.commonOnly,
                  child: Text('Common'),
                ),
                DropdownMenuItem(
                  value: AnswerFormat.scientificOnly,
                  child: Text('Scientific'),
                ),
              ],
              onChanged: (value) {
                if (value != null) notifier.updateAnswerFormat(value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Species name language'),
            leading: const Icon(Icons.language),
            subtitle: Text(
              localeByCode(settings.locale)?.nativeName ?? settings.locale,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLocalePicker(context, ref),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            subtitle: const Text('Vibrate on answer tap'),
            secondary: const Icon(Icons.vibration),
            value: settings.hapticFeedback,
            onChanged: (_) => notifier.toggleHapticFeedback(),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Photo swipe hints'),
            subtitle: const Text(
              'Show dot indicators on multi-photo observations',
            ),
            secondary: const Icon(Icons.swipe),
            value: settings.photoSwipeHints,
            onChanged: (_) => notifier.togglePhotoSwipeHints(),
          ),
        ],
      ),
    );
  }

  void _showLocalePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _LocalePickerSheet(
        currentLocale: ref.read(settingsProvider).locale,
        onSelected: (code) {
          ref.read(settingsProvider.notifier).updateLocale(code);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  String _quizTypeLabel(QuizType type) {
    switch (type) {
      case QuizType.photoToName:
        return 'Photo to Name';
      case QuizType.nameToPhoto:
        return 'Name to Photo';
      case QuizType.familyId:
        return 'Family Identification';
    }
  }

  String _qualityGradeLabel(QualityGrade grade) {
    switch (grade) {
      case QualityGrade.research:
        return 'Research grade only';
      case QualityGrade.needsId:
        return 'Needs ID only';
      case QualityGrade.both:
        return 'Research + Needs ID';
    }
  }

  String _answerFormatLabel(AnswerFormat format) {
    switch (format) {
      case AnswerFormat.both:
        return 'Common + Scientific name';
      case AnswerFormat.commonOnly:
        return 'Common name only';
      case AnswerFormat.scientificOnly:
        return 'Scientific name only';
    }
  }
}

class _LocalePickerSheet extends StatefulWidget {
  final String currentLocale;
  final ValueChanged<String> onSelected;

  const _LocalePickerSheet({
    required this.currentLocale,
    required this.onSelected,
  });

  @override
  State<_LocalePickerSheet> createState() => _LocalePickerSheetState();
}

class _LocalePickerSheetState extends State<_LocalePickerSheet> {
  final _searchController = TextEditingController();
  List<LocaleEntry> _filtered = supportedLocales;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = supportedLocales;
      } else {
        _filtered = supportedLocales
            .where((e) =>
                e.name.toLowerCase().contains(query) ||
                e.nativeName.toLowerCase().contains(query) ||
                e.code.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search languages...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final entry = _filtered[index];
                  final isSelected = entry.code == widget.currentLocale;
                  return ListTile(
                    title: Text(entry.nativeName),
                    subtitle: Text('${entry.name} (${entry.code})'),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () => widget.onSelected(entry.code),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
