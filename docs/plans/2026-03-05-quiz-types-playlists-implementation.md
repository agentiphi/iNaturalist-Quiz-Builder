# Quiz Types + Playlists Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Name-to-Photo and Family ID quiz types, multi-user playlists with save/share, and deep link import.

**Architecture:** Extend existing models with a `QuizType` enum that flows through settings -> quiz engine -> quiz screen. Playlists are a new model/provider pair persisted as JSON. Multi-user loading aggregates observations sequentially. Deep links use Android intent filters with a custom URL scheme parsed by GoRouter.

**Tech Stack:** Flutter, Riverpod, GoRouter (deep links), SharedPreferences, path_provider, `share_plus` package for share sheet.

---

### Task 1: Model Layer — QuizType, AnswerChoice.photoUrl, QuizQuestion.type

**Files:**
- Modify: `lib/models/settings.dart`
- Modify: `lib/models/quiz_question.dart`

**Step 1: Add QuizType enum to settings.dart**

Add after the existing enums:

```dart
enum QuizType { photoToName, nameToPhoto, familyId }
```

Add `quizType` field to `QuizSettings`:

```dart
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
  // ... qualityGradeParam stays the same
}
```

**Step 2: Add photoUrl to AnswerChoice and type to QuizQuestion**

In `lib/models/quiz_question.dart`:

```dart
enum QuizType { photoToName, nameToPhoto, familyId }
```

