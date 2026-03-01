import 'quiz_question.dart';

class QuizSession {
  final List<QuizQuestion> questions;
  final String username;
  final int currentIndex;

  QuizSession({
    required this.questions,
    required this.username,
    this.currentIndex = 0,
  });

  QuizQuestion get currentQuestion => questions[currentIndex];

  bool get isComplete => currentIndex >= questions.length;

  int get score => questions.where((q) => q.isCorrect).length;

  int get totalQuestions => questions.length;

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  List<QuizQuestion> get missedQuestions =>
      questions.where((q) => q.isAnswered && !q.isCorrect).toList();

  double get scorePercentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

  QuizSession copyWith({
    List<QuizQuestion>? questions,
    int? currentIndex,
  }) {
    return QuizSession(
      questions: questions ?? this.questions,
      username: username,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
