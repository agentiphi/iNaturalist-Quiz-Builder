import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_question.dart' show QuizType;
import '../models/settings.dart';

class SettingsNotifier extends Notifier<QuizSettings> {
  @override
  QuizSettings build() {
    _loadFromPrefs();
    return const QuizSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final qualityIdx = prefs.getInt('qualityGrade') ?? 0;
    final formatIdx = prefs.getInt('answerFormat') ?? 2;
    final typeIdx = prefs.getInt('quizType') ?? 0;

    state = QuizSettings(
      questionsPerQuiz: prefs.getInt('questionsPerQuiz') ?? 20,
      qualityGrade: qualityIdx < QualityGrade.values.length
          ? QualityGrade.values[qualityIdx]
          : QualityGrade.research,
      answerFormat: formatIdx < AnswerFormat.values.length
          ? AnswerFormat.values[formatIdx]
          : AnswerFormat.both,
      hapticFeedback: prefs.getBool('hapticFeedback') ?? true,
      photoSwipeHints: prefs.getBool('photoSwipeHints') ?? true,
      locale: prefs.getString('locale') ?? 'en',
      quizType: typeIdx < QuizType.values.length
          ? QuizType.values[typeIdx]
          : QuizType.photoToName,
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('questionsPerQuiz', state.questionsPerQuiz);
    await prefs.setInt('qualityGrade', state.qualityGrade.index);
    await prefs.setInt('answerFormat', state.answerFormat.index);
    await prefs.setBool('hapticFeedback', state.hapticFeedback);
    await prefs.setBool('photoSwipeHints', state.photoSwipeHints);
    await prefs.setString('locale', state.locale);
    await prefs.setInt('quizType', state.quizType.index);
  }

  void updateQuestionsPerQuiz(int value) {
    state = state.copyWith(questionsPerQuiz: value);
    _saveToPrefs();
  }

  void updateQualityGrade(QualityGrade value) {
    state = state.copyWith(qualityGrade: value);
    _saveToPrefs();
  }

  void updateAnswerFormat(AnswerFormat value) {
    state = state.copyWith(answerFormat: value);
    _saveToPrefs();
  }

  void toggleHapticFeedback() {
    state = state.copyWith(hapticFeedback: !state.hapticFeedback);
    _saveToPrefs();
  }

  void togglePhotoSwipeHints() {
    state = state.copyWith(photoSwipeHints: !state.photoSwipeHints);
    _saveToPrefs();
  }

  void updateQuizType(QuizType value) {
    state = state.copyWith(quizType: value);
    _saveToPrefs();
  }

  void updateLocale(String value) {
    state = state.copyWith(locale: value);
    _saveToPrefs();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, QuizSettings>(
  SettingsNotifier.new,
);

class RecentUsernamesNotifier extends Notifier<List<String>> {
  static const _key = 'recentUsernames';
  static const _maxRecent = 5;

  @override
  List<String> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> addUsername(String username) async {
    final updated = [
      username,
      ...state.where((u) => u != username),
    ].take(_maxRecent).toList();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
  }
}

final recentUsernamesProvider =
    NotifierProvider<RecentUsernamesNotifier, List<String>>(
  RecentUsernamesNotifier.new,
);
