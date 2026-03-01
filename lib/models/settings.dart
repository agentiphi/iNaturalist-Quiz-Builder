import 'quiz_question.dart' show QuizType;

enum QualityGrade { research, needsId, both }

enum AnswerFormat { commonOnly, scientificOnly, both }

class QuizSettings {
  final int questionsPerQuiz;
  final QualityGrade qualityGrade;
  final AnswerFormat answerFormat;
  final bool hapticFeedback;
  final bool photoSwipeHints;
  final String locale;
  final QuizType quizType;

  const QuizSettings({
    this.questionsPerQuiz = 20,
    this.qualityGrade = QualityGrade.research,
    this.answerFormat = AnswerFormat.both,
    this.hapticFeedback = true,
    this.photoSwipeHints = true,
    this.locale = 'en',
    this.quizType = QuizType.photoToName,
  });

  QuizSettings copyWith({
    int? questionsPerQuiz,
    QualityGrade? qualityGrade,
    AnswerFormat? answerFormat,
    bool? hapticFeedback,
    bool? photoSwipeHints,
    String? locale,
    QuizType? quizType,
  }) {
    return QuizSettings(
      questionsPerQuiz: questionsPerQuiz ?? this.questionsPerQuiz,
      qualityGrade: qualityGrade ?? this.qualityGrade,
      answerFormat: answerFormat ?? this.answerFormat,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      photoSwipeHints: photoSwipeHints ?? this.photoSwipeHints,
      locale: locale ?? this.locale,
      quizType: quizType ?? this.quizType,
    );
  }

  String get qualityGradeParam {
    switch (qualityGrade) {
      case QualityGrade.research:
        return 'research';
      case QualityGrade.needsId:
        return 'needs_id';
      case QualityGrade.both:
        return 'research,needs_id';
    }
  }
}