Wait — QuizType is in settings.dart. Import it from there in quiz_question.dart. Actually, better to define it in quiz_question.dart (it's a quiz concept) and import from there in settings. Update:

Define `QuizType` in `lib/models/quiz_question.dart` and import it in settings.dart.

```dart
// lib/models/quiz_question.dart
enum QuizType { photoToName, nameToPhoto, familyId }

class QuizQuestion {
  final QuizType type;
  final int taxonId;
  final String photoUrl;
  final List<String> allPhotoUrls;
  final String correctCommonName;
  final String correctScientificName;
  final List<AnswerChoice> choices;
  final int? selectedIndex;

  QuizQuestion({
    this.type = QuizType.photoToName,
    required this.taxonId,
    required this.photoUrl,
    this.allPhotoUrls = const [],
    required this.correctCommonName,
    required this.correctScientificName,
    required this.choices,
    this.selectedIndex,
  });

  QuizQuestion copyWith({int? selectedIndex}) {
    return QuizQuestion(
      type: type,
      taxonId: taxonId,
      photoUrl: photoUrl,
      allPhotoUrls: allPhotoUrls,
      correctCommonName: correctCommonName,
      correctScientificName: correctScientificName,
      choices: choices,
      selectedIndex: selectedIndex ?? this.selectedIndex,
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
  final String? photoUrl;
  final bool isCorrect;

  const AnswerChoice({
    required this.commonName,
    required this.scientificName,
    this.photoUrl,
    required this.isCorrect,
  });

  String get displayName =>
      commonName.isNotEmpty ? commonName : scientificName;
}
```

In `lib/models/settings.dart`, add import and field:

```dart
import 'quiz_question.dart' show QuizType;
```

**Step 3: Run analyze to verify no breakage**

Run: `flutter analyze`
Expected: No issues (existing code passes QuizType.photoToName by default)

**Step 4: Commit**

```bash
git add lib/models/quiz_question.dart lib/models/settings.dart
git commit -m "feat: add QuizType enum, photoUrl to AnswerChoice, type to QuizQuestion"
```

---

### Task 2: TaxonSummary photoUrl + API Parsing

**Files:**
- Modify: `lib/services/inaturalist_api.dart`
- Modify: `test/services/inaturalist_api_test.dart`

**Step 1: Write the failing test**

Add to `test/services/inaturalist_api_test.dart`:

```dart
test('fetchFamilySpecies parses default_photo URL', () async {
  final mockClient = MockClient();
  final api = INaturalistApi(client: mockClient);

  when(() => mockClient.get(any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 100,
                  'name': 'Canis lupus',
                  'preferred_common_name': 'Wolf',
                  'default_photo': {
                    'medium_url': 'https://example.com/wolf_medium.jpg',
                  },
                },
                {
                  'id': 101,
                  'name': 'Vulpes vulpes',
                  'preferred_common_name': 'Red Fox',
                  // No default_photo — should be null
                },
              ],
            }),
            200,
          ));

  final species = await api.fetchFamilySpecies(familyId: 42);

  expect(species[0].photoUrl, 'https://example.com/wolf_medium.jpg');
  expect(species[1].photoUrl, isNull);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/inaturalist_api_test.dart -v`
Expected: FAIL — `photoUrl` not a field on TaxonSummary

**Step 3: Add photoUrl to TaxonSummary**

In `lib/services/inaturalist_api.dart`, update `TaxonSummary`:

```dart
class TaxonSummary {
  final int id;
  final String scientificName;
  final String? commonName;
  final String? photoUrl;

  const TaxonSummary({
    required this.id,
    required this.scientificName,
    this.commonName,
    this.photoUrl,
  });

  factory TaxonSummary.fromJson(Map<String, dynamic> json) {
    final defaultPhoto = json['default_photo'] as Map<String, dynamic>?;
    return TaxonSummary(
      id: json['id'] as int,
      scientificName: json['name'] as String,
      commonName: json['preferred_common_name'] as String?,
      photoUrl: defaultPhoto?['medium_url'] as String?,
    );
  }

  String get displayName => commonName ?? scientificName;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/inaturalist_api_test.dart -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/services/inaturalist_api.dart test/services/inaturalist_api_test.dart
git commit -m "feat: parse default_photo URL from taxa API into TaxonSummary"
```

---

### Task 3: Quiz Engine — Name-to-Photo Question Generation

**Files:**
- Modify: `lib/services/quiz_engine.dart`
- Modify: `test/services/quiz_engine_test.dart`

**Step 1: Write the failing test**

Add to `test/services/quiz_engine_test.dart`:

```dart
test('generateQuestions with nameToPhoto produces photo-based choices', () {
  final familySpecies = {
    42: [
      TaxonSummary(id: 100, scientificName: 'Canis lupus', commonName: 'Wolf',
          photoUrl: 'https://example.com/wolf.jpg'),
      TaxonSummary(id: 102, scientificName: 'Canis latrans', commonName: 'Coyote',
          photoUrl: 'https://example.com/coyote.jpg'),
      TaxonSummary(id: 103, scientificName: 'Lycaon pictus', commonName: 'African Wild Dog',
          photoUrl: 'https://example.com/wild_dog.jpg'),
      TaxonSummary(id: 104, scientificName: 'Cuon alpinus', commonName: 'Dhole',
          photoUrl: 'https://example.com/dhole.jpg'),
    ],
  };

  final singleObs = [observations[0]]; // Wolf
  final questions = QuizEngine.generateQuestions(
    observations: singleObs,
    familySpeciesMap: familySpecies,
    count: 1,
    quizType: QuizType.nameToPhoto,
  );

  expect(questions.length, 1);
  expect(questions[0].type, QuizType.nameToPhoto);
  // All choices should have photoUrl set
  for (final choice in questions[0].choices) {
    expect(choice.photoUrl, isNotNull);
  }
  // Exactly one correct
  expect(questions[0].choices.where((c) => c.isCorrect).length, 1);
});
```

Note: import `QuizType` from `quiz_question.dart` at top of test file.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/quiz_engine_test.dart -v`
Expected: FAIL — `quizType` not a named parameter

**Step 3: Implement nameToPhoto in quiz_engine.dart**

Update `generateQuestions` signature to accept `QuizType quizType = QuizType.photoToName`. Add a branch for `nameToPhoto`:

```dart
static List<QuizQuestion> generateQuestions({
  required List<Observation> observations,
  required Map<int, List<TaxonSummary>> familySpeciesMap,
  required int count,
  List<Observation>? allObservations,
  QuizType quizType = QuizType.photoToName,
}) {
  // ... existing shuffling and orderSpeciesMap logic ...

  final questions = <QuizQuestion>[];

  for (final obs in selected) {
    switch (quizType) {
      case QuizType.photoToName:
        final q = _buildPhotoToNameQuestion(obs, familySpeciesMap, orderSpeciesMap, allObs);
        if (q != null) questions.add(q);
      case QuizType.nameToPhoto:
        final q = _buildNameToPhotoQuestion(obs, familySpeciesMap, orderSpeciesMap, allObs);
        if (q != null) questions.add(q);
      case QuizType.familyId:
        final q = _buildFamilyIdQuestion(obs, allObs);
        if (q != null) questions.add(q);
    }
  }

  return questions;
}
```

Extract existing photo-to-name logic into `_buildPhotoToNameQuestion`. Add `_buildNameToPhotoQuestion`:

```dart
static QuizQuestion? _buildNameToPhotoQuestion(
  Observation obs,
  Map<int, List<TaxonSummary>> familySpeciesMap,
  Map<int, List<TaxonSummary>> orderSpeciesMap,
  List<Observation> allObservations,
) {
  final distractors = _pickDistractors(
    obs: obs,
    familySpeciesMap: familySpeciesMap,
    orderSpeciesMap: orderSpeciesMap,
    allObservations: allObservations,
  );

  // For nameToPhoto, distractors need photos
  final distractorsWithPhotos = distractors.where((t) => t.photoUrl != null).toList();
  if (distractorsWithPhotos.length < 3) return null;

  final correctChoice = AnswerChoice(
    commonName: obs.commonName ?? '',
    scientificName: obs.scientificName,
    photoUrl: obs.photoUrls.first,
    isCorrect: true,
  );

  final wrongChoices = distractorsWithPhotos.take(3).map((t) => AnswerChoice(
    commonName: t.commonName ?? '',
    scientificName: t.scientificName,
    photoUrl: t.photoUrl,
    isCorrect: false,
  )).toList();

  final choices = [correctChoice, ...wrongChoices]..shuffle(_random);

  return QuizQuestion(
    type: QuizType.nameToPhoto,
    taxonId: obs.taxonId,
    photoUrl: obs.photoUrls.first,
    allPhotoUrls: obs.photoUrls,
    correctCommonName: obs.commonName ?? obs.scientificName,
    correctScientificName: obs.scientificName,
    choices: choices,
  );
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/quiz_engine_test.dart -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/services/quiz_engine.dart test/services/quiz_engine_test.dart
git commit -m "feat: add nameToPhoto question generation to quiz engine"
```

---

### Task 4: Quiz Engine — Family ID Question Generation

**Files:**
- Modify: `lib/services/quiz_engine.dart`
- Modify: `test/services/quiz_engine_test.dart`

**Step 1: Write the failing test**

```dart
test('generateQuestions with familyId produces family name choices', () {
  final familySpecies = {
    42: [
      TaxonSummary(id: 100, scientificName: 'Canis lupus', commonName: 'Wolf'),
      TaxonSummary(id: 102, scientificName: 'Canis latrans', commonName: 'Coyote'),
      TaxonSummary(id: 103, scientificName: 'Lycaon pictus', commonName: 'African Wild Dog'),
      TaxonSummary(id: 104, scientificName: 'Cuon alpinus', commonName: 'Dhole'),
    ],
    55: [
      TaxonSummary(id: 200, scientificName: 'Aquila chrysaetos', commonName: 'Golden Eagle'),
      TaxonSummary(id: 201, scientificName: 'Haliaeetus leucocephalus', commonName: 'Bald Eagle'),
      TaxonSummary(id: 202, scientificName: 'Buteo jamaicensis', commonName: 'Red-tailed Hawk'),
      TaxonSummary(id: 203, scientificName: 'Accipiter cooperii', commonName: 'Cooper\'s Hawk'),
    ],
  };

  // Need 4+ unique families for distractors. Add more observations.
  final obsWithFamilies = [
    ...observations, // familyId 42 (Canidae) and 55 (Accipitridae)
    Observation(
      id: 4, taxonId: 300, scientificName: 'Rana temporaria',
      commonName: 'Common Frog', familyId: 66, familyName: 'Ranidae',
      iconicTaxonName: 'Amphibia',
      photoUrls: ['https://example.com/frog.jpg'],
    ),
    Observation(
      id: 5, taxonId: 400, scientificName: 'Salmo salar',
      commonName: 'Atlantic Salmon', familyId: 77, familyName: 'Salmonidae',
      iconicTaxonName: 'Actinopterygii',
      photoUrls: ['https://example.com/salmon.jpg'],
    ),
  ];

  final questions = QuizEngine.generateQuestions(
    observations: [observations[0]], // Wolf, familyId=42, familyName=Canidae
    familySpeciesMap: familySpecies,
    count: 1,
    allObservations: obsWithFamilies,
    quizType: QuizType.familyId,
  );

  expect(questions.length, 1);
  expect(questions[0].type, QuizType.familyId);
  // Correct answer should be the family name
  final correct = questions[0].choices.firstWhere((c) => c.isCorrect);
  expect(correct.commonName, 'Canidae');
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/quiz_engine_test.dart -v`
Expected: FAIL

**Step 3: Implement familyId question generation**

Add `_buildFamilyIdQuestion` to `quiz_engine.dart`:

```dart
static QuizQuestion? _buildFamilyIdQuestion(
  Observation obs,
  List<Observation> allObservations,
) {
  if (obs.familyId == null || obs.familyName == null) return null;

  // Collect other family names from observations (same iconic taxon preferred)
  final otherFamilies = <int, String>{};
  final shuffledObs = List<Observation>.from(allObservations)..shuffle(_random);

  // Prefer same iconic taxon
  for (final o in shuffledObs) {
    if (otherFamilies.length >= 3) break;
    if (o.familyId != null &&
        o.familyName != null &&
        o.familyId != obs.familyId &&
        !otherFamilies.containsKey(o.familyId) &&
        o.iconicTaxonName == obs.iconicTaxonName) {
      otherFamilies[o.familyId!] = o.familyName!;
    }
  }

  // Fill remaining from any iconic taxon
  for (final o in shuffledObs) {
    if (otherFamilies.length >= 3) break;
    if (o.familyId != null &&
        o.familyName != null &&
        o.familyId != obs.familyId &&
        !otherFamilies.containsKey(o.familyId)) {
      otherFamilies[o.familyId!] = o.familyName!;
    }
  }

  if (otherFamilies.length < 3) return null;

  final correctChoice = AnswerChoice(
    commonName: obs.familyName!,
    scientificName: obs.familyName!,
    isCorrect: true,
  );

  final wrongChoices = otherFamilies.values.take(3).map((name) => AnswerChoice(
    commonName: name,
    scientificName: name,
    isCorrect: false,
  )).toList();

  final choices = [correctChoice, ...wrongChoices]..shuffle(_random);

  return QuizQuestion(
    type: QuizType.familyId,
    taxonId: obs.taxonId,
    photoUrl: obs.photoUrls.first,
    allPhotoUrls: obs.photoUrls,
    correctCommonName: obs.commonName ?? obs.scientificName,
    correctScientificName: obs.scientificName,
    choices: choices,
  );
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/quiz_engine_test.dart -v`
Expected: ALL PASS

**Step 5: Run full test suite**

Run: `flutter test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add lib/services/quiz_engine.dart test/services/quiz_engine_test.dart
git commit -m "feat: add familyId question generation to quiz engine"
```

---

### Task 5: Playlist Model + Provider

**Files:**
- Create: `lib/models/playlist.dart`
- Create: `lib/providers/playlist_provider.dart`

**Step 1: Create Playlist model**

```dart
// lib/models/playlist.dart
class Playlist {
  final String id;
  final String name;
  final List<String> usernames;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.usernames,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'usernames': usernames,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        usernames: (json['usernames'] as List<dynamic>).cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
```

**Step 2: Create PlaylistProvider**

```dart
// lib/providers/playlist_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';

class PlaylistNotifier extends Notifier<List<Playlist>> {
  @override
  List<Playlist> build() {
    _loadFromFile();
    return [];
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/playlists.json');
  }

  Future<void> _loadFromFile() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final list = jsonDecode(contents) as List<dynamic>;
        state = list
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // If file is corrupted, start fresh
    }
  }

  Future<void> _saveToFile() async {
    final file = await _file;
    await file.writeAsString(jsonEncode(state.map((p) => p.toJson()).toList()));
  }

  Future<void> addPlaylist(Playlist playlist) async {
    state = [...state, playlist];
    await _saveToFile();
  }

  Future<void> removePlaylist(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _saveToFile();
  }

  Future<void> updatePlaylist(Playlist updated) async {
    state = state.map((p) => p.id == updated.id ? updated : p).toList();
    await _saveToFile();
  }
}

final playlistProvider = NotifierProvider<PlaylistNotifier, List<Playlist>>(
  PlaylistNotifier.new,
);
```

**Step 3: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/models/playlist.dart lib/providers/playlist_provider.dart
git commit -m "feat: add Playlist model and PlaylistProvider with file persistence"
```

---

### Task 6: Multi-User Observations Loading

**Files:**
- Modify: `lib/providers/observations_provider.dart`

**Step 1: Add fetchForUsers method**

Add a new method to `ObservationsNotifier` that fetches for multiple usernames and merges:

```dart
Future<void> fetchForUsers(List<String> usernames) async {
  state = state.copyWith(status: LoadingStatus.loading, loadedCount: 0);

  try {
    final api = ref.read(inaturalistApiProvider);
    final settings = ref.read(settingsProvider);
    final allObservations = <Observation>[];

    for (final username in usernames) {
      final observations = await api.fetchObservations(
        username: username,
        qualityGrade: settings.qualityGradeParam,
        locale: settings.locale,
      );
      allObservations.addAll(observations);
      state = state.copyWith(loadedCount: allObservations.length);
    }

    if (allObservations.isEmpty) {
      state = state.copyWith(
        status: LoadingStatus.error,
        errorMessage: 'No photo observations found.',
      );
      return;
    }

    final uniqueSpecies = allObservations.map((o) => o.taxonId).toSet();
    if (uniqueSpecies.length < 2) {
      state = state.copyWith(
        status: LoadingStatus.error,
        errorMessage:
            'Need observations of at least 2 species to generate a quiz.',
      );
      return;
    }

    state = state.copyWith(
      status: LoadingStatus.success,
      observations: allObservations,
      loadedCount: allObservations.length,
    );
  } on ApiException catch (_) {
    state = state.copyWith(
      status: LoadingStatus.error,
      errorMessage: 'Couldn\'t reach iNaturalist. Check your connection.',
    );
  } catch (_) {
    state = state.copyWith(
      status: LoadingStatus.error,
      errorMessage: 'Couldn\'t reach iNaturalist. Check your connection.',
    );
  }
}
```

Also add tracking fields for multi-user progress. Add to `ObservationsState`:

```dart
final int currentUserIndex;
final int totalUsers;

const ObservationsState({
  this.status = LoadingStatus.idle,
  this.observations = const [],
  this.errorMessage,
  this.loadedCount = 0,
  this.currentUserIndex = 0,
  this.totalUsers = 0,
});
```

Update `copyWith` accordingly. In `fetchForUsers`, update `currentUserIndex` and `totalUsers` as you iterate.

**Step 2: Run analyze and existing tests**

Run: `flutter analyze && flutter test`
Expected: ALL PASS (existing `fetchForUser` still works)

**Step 3: Commit**

```bash
git add lib/providers/observations_provider.dart
git commit -m "feat: add multi-user observation fetching to ObservationsProvider"
```

---

### Task 7: Quiz Provider — QuizType Support

**Files:**
- Modify: `lib/providers/quiz_provider.dart`

**Step 1: Pass QuizType through to quiz engine**

Update `generateQuiz` to read `quizType` from settings and pass it through:

```dart
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
      } catch (_) {}
    }

    final questions = QuizEngine.generateQuestions(
      observations: observations,
      familySpeciesMap: familySpeciesMap,
      count: settings.questionsPerQuiz,
      allObservations: observations,
      quizType: settings.quizType,  // NEW
    );

    // ... rest unchanged
  }
}
```

Do the same for `generateWeakQuiz`.

**Step 2: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add lib/providers/quiz_provider.dart
git commit -m "feat: pass QuizType from settings through quiz provider to engine"
```

---

### Task 8: Settings Provider — Quiz Type Persistence

**Files:**
- Modify: `lib/providers/settings_provider.dart`
- Modify: `test/providers/settings_provider_test.dart`

**Step 1: Add quiz type persistence to SettingsNotifier**

In `_loadFromPrefs`:
```dart
quizType: QuizType.values[prefs.getInt('quizType') ?? 0],
```

In `_saveToPrefs`:
```dart
await prefs.setInt('quizType', state.quizType.index);
```

Add method:
```dart
void updateQuizType(QuizType value) {
  state = state.copyWith(quizType: value);
  _saveToPrefs();
}
```

Import `QuizType` from `quiz_question.dart`.

**Step 2: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add lib/providers/settings_provider.dart
git commit -m "feat: persist quiz type setting"
```

---

### Task 9: Photo Answer Grid Widget

**Files:**
- Create: `lib/widgets/photo_answer_grid.dart`

**Step 1: Create the widget**

A 2x2 grid of tappable photos for nameToPhoto questions:

```dart
// lib/widgets/photo_answer_grid.dart
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
            border: borderColor != null
                ? Border.all(color: borderColor, width: borderWidth)
                : Border.all(color: Colors.grey.shade300),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/widgets/photo_answer_grid.dart
git commit -m "feat: add PhotoAnswerGrid widget for nameToPhoto questions"
```

---

### Task 10: Quiz Screen — Render by Question Type

**Files:**
- Modify: `lib/screens/quiz_screen.dart`

**Step 1: Update quiz screen body to branch on question type**

Import `PhotoAnswerGrid` and `QuizType`. Replace the static photo+buttons layout with a switch on `question.type`:

For `photoToName` (existing): photo on top, text answer buttons below.
For `nameToPhoto`: species name prompt on top, 2x2 photo grid below.
For `familyId`: photo on top, text answer buttons below (same layout as photoToName but the choices show family names — already handled by data).

```dart
// In the Column children, replace the Expanded(flex:3, child: PhotoViewer...) and Expanded(flex:2, child: ListView...) with:

if (question.type == QuizType.nameToPhoto) ...[
  // Name prompt
  Expanded(
    flex: 1,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.correctCommonName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (question.correctCommonName != question.correctScientificName)
            Text(
              question.correctScientificName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    ),
  ),
  const SizedBox(height: 8),
  // Photo grid
  Expanded(
    flex: 4,
    child: PhotoAnswerGrid(
      choices: question.choices,
      isAnswered: question.isAnswered,
      selectedIndex: question.selectedIndex,
      hapticEnabled: settings.hapticFeedback,
      onTap: (index) {
        ref.read(quizProvider.notifier).selectAnswer(index);
      },
    ),
  ),
] else ...[
  // Existing photoToName / familyId layout (photo + text buttons)
  Expanded(
    flex: 3,
    child: PhotoViewer(
      photoUrl: question.photoUrl,
      allPhotoUrls: question.allPhotoUrls,
      showSwipeHints: settings.photoSwipeHints,
    ),
  ),
  const SizedBox(height: 8),
  Expanded(
    flex: 2,
    child: ListView.separated(
      itemCount: question.choices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return AnswerButton(
          choice: question.choices[index],
          index: index,
          isAnswered: question.isAnswered,
          selectedIndex: question.selectedIndex,
          answerFormat: settings.answerFormat,
          hapticEnabled: settings.hapticFeedback,
          onTap: () {
            ref.read(quizProvider.notifier).selectAnswer(index);
          },
        );
      },
    ),
  ),
],
```

Add `final theme = Theme.of(context);` at the top of build if not already present.

**Step 2: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/screens/quiz_screen.dart
git commit -m "feat: quiz screen renders different layouts based on question type"
```

---

### Task 11: Home Screen — Quiz Type Selector + Multi-User Input

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Add state for multi-user chips and quiz type**

Convert from single text field to a chips-based multi-user input. Add state:

```dart
class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<String> _usernames = [];
```

**Step 2: Add quiz type selector**

Add a `SegmentedButton<QuizType>` below the username input area. Read/write from settings:

```dart
SegmentedButton<QuizType>(
  segments: const [
    ButtonSegment(value: QuizType.photoToName, label: Text('Photo'), icon: Icon(Icons.image)),
    ButtonSegment(value: QuizType.nameToPhoto, label: Text('Name'), icon: Icon(Icons.text_fields)),
    ButtonSegment(value: QuizType.familyId, label: Text('Family'), icon: Icon(Icons.account_tree)),
  ],
  selected: {ref.watch(settingsProvider).quizType},
  onSelectionChanged: (selected) {
    ref.read(settingsProvider.notifier).updateQuizType(selected.first);
  },
),
```

**Step 3: Add multi-user chip input**

When user submits a username (Enter or comma), add it as a chip above the text field. The text field clears. Chips have an X to remove. The "Start Quiz" button uses `_usernames` if non-empty, falls back to `_controller.text`:

```dart
void _addUsername() {
  final username = _controller.text.trim().replaceAll(',', '');
  if (username.isEmpty) return;
  if (!_usernames.contains(username)) {
    setState(() => _usernames.add(username));
  }
  _controller.clear();
}

void _startQuiz() {
  // If there's text in the field, add it first
  final pendingText = _controller.text.trim();
  if (pendingText.isNotEmpty && !_usernames.contains(pendingText)) {
    _usernames.add(pendingText);
    _controller.clear();
  }

  if (_usernames.isEmpty) {
    _formKey.currentState?.validate();
    return;
  }

  if (_usernames.length == 1) {
    context.go('/loading/${_usernames.first}');
  } else {
    // Encode usernames as comma-separated in the route
    final encoded = _usernames.join(',');
    context.go('/loading/$encoded');
  }
}
```

Show chips as a Wrap widget above the text field:

```dart
if (_usernames.isNotEmpty)
  Wrap(
    spacing: 8,
    runSpacing: 4,
    children: _usernames.map((username) => Chip(
      label: Text(username),
      onDeleted: () => setState(() => _usernames.remove(username)),
    )).toList(),
  ),
```

**Step 4: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: add quiz type selector and multi-user chip input to home screen"
```

---

### Task 12: Home Screen — Saved Playlists Section

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Add saved playlists section**

Below the "Recent" section, show saved playlists:

```dart
final playlists = ref.watch(playlistProvider);

if (playlists.isNotEmpty) ...[
  const SizedBox(height: 32),
  Align(
    alignment: Alignment.centerLeft,
    child: Text('Playlists', style: theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    )),
  ),
  const SizedBox(height: 8),
  ...playlists.map((playlist) => Card(
    child: ListTile(
      title: Text(playlist.name),
      subtitle: Text(playlist.usernames.join(', ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: () => _sharePlaylist(playlist),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(playlistProvider.notifier).removePlaylist(playlist.id),
          ),
        ],
      ),
      onTap: () {
        final encoded = playlist.usernames.join(',');
        context.go('/loading/$encoded');
      },
    ),
  )),
],
```

**Step 2: Add "Save as Playlist" button**

Show when `_usernames.length >= 2`:

```dart
if (_usernames.length >= 2)
  TextButton.icon(
    onPressed: () => _showSavePlaylistDialog(),
    icon: const Icon(Icons.playlist_add),
    label: const Text('Save as Playlist'),
  ),
```

Implement `_showSavePlaylistDialog` to prompt for a name and save:

```dart
void _showSavePlaylistDialog() {
  final nameController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save Playlist'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Playlist name'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            ref.read(playlistProvider.notifier).addPlaylist(Playlist(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              usernames: List.from(_usernames),
            ));
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
```

**Step 3: Add share method**

```dart
void _sharePlaylist(Playlist playlist) {
  final uri = Uri(
    scheme: 'inaturalistquiz',
    host: 'playlist',
    queryParameters: {
      'name': playlist.name,
      'users': playlist.usernames.join(','),
    },
  );
  Share.share('Check out my iNaturalist quiz playlist!\n$uri');
}
```

Add `share_plus` to `pubspec.yaml` dependencies:
```yaml
share_plus: ^10.1.4
```

Run `flutter pub get`.

**Step 4: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 5: Commit**

```bash
git add lib/screens/home_screen.dart pubspec.yaml pubspec.lock
git commit -m "feat: add saved playlists section and share to home screen"
```

---

### Task 13: Loading Screen — Multi-User Support

**Files:**
- Modify: `lib/screens/loading_screen.dart`
- Modify: `lib/router.dart`

**Step 1: Update LoadingScreen to accept multiple usernames**

Change the `username` field to `usernames`:

```dart
class LoadingScreen extends ConsumerStatefulWidget {
  final List<String> usernames;

  const LoadingScreen({super.key, required this.usernames});
```

Update `_loadAndGenerate`:

```dart
Future<void> _loadAndGenerate() async {
  // Save usernames to recents
  for (final username in widget.usernames) {
    ref.read(recentUsernamesProvider.notifier).addUsername(username);
  }

  // Fetch observations
  if (widget.usernames.length == 1) {
    await ref.read(observationsProvider.notifier).fetchForUser(widget.usernames.first);
  } else {
    await ref.read(observationsProvider.notifier).fetchForUsers(widget.usernames);
  }

  if (!mounted) return;

  final obsState = ref.read(observationsProvider);
  if (obsState.status == LoadingStatus.error) return;

  // Generate quiz
  await ref.read(quizProvider.notifier).generateQuiz(widget.usernames.join(', '));

  if (!mounted) return;

  final quizState = ref.read(quizProvider);
  if (quizState.session != null) {
    context.go('/quiz');
  }
}
```

Update AppBar title to show usernames:

```dart
title: Text(widget.usernames.length == 1
    ? widget.usernames.first
    : '${widget.usernames.length} users'),
```

Update loading progress text to show multi-user info:

```dart
if (obsState.status == LoadingStatus.loading)
  Text(
    obsState.totalUsers > 1
        ? 'Loading user ${obsState.currentUserIndex + 1}/${obsState.totalUsers}...'
        : 'Loading observations...',
    style: theme.textTheme.titleMedium,
  )
```

**Step 2: Update router**

In `lib/router.dart`, update the loading route to parse comma-separated usernames:

```dart
GoRoute(
  path: '/loading/:usernames',
  builder: (context, state) {
    final raw = state.pathParameters['usernames']!;
    final usernames = raw.split(',').where((s) => s.isNotEmpty).toList();
    return LoadingScreen(usernames: usernames);
  },
),
```

**Step 3: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add lib/screens/loading_screen.dart lib/router.dart
git commit -m "feat: loading screen supports multi-user observation fetching"
```

---

### Task 14: Settings Screen — Default Quiz Type

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Step 1: Add quiz type setting**

Add a `ListTile` with a `DropdownButton<QuizType>` to the settings screen, similar to the existing quality grade dropdown:

```dart
ListTile(
  title: const Text('Default quiz type'),
  leading: const Icon(Icons.category),
  subtitle: Text(_quizTypeLabel(settings.quizType)),
  trailing: DropdownButton<QuizType>(
    value: settings.quizType,
    underline: const SizedBox.shrink(),
    items: const [
      DropdownMenuItem(value: QuizType.photoToName, child: Text('Photo -> Name')),
      DropdownMenuItem(value: QuizType.nameToPhoto, child: Text('Name -> Photo')),
      DropdownMenuItem(value: QuizType.familyId, child: Text('Family ID')),
    ],
    onChanged: (value) {
      if (value != null) notifier.updateQuizType(value);
    },
  ),
),
const Divider(),
```

Add helper:
```dart
String _quizTypeLabel(QuizType type) {
  switch (type) {
    case QuizType.photoToName: return 'Photo to Name';
    case QuizType.nameToPhoto: return 'Name to Photo';
    case QuizType.familyId: return 'Family Identification';
  }
}
```

Import `QuizType` from `quiz_question.dart`.

**Step 2: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add default quiz type setting to settings screen"
```

---

### Task 15: Deep Link Handling

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/router.dart`
- Modify: `lib/screens/home_screen.dart` (minor — handle incoming playlist)

**Step 1: Add intent filter to AndroidManifest.xml**

Inside the `<activity>` tag, add a second `<intent-filter>` for the custom scheme:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="inaturalistquiz" android:host="playlist"/>
</intent-filter>
```

**Step 2: Add deep link route to GoRouter**

Add a route that handles the incoming playlist link and redirects to home with the playlist data:

```dart
GoRoute(
  path: '/import-playlist',
  builder: (context, state) {
    final name = state.uri.queryParameters['name'] ?? 'Shared Playlist';
    final users = state.uri.queryParameters['users']?.split(',') ?? [];
    return ImportPlaylistScreen(name: name, usernames: users);
  },
),
```

Create a minimal `ImportPlaylistScreen` that shows the playlist info and lets the user save or start it immediately. Alternatively, handle this in the router redirect to navigate to home with state.

Simpler approach — handle in GoRouter redirect:

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Handle deep link: inaturalistquiz://playlist?name=X&users=a,b
    if (state.uri.scheme == 'inaturalistquiz' && state.uri.host == 'playlist') {
      final name = state.uri.queryParameters['name'] ?? 'Shared Playlist';
      final users = state.uri.queryParameters['users'] ?? '';
      return '/import-playlist?name=$name&users=$users';
    }
    return null;
  },
  routes: [
    // ... existing routes ...
  ],
);
```

Actually, GoRouter handles deep links by matching route paths. For a custom scheme, use `GoRouter`'s initial location or route matching. The simplest approach:

Create `lib/screens/import_playlist_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/playlist.dart';
import '../providers/playlist_provider.dart';

class ImportPlaylistScreen extends ConsumerWidget {
  final String name;
  final List<String> usernames;

  const ImportPlaylistScreen({
    super.key,
    required this.name,
    required this.usernames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Import Playlist')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.playlist_add_check, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${usernames.length} users: ${usernames.join(", ")}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(playlistProvider.notifier).addPlaylist(Playlist(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    usernames: usernames,
                  ));
                  context.go('/');
                },
                icon: const Icon(Icons.save),
                label: const Text('Save & Go Home'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final encoded = usernames.join(',');
                  context.go('/loading/$encoded');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Quiz Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Add route in `lib/router.dart`:
```dart
GoRoute(
  path: '/import-playlist',
  builder: (context, state) {
    final name = state.uri.queryParameters['name'] ?? 'Shared Playlist';
    final users = (state.uri.queryParameters['users'] ?? '').split(',').where((s) => s.isNotEmpty).toList();
    return ImportPlaylistScreen(name: name, usernames: users);
  },
),
```

**Step 3: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml lib/router.dart lib/screens/import_playlist_screen.dart
git commit -m "feat: add deep link support for playlist sharing"
```

---

### Task 16: Final Integration Test

**Step 1: Run full test suite**

Run: `flutter test`
Expected: ALL PASS

**Step 2: Run analyze**

Run: `flutter analyze`
Expected: No issues

**Step 3: Manual testing on device**

Run: `flutter run -d <device_id>`

Test checklist:
- [ ] Photo-to-Name quiz works as before
- [ ] Name-to-Photo quiz shows species name, 4 photo tiles, correct answer highlighting
- [ ] Family ID quiz shows photo, 4 family name buttons
- [ ] Quiz type selector on home screen changes the quiz type
- [ ] Enter multiple usernames via chips, start quiz with combined observations
- [ ] Save a multi-user playlist, verify it appears in the list
- [ ] Tap saved playlist to start quiz
- [ ] Share playlist generates a deep link
- [ ] Settings screen shows quiz type dropdown
- [ ] Progress tracking still works with new quiz types

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete quiz types (nameToPhoto, familyId) + playlists with save/share"
```
