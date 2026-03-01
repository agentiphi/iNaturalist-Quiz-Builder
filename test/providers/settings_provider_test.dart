import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inaturalist_quiz/models/settings.dart';
import 'package:inaturalist_quiz/providers/settings_provider.dart';

void main() {
  group('SettingsNotifier', () {
    test('has correct defaults', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);

      expect(settings.questionsPerQuiz, 20);
      expect(settings.qualityGrade, QualityGrade.research);
      expect(settings.answerFormat, AnswerFormat.both);
      expect(settings.hapticFeedback, true);
      expect(settings.photoSwipeHints, true);
    });

    test('loads saved values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'questionsPerQuiz': 10,
        'qualityGrade': 1,
        'answerFormat': 0,
        'hapticFeedback': false,
        'photoSwipeHints': false,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read initial (defaults) then wait for async load
      container.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);

      final settings = container.read(settingsProvider);
      expect(settings.questionsPerQuiz, 10);
      expect(settings.qualityGrade, QualityGrade.needsId);
      expect(settings.answerFormat, AnswerFormat.commonOnly);
      expect(settings.hapticFeedback, false);
      expect(settings.photoSwipeHints, false);
    });

    test('updateQuestionsPerQuiz updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      notifier.updateQuestionsPerQuiz(15);

      final settings = container.read(settingsProvider);
      expect(settings.questionsPerQuiz, 15);

      // Verify persistence
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('questionsPerQuiz'), 15);
    });

    test('updateQualityGrade updates state', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      notifier.updateQualityGrade(QualityGrade.both);

      expect(container.read(settingsProvider).qualityGrade, QualityGrade.both);
    });

    test('updateAnswerFormat updates state', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      notifier.updateAnswerFormat(AnswerFormat.scientificOnly);

      expect(
        container.read(settingsProvider).answerFormat,
        AnswerFormat.scientificOnly,
      );
    });

    test('toggleHapticFeedback flips the value', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsProvider).hapticFeedback, true);

      notifier.toggleHapticFeedback();
      expect(container.read(settingsProvider).hapticFeedback, false);

      notifier.toggleHapticFeedback();
      expect(container.read(settingsProvider).hapticFeedback, true);
    });

    test('togglePhotoSwipeHints flips the value', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsProvider).photoSwipeHints, true);

      notifier.togglePhotoSwipeHints();
      expect(container.read(settingsProvider).photoSwipeHints, false);
    });
  });

  group('RecentUsernamesNotifier', () {
    test('starts with empty list', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final usernames = container.read(recentUsernamesProvider);
      expect(usernames, isEmpty);
    });

    test('addUsername adds and persists username', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recentUsernamesProvider.notifier);
      await notifier.addUsername('alice');

      expect(container.read(recentUsernamesProvider), ['alice']);
    });

    test('addUsername moves duplicate to front', () async {
      SharedPreferences.setMockInitialValues({
        'recentUsernames': ['bob', 'alice'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for async load
      container.read(recentUsernamesProvider);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(recentUsernamesProvider.notifier);
      await notifier.addUsername('alice');

      expect(container.read(recentUsernamesProvider), ['alice', 'bob']);
    });

    test('addUsername limits to 5 recent usernames', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recentUsernamesProvider.notifier);
      await notifier.addUsername('a');
      await notifier.addUsername('b');
      await notifier.addUsername('c');
      await notifier.addUsername('d');
      await notifier.addUsername('e');
      await notifier.addUsername('f');

      final usernames = container.read(recentUsernamesProvider);
      expect(usernames.length, 5);
      expect(usernames.first, 'f');
      expect(usernames.contains('a'), false);
    });
  });
}
