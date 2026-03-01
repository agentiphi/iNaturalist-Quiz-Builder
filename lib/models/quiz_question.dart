enum QuizType { photoToName, nameToPhoto, familyId }

class QuizQuestion {
  final int taxonId;
  final String photoUrl;
  final List<String> allPhotoUrls;
  final String correctCommonName;
  final String correctScientificName;
  final List<AnswerChoice> choices;
  final int? selectedIndex;
  final QuizType type;

  QuizQuestion({
    required this.taxonId,
    required this.photoUrl,
    this.allPhotoUrls = const [],
    required this.correctCommonName,
    required this.correctScientificName,
    required this.choices,
    this.selectedIndex,
    this.type = QuizType.photoToName,
  });

  QuizQuestion copyWith({int? selectedIndex, QuizType? type}) {
    return QuizQuestion(
      taxonId: taxonId,
      photoUrl: photoUrl,
      allPhotoUrls: allPhotoUrls,
      correctCommonName: correctCommonName,
      correctScientificName: correctScientificName,
      choices: choices,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      type: type ?? this.type,
    );
  }

  bool get isAnswered => selectedIndex != null;

  bool get isCorrect =>
      selectedIndex != null && choices[selectedIndex!].isCorrect;

  AnswerChoice get correctChoice => choices.firstWhere((c) => c.isCorrect);
}

class AnswerChoice {
  final String commonName;
  final String scientificName;
  final bool isCorrect;
  final String? photoUrl;

  const AnswerChoice({
    required this.commonName,
    required this.scientificName,
    required this.isCorrect,
    this.photoUrl,
  });

  String get displayName =>
      commonName.isNotEmpty ? commonName : scientificName;
}
