class SpeciesRecord {
  final int taxonId;
  final String scientificName;
  final String commonName;
  final String? photoUrl;
  final int timesCorrect;
  final int timesIncorrect;
  final DateTime lastSeenAt;

  SpeciesRecord({
    required this.taxonId,
    required this.scientificName,
    required this.commonName,
    this.photoUrl,
    this.timesCorrect = 0,
    this.timesIncorrect = 0,
    DateTime? lastSeenAt,
  }) : lastSeenAt = lastSeenAt ?? DateTime.now();

  int get timesSeen => timesCorrect + timesIncorrect;

  double get accuracy => timesSeen > 0 ? timesCorrect / timesSeen : 0;

  String get displayName => commonName.isNotEmpty ? commonName : scientificName;

  SpeciesRecord copyWith({
    int? timesCorrect,
    int? timesIncorrect,
    DateTime? lastSeenAt,
    String? photoUrl,
  }) =>
      SpeciesRecord(
        taxonId: taxonId,
        scientificName: scientificName,
        commonName: commonName,
        photoUrl: photoUrl ?? this.photoUrl,
        timesCorrect: timesCorrect ?? this.timesCorrect,
        timesIncorrect: timesIncorrect ?? this.timesIncorrect,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  Map<String, dynamic> toJson() => {
        'taxonId': taxonId,
        'scientificName': scientificName,
        'commonName': commonName,
        'photoUrl': photoUrl,
        'timesCorrect': timesCorrect,
        'timesIncorrect': timesIncorrect,
        'lastSeenAt': lastSeenAt.toIso8601String(),
      };

  factory SpeciesRecord.fromJson(Map<String, dynamic> json) => SpeciesRecord(
        taxonId: json['taxonId'] as int,
        scientificName: json['scientificName'] as String,
        commonName: (json['commonName'] as String?) ?? '',
        photoUrl: json['photoUrl'] as String?,
        timesCorrect: json['timesCorrect'] as int? ?? 0,
        timesIncorrect: json['timesIncorrect'] as int? ?? 0,
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.parse(json['lastSeenAt'] as String)
            : DateTime.now(),
      );
}

class ProgressData {
  final Map<int, SpeciesRecord> species;
  final int totalQuizzesTaken;
  final int totalQuestionsAnswered;
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastQuizDate;

  ProgressData({
    Map<int, SpeciesRecord>? species,
    this.totalQuizzesTaken = 0,
    this.totalQuestionsAnswered = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastQuizDate,
  }) : species = species ?? {};

  int get speciesSeenCount => species.length;

  double get overallAccuracy {
    if (totalQuestionsAnswered == 0) return 0;
    final totalCorrect =
        species.values.fold<int>(0, (sum, r) => sum + r.timesCorrect);
    return totalCorrect / totalQuestionsAnswered;
  }

  List<SpeciesRecord> get weakestSpecies {
    final seen = species.values.where((r) => r.timesSeen >= 2).toList();
    seen.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return seen;
  }

  /// Returns a new ProgressData with the quiz results applied.
  ProgressData withQuizResult({
    required List<QuizQuestionResult> results,
    required double scorePercentage,
  }) {
    final newSpecies = Map<int, SpeciesRecord>.from(species);
    final now = DateTime.now();

    for (final result in results) {
      final existing = newSpecies[result.taxonId];
      if (existing != null) {
        newSpecies[result.taxonId] = existing.copyWith(
          timesCorrect: existing.timesCorrect + (result.correct ? 1 : 0),
          timesIncorrect: existing.timesIncorrect + (result.correct ? 0 : 1),
          lastSeenAt: now,
          photoUrl: result.photoUrl,
        );
      } else {
        newSpecies[result.taxonId] = SpeciesRecord(
          taxonId: result.taxonId,
          scientificName: result.scientificName,
          commonName: result.commonName,
          photoUrl: result.photoUrl,
          timesCorrect: result.correct ? 1 : 0,
          timesIncorrect: result.correct ? 0 : 1,
          lastSeenAt: now,
        );
      }
    }

    final newStreak = scorePercentage >= 70 ? currentStreak + 1 : 0;

    return ProgressData(
      species: newSpecies,
      totalQuizzesTaken: totalQuizzesTaken + 1,
      totalQuestionsAnswered: totalQuestionsAnswered + results.length,
      currentStreak: newStreak,
      bestStreak: newStreak > bestStreak ? newStreak : bestStreak,
      lastQuizDate: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'species': species.map(
          (k, v) => MapEntry(k.toString(), v.toJson()),
        ),
        'totalQuizzesTaken': totalQuizzesTaken,
        'totalQuestionsAnswered': totalQuestionsAnswered,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastQuizDate': lastQuizDate?.toIso8601String(),
      };

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    final speciesMap = <int, SpeciesRecord>{};
    final rawSpecies = json['species'] as Map<String, dynamic>? ?? {};
    for (final entry in rawSpecies.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) continue;
      speciesMap[id] =
          SpeciesRecord.fromJson(entry.value as Map<String, dynamic>);
    }

    return ProgressData(
      species: speciesMap,
      totalQuizzesTaken: json['totalQuizzesTaken'] as int? ?? 0,
      totalQuestionsAnswered: json['totalQuestionsAnswered'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      lastQuizDate: json['lastQuizDate'] != null
          ? DateTime.parse(json['lastQuizDate'] as String)
          : null,
    );
  }
}

class QuizQuestionResult {
  final int taxonId;
  final String scientificName;
  final String commonName;
  final String? photoUrl;
  final bool correct;

  const QuizQuestionResult({
    required this.taxonId,
    required this.scientificName,
    required this.commonName,
    this.photoUrl,
    required this.correct,
  });
}
