import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_question.dart';
import '../models/quiz_session.dart';
import '../services/inaturalist_api.dart';
import '../services/quiz_engine.dart';
import 'observations_provider.dart';
import 'settings_provider.dart';

class QuizState {
  final QuizSession? session;
  final bool isGenerating;
  final String? errorMessage;

  const QuizState({
    this.session,
    this.isGenerating = false,
    this.errorMessage,
  });

  QuizState copyWith({
    QuizSession? session,
    bool? isGenerating,
    String? errorMessage,
  }) {
    return QuizState(
      session: session ?? this.session,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage,
    );
  }
}

class QuizNotifier extends Notifier<QuizState> {
  @override
  QuizState build() => const QuizState();

  Future<void> generateQuiz(String username) async {
    state = const QuizState(isGenerating: true);

    try {
      final api = ref.read(inaturalistApiProvider);
      final observations = ref.read(observationsProvider).observations;
      final settings = ref.read(settingsProvider);

      final familyIds = QuizEngine.getUniqueFamilyIds(observations);
      final familySpeciesMap = <int, List<TaxonSummary>>{};

      for (final familyId in familyIds) {
        try {
          final species = await api.fetchFamilySpecies(
            familyId: familyId,
            locale: settings.locale,
          );
          familySpeciesMap[familyId] = species;
        } catch (_) {
          // If a single family fetch fails, skip it
        }
      }

      final questions = QuizEngine.generateQuestions(
        observations: observations,
        familySpeciesMap: familySpeciesMap,
        count: settings.questionsPerQuiz,
        allObservations: observations,
        quizType: settings.quizType,
      );

      if (questions.isEmpty) {
        state = const QuizState(
          errorMessage:
              'Couldn\'t generate quiz questions. Try a different user.',
        );
        return;
      }

      state = QuizState(
        session: QuizSession(
          questions: questions,
          username: username,
        ),
      );
    } catch (e) {
      state = QuizState(
        errorMessage: 'Failed to generate quiz: $e',
      );
    }
  }

  Future<void> generateWeakQuiz(String username, Set<int> weakTaxonIds) async {
    state = const QuizState(isGenerating: true);

    try {
      final api = ref.read(inaturalistApiProvider);
      final allObservations = ref.read(observationsProvider).observations;
      final settings = ref.read(settingsProvider);

      // Filter to weak species, but keep all observations for distractors
      final weakObservations =
          allObservations.where((o) => weakTaxonIds.contains(o.taxonId)).toList();

      if (weakObservations.isEmpty) {
        state = const QuizState(
          errorMessage: 'No weak species observations available.',
        );
        return;
      }

      final familyIds = QuizEngine.getUniqueFamilyIds(weakObservations);
      final familySpeciesMap = <int, List<TaxonSummary>>{};

      for (final familyId in familyIds) {
        try {
          final species = await api.fetchFamilySpecies(
            familyId: familyId,
            locale: settings.locale,
          );
          familySpeciesMap[familyId] = species;
        } catch (_) {}
      }

      final questions = QuizEngine.generateQuestions(
        observations: weakObservations,
        familySpeciesMap: familySpeciesMap,
        count: settings.questionsPerQuiz,
        allObservations: allObservations,
        quizType: settings.quizType,
      );

      if (questions.isEmpty) {
        state = const QuizState(
          errorMessage: 'Couldn\'t generate practice questions.',
        );
        return;
      }

      state = QuizState(
        session: QuizSession(
          questions: questions,
          username: username,
        ),
      );
    } catch (e) {
      state = QuizState(
        errorMessage: 'Failed to generate quiz: $e',
      );
    }
  }

  void selectAnswer(int choiceIndex) {
    final session = state.session;
    if (session == null || session.isComplete) return;

    final question = session.currentQuestion;
    if (question.isAnswered) return;

    final updatedQuestion = question.copyWith(selectedIndex: choiceIndex);
    final updatedQuestions = List<QuizQuestion>.from(session.questions);
    updatedQuestions[session.currentIndex] = updatedQuestion;

    state = QuizState(session: session.copyWith(questions: updatedQuestions));
  }

  void nextQuestion() {
    final session = state.session;
    if (session == null || session.isComplete) return;

    state = QuizState(
      session: session.copyWith(currentIndex: session.currentIndex + 1),
    );
  }
}

final quizProvider = NotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);
