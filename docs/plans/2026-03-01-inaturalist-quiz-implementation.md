# iNaturalist Quiz App — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Flutter app that generates species identification quizzes from any iNaturalist user's observation library.

**Architecture:** Stateless online-only app using Riverpod for state management. Fetches observations from iNaturalist public API, generates multiple-choice questions with same-family distractors, presents photo → name quizzes.

**Tech Stack:** Flutter 3.x, Riverpod (flutter_riverpod), http, cached_network_image, shared_preferences, go_router

---

## Project Structure

```
lib/
  main.dart
  app.dart
  theme.dart
  router.dart
  models/
    observation.dart
    quiz_question.dart
    quiz_session.dart
    settings.dart
  services/
    inaturalist_api.dart
    quiz_engine.dart
  providers/
    quiz_provider.dart
    settings_provider.dart
    observations_provider.dart
  screens/
    home_screen.dart
    loading_screen.dart
    quiz_screen.dart
    results_screen.dart
    settings_screen.dart
  widgets/
    answer_button.dart
    photo_viewer.dart
    score_badge.dart
test/
  models/
    observation_test.dart
  services/
    inaturalist_api_test.dart
    quiz_engine_test.dart
  providers/
    settings_provider_test.dart
```

---

### Task 1: Project Scaffolding & Dependencies

**Files:**
- Create: Flutter project via `flutter create`
- Modify: `pubspec.yaml`

**Step 1: Create Flutter project**

Run:
```bash
cd E:/Claude_Coding/inaturalist_quiz
flutter create --org com.inaturalist.quiz --project-name inaturalist_quiz .
```

**Step 2: Add dependencies to pubspec.yaml**

Replace the `dependencies` and `dev_dependencies` sections:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  http: ^1.2.2
  cached_network_image: ^3.4.1
  shared_preferences: ^2.3.4
  go_router: ^14.8.1
  shimmer: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4
```

**Step 3: Install dependencies**

Run: `flutter pub get`
Expected: "Got dependencies!"

**Step 4: Verify project builds**

Run: `flutter analyze`
Expected: No issues found

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

### Task 2: Data Models + JSON Parsing

**Files:**
- Create: `lib/models/observation.dart`
- Create: `lib/models/quiz_question.dart`
- Create: `lib/models/quiz_session.dart`
- Create: `lib/models/settings.dart`
- Test: `test/models/observation_test.dart`

**Step 1: Write the failing test for Observation model**

Create `test/models/observation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inaturalist_quiz/models/observation.dart';

void main() {
  group('Observation.fromJson', () {
    test('parses a valid observation JSON', () {
      final json = {
        'id': 340699057,
        'taxon': {
          'id': 78213,
          'name': 'Nemophila pulchella',
          'rank': 'species',
          'preferred_common_name': 'Eastwood\'s Baby Blue-eyes',
          'ancestors': [
            {'id': 47126, 'rank': 'kingdom', 'rank_level': 70, 'name': 'Plantae'},
            {'id': 211194, 'rank': 'phylum', 'rank_level': 60, 'name': 'Tracheophyta'},
            {'id': 48150, 'rank': 'family', 'rank_level': 30, 'name': 'Boraginaceae'},
            {'id': 78212, 'rank': 'genus', 'rank_level': 20, 'name': 'Nemophila'},
          ],
        },
        'photos': [
          {
            'id': 620049585,
            'url': 'https://inaturalist-open-data.s3.amazonaws.com/photos/620049585/square.jpg',
          },
        ],
      };

      final obs = Observation.fromJson(json);

      expect(obs.id, 340699057);
      expect(obs.taxonId, 78213);
      expect(obs.scientificName, 'Nemophila pulchella');
      expect(obs.commonName, 'Eastwood\'s Baby Blue-eyes');
      expect(obs.familyId, 48150);
      expect(obs.familyName, 'Boraginaceae');
      expect(obs.orderId, isNull); // no order in this trimmed ancestor list
      expect(obs.photoUrls.length, 1);
      expect(obs.photoUrls[0], contains('/medium.'));
    });

    test('returns null commonName when preferred_common_name is missing', () {
      final json = {
        'id': 1,
        'taxon': {
          'id': 100,
          'name': 'Foo bar',
          'rank': 'species',
          'ancestors': [],
        },
        'photos': [
          {'id': 1, 'url': 'https://example.com/photos/1/square.jpg'},
        ],
      };

      final obs = Observation.fromJson(json);
      expect(obs.commonName, isNull);
    });

    test('extracts medium photo URL from square URL', () {
      final json = {
        'id': 1,
        'taxon': {
          'id': 100,
          'name': 'Foo bar',
          'rank': 'species',
          'ancestors': [],
        },
        'photos': [
          {'id': 1, 'url': 'https://example.com/photos/1/square.jpg'},
          {'id': 2, 'url': 'https://example.com/photos/2/square.jpeg'},
        ],
      };

      final obs = Observation.fromJson(json);
      expect(obs.photoUrls[0], 'https://example.com/photos/1/medium.jpg');
      expect(obs.photoUrls[1], 'https://example.com/photos/2/medium.jpeg');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/observation_test.dart`
Expected: FAIL — cannot find `package:inaturalist_quiz/models/observation.dart`

**Step 3: Implement Observation model**

Create `lib/models/observation.dart`:

```dart
class Observation {
  final int id;
  final int taxonId;
  final String scientificName;
  final String? commonName;
  final int? familyId;
  final String? familyName;
  final int? orderId;
  final String? orderName;
  final List<String> photoUrls;

  const Observation({
    required this.id,
    required this.taxonId,
    required this.scientificName,
    this.commonName,
    this.familyId,
    this.familyName,
    this.orderId,
    this.orderName,
    required this.photoUrls,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    final taxon = json['taxon'] as Map<String, dynamic>;
    final ancestors = (taxon['ancestors'] as List<dynamic>?) ?? [];

    int? familyId;
    String? familyName;
    int? orderId;
    String? orderName;

    for (final ancestor in ancestors) {
      final rank = ancestor['rank'] as String?;
      if (rank == 'family') {
        familyId = ancestor['id'] as int;
        familyName = ancestor['name'] as String?;
      } else if (rank == 'order') {
        orderId = ancestor['id'] as int;
        orderName = ancestor['name'] as String?;
      }
    }

    final photos = (json['photos'] as List<dynamic>?) ?? [];
    final photoUrls = photos.map((p) {
      final url = p['url'] as String;
      // Convert square URL to medium for better quality
      return url.replaceFirst('/square.', '/medium.');
    }).toList();

    return Observation(
      id: json['id'] as int,
      taxonId: taxon['id'] as int,
      scientificName: taxon['name'] as String,
      commonName: taxon['preferred_common_name'] as String?,
      familyId: familyId,
      familyName: familyName,
      orderId: orderId,
      orderName: orderName,
      photoUrls: photoUrls,
    );
  }

  /// Display name: common name if available, otherwise scientific name.
  String get displayName => commonName ?? scientificName;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/observation_test.dart`
Expected: All tests pass

**Step 5: Create QuizQuestion model**

Create `lib/models/quiz_question.dart`:

```dart
class QuizQuestion {
  final String photoUrl;
  final String correctCommonName;
  final String correctScientificName;
  final List<AnswerChoice> choices;
  int? selectedIndex;

  QuizQuestion({
    required this.photoUrl,
    required this.correctCommonName,
    required this.correctScientificName,
    required this.choices,
  });

  bool get isAnswered => selectedIndex != null;

  bool get isCorrect =>
      selectedIndex != null && choices[selectedIndex!].isCorrect;

  AnswerChoice get correctChoice => choices.firstWhere((c) => c.isCorrect);
}

class AnswerChoice {
  final String commonName;
  final String scientificName;
  final bool isCorrect;

  const AnswerChoice({
    required this.commonName,
    required this.scientificName,
    required this.isCorrect,
  });

  /// Display name: common name if non-empty, otherwise scientific name.
  String get displayName =>
      commonName.isNotEmpty ? commonName : scientificName;
}
```

**Step 6: Create QuizSession model**

Create `lib/models/quiz_session.dart`:

```dart
import 'quiz_question.dart';

class QuizSession {
  final List<QuizQuestion> questions;
  final String username;
  int currentIndex;

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

  void advance() {
    if (currentIndex < questions.length) {
      currentIndex++;
    }
  }
}
```

**Step 7: Create Settings model**

Create `lib/models/settings.dart`:

```dart
enum QualityGrade { research, needsId, both }

enum AnswerFormat { commonOnly, scientificOnly, both }

class QuizSettings {
  final int questionsPerQuiz;
  final QualityGrade qualityGrade;
  final AnswerFormat answerFormat;
  final bool hapticFeedback;
  final bool photoSwipeHints;

  const QuizSettings({
    this.questionsPerQuiz = 20,
    this.qualityGrade = QualityGrade.research,
    this.answerFormat = AnswerFormat.both,
    this.hapticFeedback = true,
    this.photoSwipeHints = true,
  });

  QuizSettings copyWith({
    int? questionsPerQuiz,
    QualityGrade? qualityGrade,
    AnswerFormat? answerFormat,
    bool? hapticFeedback,
    bool? photoSwipeHints,
  }) {
    return QuizSettings(
      questionsPerQuiz: questionsPerQuiz ?? this.questionsPerQuiz,
      qualityGrade: qualityGrade ?? this.qualityGrade,
      answerFormat: answerFormat ?? this.answerFormat,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      photoSwipeHints: photoSwipeHints ?? this.photoSwipeHints,
    );
  }

  /// Quality grade query parameter value for the iNaturalist API.
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
```

**Step 8: Commit**

```bash
git add lib/models/ test/models/
git commit -m "feat: add data models with JSON parsing and tests"
```

---

### Task 3: iNaturalist API Service

**Files:**
- Create: `lib/services/inaturalist_api.dart`
- Test: `test/services/inaturalist_api_test.dart`

**Step 1: Write failing tests for the API service**

Create `test/services/inaturalist_api_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:inaturalist_quiz/models/observation.dart';
import 'package:inaturalist_quiz/services/inaturalist_api.dart';

void main() {
  group('INaturalistApi', () {
    test('fetchObservations parses response correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.host, 'api.inaturalist.org');
        expect(request.url.path, '/v1/observations');
        expect(request.url.queryParameters['user_id'], 'testuser');
        expect(request.url.queryParameters['photos'], 'true');

        return http.Response(
          jsonEncode({
            'total_results': 1,
            'results': [
              {
                'id': 1,
                'taxon': {
                  'id': 100,
                  'name': 'Canis lupus',
                  'rank': 'species',
                  'preferred_common_name': 'Wolf',
                  'ancestors': [
                    {'id': 42, 'rank': 'family', 'rank_level': 30, 'name': 'Canidae'},
                  ],
                },
                'photos': [
                  {'id': 1, 'url': 'https://example.com/photos/1/square.jpg'},
                ],
              },
            ],
          }),
          200,
        );
      });

      final api = INaturalistApi(client: mockClient);
      final observations = await api.fetchObservations(
        username: 'testuser',
        qualityGrade: 'research',
      );

      expect(observations.length, 1);
      expect(observations[0].scientificName, 'Canis lupus');
      expect(observations[0].commonName, 'Wolf');
      expect(observations[0].familyId, 42);
    });

    test('fetchObservations throws on non-200 response', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final api = INaturalistApi(client: mockClient);
      expect(
        () => api.fetchObservations(username: 'nobody', qualityGrade: 'research'),
        throwsA(isA<ApiException>()),
      );
    });

    test('fetchFamilySpecies returns list of TaxonSummary', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.queryParameters['taxon_id'], '42');
        expect(request.url.queryParameters['rank'], 'species');

        return http.Response(
          jsonEncode({
            'total_results': 2,
            'results': [
              {
                'id': 100,
                'name': 'Canis lupus',
                'preferred_common_name': 'Wolf',
              },
              {
                'id': 101,
                'name': 'Vulpes vulpes',
                'preferred_common_name': 'Red Fox',
              },
            ],
          }),
          200,
        );
      });

      final api = INaturalistApi(client: mockClient);
      final species = await api.fetchFamilySpecies(familyId: 42);

      expect(species.length, 2);
      expect(species[0].scientificName, 'Canis lupus');
      expect(species[1].commonName, 'Red Fox');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/inaturalist_api_test.dart`
Expected: FAIL — cannot import `inaturalist_api.dart`

**Step 3: Implement the API service**

Create `lib/services/inaturalist_api.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/observation.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Lightweight species info returned from the taxa endpoint.
class TaxonSummary {
  final int id;
  final String scientificName;
  final String? commonName;

  const TaxonSummary({
    required this.id,
    required this.scientificName,
    this.commonName,
  });

  factory TaxonSummary.fromJson(Map<String, dynamic> json) {
    return TaxonSummary(
      id: json['id'] as int,
      scientificName: json['name'] as String,
      commonName: json['preferred_common_name'] as String?,
    );
  }

  String get displayName => commonName ?? scientificName;
}

class INaturalistApi {
  static const _baseUrl = 'https://api.inaturalist.org/v1';
  final http.Client _client;

  INaturalistApi({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches observations for a given username. Returns all pages up to [maxObservations].
  Future<List<Observation>> fetchObservations({
    required String username,
    required String qualityGrade,
    int maxObservations = 500,
  }) async {
    final allObservations = <Observation>[];
    int? lastId;

    while (allObservations.length < maxObservations) {
      final perPage = (maxObservations - allObservations.length).clamp(1, 200);
      final params = {
        'user_id': username,
        'photos': 'true',
        'quality_grade': qualityGrade,
        'per_page': perPage.toString(),
        'order': 'asc',
        'order_by': 'id',
        if (lastId != null) 'id_above': lastId.toString(),
      };

      final uri = Uri.parse('$_baseUrl/observations').replace(queryParameters: params);
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'iNaturalistQuizApp/1.0',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch observations',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>;

      if (results.isEmpty) break;

      final observations = results
          .where((r) =>
              r['taxon'] != null &&
              r['photos'] != null &&
              (r['photos'] as List).isNotEmpty)
          .map((r) => Observation.fromJson(r as Map<String, dynamic>))
          .where((o) => o.photoUrls.isNotEmpty)
          .toList();

      allObservations.addAll(observations);
      lastId = results.last['id'] as int;

      // If we got fewer results than requested, we've reached the end
      if (results.length < perPage) break;
    }

    return allObservations;
  }

  /// Fetches species within a given taxon (family or order) for distractors.
  Future<List<TaxonSummary>> fetchFamilySpecies({
    required int familyId,
    int perPage = 30,
  }) async {
    final params = {
      'taxon_id': familyId.toString(),
      'rank': 'species',
      'per_page': perPage.toString(),
      'order_by': 'observations_count',
      'order': 'desc',
    };

    final uri = Uri.parse('$_baseUrl/taxa').replace(queryParameters: params);
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'iNaturalistQuizApp/1.0',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to fetch taxa',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;

    return results
        .map((r) => TaxonSummary.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/inaturalist_api_test.dart`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/services/inaturalist_api.dart test/services/inaturalist_api_test.dart
git commit -m "feat: add iNaturalist API service with pagination and tests"
```

---

### Task 4: Quiz Engine

**Files:**
- Create: `lib/services/quiz_engine.dart`
- Test: `test/services/quiz_engine_test.dart`

**Step 1: Write failing tests for the quiz engine**

Create `test/services/quiz_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inaturalist_quiz/models/observation.dart';
import 'package:inaturalist_quiz/services/inaturalist_api.dart';
import 'package:inaturalist_quiz/services/quiz_engine.dart';

void main() {
  group('QuizEngine', () {
    final observations = [
      Observation(
        id: 1,
        taxonId: 100,
        scientificName: 'Canis lupus',
        commonName: 'Wolf',
        familyId: 42,
        familyName: 'Canidae',
        photoUrls: ['https://example.com/wolf.jpg'],
      ),
      Observation(
        id: 2,
        taxonId: 101,
        scientificName: 'Vulpes vulpes',
        commonName: 'Red Fox',
        familyId: 42,
        familyName: 'Canidae',
        photoUrls: ['https://example.com/fox.jpg'],
      ),
      Observation(
        id: 3,
        taxonId: 200,
        scientificName: 'Aquila chrysaetos',
        commonName: 'Golden Eagle',
        familyId: 55,
        familyName: 'Accipitridae',
        photoUrls: ['https://example.com/eagle.jpg'],
      ),
    ];

    test('generateQuestions produces correct number of questions', () {
      final familySpecies = {
        42: [
          TaxonSummary(id: 100, scientificName: 'Canis lupus', commonName: 'Wolf'),
          TaxonSummary(id: 101, scientificName: 'Vulpes vulpes', commonName: 'Red Fox'),
          TaxonSummary(id: 102, scientificName: 'Canis latrans', commonName: 'Coyote'),
          TaxonSummary(id: 103, scientificName: 'Lycaon pictus', commonName: 'African Wild Dog'),
        ],
        55: [
          TaxonSummary(id: 200, scientificName: 'Aquila chrysaetos', commonName: 'Golden Eagle'),
          TaxonSummary(id: 201, scientificName: 'Haliaeetus leucocephalus', commonName: 'Bald Eagle'),
          TaxonSummary(id: 202, scientificName: 'Buteo jamaicensis', commonName: 'Red-tailed Hawk'),
          TaxonSummary(id: 203, scientificName: 'Accipiter cooperii', commonName: 'Cooper\'s Hawk'),
        ],
      };

      final questions = QuizEngine.generateQuestions(
        observations: observations,
        familySpeciesMap: familySpecies,
        count: 3,
      );

      expect(questions.length, 3);
    });

    test('each question has exactly 4 choices with 1 correct', () {
      final familySpecies = {
        42: [
          TaxonSummary(id: 100, scientificName: 'Canis lupus', commonName: 'Wolf'),
          TaxonSummary(id: 101, scientificName: 'Vulpes vulpes', commonName: 'Red Fox'),
          TaxonSummary(id: 102, scientificName: 'Canis latrans', commonName: 'Coyote'),
          TaxonSummary(id: 103, scientificName: 'Lycaon pictus', commonName: 'African Wild Dog'),
        ],
        55: [
          TaxonSummary(id: 200, scientificName: 'Aquila chrysaetos', commonName: 'Golden Eagle'),
          TaxonSummary(id: 201, scientificName: 'Haliaeetus leucocephalus', commonName: 'Bald Eagle'),
          TaxonSummary(id: 202, scientificName: 'Buteo jamaicensis', commonName: 'Red-tailed Hawk'),
          TaxonSummary(id: 203, scientificName: 'Accipiter cooperii', commonName: 'Cooper\'s Hawk'),
        ],
      };

      final questions = QuizEngine.generateQuestions(
        observations: observations,
        familySpeciesMap: familySpecies,
        count: 3,
      );

      for (final q in questions) {
        expect(q.choices.length, 4);
        expect(q.choices.where((c) => c.isCorrect).length, 1);
      }
    });

    test('correct answer matches the observation species', () {
      final familySpecies = {
        42: [
          TaxonSummary(id: 100, scientificName: 'Canis lupus', commonName: 'Wolf'),
          TaxonSummary(id: 102, scientificName: 'Canis latrans', commonName: 'Coyote'),
          TaxonSummary(id: 103, scientificName: 'Lycaon pictus', commonName: 'African Wild Dog'),
          TaxonSummary(id: 104, scientificName: 'Cuon alpinus', commonName: 'Dhole'),
        ],
      };

      final singleObs = [observations[0]]; // Wolf
      final questions = QuizEngine.generateQuestions(
        observations: singleObs,
        familySpeciesMap: familySpecies,
        count: 1,
      );

      final correct = questions[0].choices.firstWhere((c) => c.isCorrect);
      expect(correct.scientificName, 'Canis lupus');
      expect(correct.commonName, 'Wolf');
    });

    test('limits questions to available observations', () {
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

      final questions = QuizEngine.generateQuestions(
        observations: observations,
        familySpeciesMap: familySpecies,
        count: 100, // way more than available
      );

      expect(questions.length, 3);
    });

    test('getUniqueFamilyIds returns distinct family IDs', () {
      final familyIds = QuizEngine.getUniqueFamilyIds(observations);
      expect(familyIds, containsAll([42, 55]));
      expect(familyIds.length, 2);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/quiz_engine_test.dart`
Expected: FAIL — cannot import quiz_engine.dart

**Step 3: Implement the quiz engine**

Create `lib/services/quiz_engine.dart`:

```dart
import 'dart:math';

import '../models/observation.dart';
import '../models/quiz_question.dart';
import 'inaturalist_api.dart';

class QuizEngine {
  static final _random = Random();

  /// Extracts unique family IDs (and order IDs as fallback) from observations.
  static List<int> getUniqueFamilyIds(List<Observation> observations) {
    return observations
        .where((o) => o.familyId != null)
        .map((o) => o.familyId!)
        .toSet()
        .toList();
  }

  /// Generates quiz questions from observations and a pre-fetched map of
  /// family ID → list of species in that family.
  static List<QuizQuestion> generateQuestions({
    required List<Observation> observations,
    required Map<int, List<TaxonSummary>> familySpeciesMap,
    required int count,
    List<Observation>? allObservations,
  }) {
    // Shuffle and limit to requested count
    final shuffled = List<Observation>.from(observations)..shuffle(_random);
    final selected = shuffled.take(count).toList();

    final questions = <QuizQuestion>[];

    for (final obs in selected) {
      final distractors = _pickDistractors(
        obs: obs,
        familySpeciesMap: familySpeciesMap,
        allObservations: allObservations ?? observations,
      );

      if (distractors.length < 3) continue; // skip if we can't make 4 choices

      final correctChoice = AnswerChoice(
        commonName: obs.commonName ?? '',
        scientificName: obs.scientificName,
        isCorrect: true,
      );

      final wrongChoices = distractors.map((t) => AnswerChoice(
        commonName: t.commonName ?? '',
        scientificName: t.scientificName,
        isCorrect: false,
      )).toList();

      final choices = [correctChoice, ...wrongChoices]..shuffle(_random);

      questions.add(QuizQuestion(
        photoUrl: obs.photoUrls.first,
        correctCommonName: obs.commonName ?? obs.scientificName,
        correctScientificName: obs.scientificName,
        choices: choices,
      ));
    }

    return questions;
  }

  /// Picks 3 distractor species for a given observation.
  /// Strategy: same family first, fall back to other user observations.
  static List<TaxonSummary> _pickDistractors({
    required Observation obs,
    required Map<int, List<TaxonSummary>> familySpeciesMap,
    required List<Observation> allObservations,
  }) {
    final distractors = <TaxonSummary>[];

    // Try same family
    if (obs.familyId != null && familySpeciesMap.containsKey(obs.familyId)) {
      final siblings = familySpeciesMap[obs.familyId]!
          .where((t) => t.id != obs.taxonId)
          .toList()
        ..shuffle(_random);
      distractors.addAll(siblings.take(3));
    }

    // If not enough, try order-level species
    if (distractors.length < 3 && obs.orderId != null && familySpeciesMap.containsKey(obs.orderId)) {
      final orderSiblings = familySpeciesMap[obs.orderId]!
          .where((t) => t.id != obs.taxonId && !distractors.any((d) => d.id == t.id))
          .toList()
        ..shuffle(_random);
      distractors.addAll(orderSiblings.take(3 - distractors.length));
    }

    // Last resort: use other species from the user's observations
    if (distractors.length < 3) {
      final otherObs = allObservations
          .where((o) => o.taxonId != obs.taxonId && !distractors.any((d) => d.id == o.taxonId))
          .toList()
        ..shuffle(_random);

      for (final o in otherObs) {
        if (distractors.length >= 3) break;
        distractors.add(TaxonSummary(
          id: o.taxonId,
          scientificName: o.scientificName,
          commonName: o.commonName,
        ));
      }
    }

    return distractors.take(3).toList();
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/quiz_engine_test.dart`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/services/quiz_engine.dart test/services/quiz_engine_test.dart
git commit -m "feat: add quiz engine with distractor generation and tests"
```

---

### Task 5: Theme, Router, and App Shell

**Files:**
- Create: `lib/theme.dart`
- Create: `lib/router.dart`
- Create: `lib/app.dart`
- Modify: `lib/main.dart`

**Step 1: Create the app theme**

Create `lib/theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF4CAF50); // Nature green

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
```

**Step 2: Create the router**

Create `lib/router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/results_screen.dart';
import 'screens/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/loading/:username',
      builder: (context, state) {
        final username = state.pathParameters['username']!;
        return LoadingScreen(username: username);
      },
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
```

**Step 3: Create the app widget**

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class INaturalistQuizApp extends StatelessWidget {
  const INaturalistQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'iNaturalist Quiz',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

**Step 4: Update main.dart**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: INaturalistQuizApp(),
    ),
  );
}
```

**Step 5: Create placeholder screens (so router compiles)**

Create minimal placeholder files for each screen — just a `Scaffold` with a `Text` center. These will be fleshed out in subsequent tasks.

`lib/screens/home_screen.dart`:
```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Home')));
  }
}
```

Same pattern for `loading_screen.dart`, `quiz_screen.dart`, `results_screen.dart`, `settings_screen.dart` (with appropriate class names and constructor params — `LoadingScreen` takes `required String username`).

**Step 6: Verify it compiles**

Run: `flutter analyze`
Expected: No issues found

**Step 7: Commit**

```bash
git add lib/
git commit -m "feat: add theme, router, app shell, and placeholder screens"
```

---

### Task 6: Settings Provider

**Files:**
- Create: `lib/providers/settings_provider.dart`
- Test: `test/providers/settings_provider_test.dart`

**Step 1: Write failing test**

Create `test/providers/settings_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inaturalist_quiz/models/settings.dart';
import 'package:inaturalist_quiz/providers/settings_provider.dart';

void main() {
  group('SettingsNotifier', () {
    test('has correct defaults', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = SettingsNotifier();
      final settings = notifier.state;

      expect(settings.questionsPerQuiz, 20);
      expect(settings.qualityGrade, QualityGrade.research);
      expect(settings.answerFormat, AnswerFormat.both);
      expect(settings.hapticFeedback, true);
      expect(settings.photoSwipeHints, true);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/providers/settings_provider_test.dart`
Expected: FAIL

**Step 3: Implement settings provider**

Create `lib/providers/settings_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsNotifier extends Notifier<QuizSettings> {
  @override
  QuizSettings build() {
    _loadFromPrefs();
    return const QuizSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = QuizSettings(
      questionsPerQuiz: prefs.getInt('questionsPerQuiz') ?? 20,
      qualityGrade: QualityGrade.values[prefs.getInt('qualityGrade') ?? 0],
      answerFormat: AnswerFormat.values[prefs.getInt('answerFormat') ?? 2],
      hapticFeedback: prefs.getBool('hapticFeedback') ?? true,
      photoSwipeHints: prefs.getBool('photoSwipeHints') ?? true,
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('questionsPerQuiz', state.questionsPerQuiz);
    await prefs.setInt('qualityGrade', state.qualityGrade.index);
    await prefs.setInt('answerFormat', state.answerFormat.index);
    await prefs.setBool('hapticFeedback', state.hapticFeedback);
    await prefs.setBool('photoSwipeHints', state.photoSwipeHints);
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
}

final settingsProvider = NotifierProvider<SettingsNotifier, QuizSettings>(
  SettingsNotifier.new,
);

/// Provider for recent usernames stored in SharedPreferences.
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
```

**Step 4: Run tests**

Run: `flutter test test/providers/settings_provider_test.dart`
Expected: All pass

**Step 5: Commit**

```bash
git add lib/providers/settings_provider.dart test/providers/settings_provider_test.dart
git commit -m "feat: add settings and recent usernames providers with persistence"
```

---

### Task 7: Quiz Provider (Orchestration)

**Files:**
- Create: `lib/providers/quiz_provider.dart`
- Create: `lib/providers/observations_provider.dart`

**Step 1: Create observations provider**

Create `lib/providers/observations_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/observation.dart';
import '../services/inaturalist_api.dart';
import 'settings_provider.dart';

final inaturalistApiProvider = Provider<INaturalistApi>((ref) {
  return INaturalistApi();
});

enum LoadingStatus { idle, loading, success, error }

class ObservationsState {
  final LoadingStatus status;
  final List<Observation> observations;
  final String? errorMessage;
  final int loadedCount;

  const ObservationsState({
    this.status = LoadingStatus.idle,
    this.observations = const [],
    this.errorMessage,
    this.loadedCount = 0,
  });

  ObservationsState copyWith({
    LoadingStatus? status,
    List<Observation>? observations,
    String? errorMessage,
    int? loadedCount,
  }) {
    return ObservationsState(
      status: status ?? this.status,
      observations: observations ?? this.observations,
      errorMessage: errorMessage,
      loadedCount: loadedCount ?? this.loadedCount,
    );
  }
}

class ObservationsNotifier extends Notifier<ObservationsState> {
  @override
  ObservationsState build() => const ObservationsState();

  Future<void> fetchForUser(String username) async {
    state = state.copyWith(status: LoadingStatus.loading, loadedCount: 0);

    try {
      final api = ref.read(inaturalistApiProvider);
      final settings = ref.read(settingsProvider);

      final observations = await api.fetchObservations(
        username: username,
        qualityGrade: settings.qualityGradeParam,
      );

      if (observations.isEmpty) {
        state = state.copyWith(
          status: LoadingStatus.error,
          errorMessage: 'No photo observations found for "$username".',
        );
        return;
      }

      // Check if we have at least 2 species
      final uniqueSpecies = observations.map((o) => o.taxonId).toSet();
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
        observations: observations,
        loadedCount: observations.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoadingStatus.error,
        errorMessage: e.statusCode == 404
            ? 'No user found with that name.'
            : 'Couldn\'t reach iNaturalist. Check your connection.',
      );
    } catch (e) {
      state = state.copyWith(
        status: LoadingStatus.error,
        errorMessage: 'Couldn\'t reach iNaturalist. Check your connection.',
      );
    }
  }
}

final observationsProvider =
    NotifierProvider<ObservationsNotifier, ObservationsState>(
  ObservationsNotifier.new,
);
```

**Step 2: Create quiz provider**

Create `lib/providers/quiz_provider.dart`:

```dart
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

  /// Generates a quiz from the loaded observations.
  Future<void> generateQuiz(String username) async {
    state = const QuizState(isGenerating: true);

    try {
      final api = ref.read(inaturalistApiProvider);
      final observations = ref.read(observationsProvider).observations;
      final settings = ref.read(settingsProvider);

      // Get unique family IDs and fetch species for each
      final familyIds = QuizEngine.getUniqueFamilyIds(observations);
      final familySpeciesMap = <int, List<TaxonSummary>>{};

      for (final familyId in familyIds) {
        try {
          final species = await api.fetchFamilySpecies(familyId: familyId);
          familySpeciesMap[familyId] = species;
        } catch (_) {
          // If a single family fetch fails, skip it — we have fallbacks
        }
      }

      final questions = QuizEngine.generateQuestions(
        observations: observations,
        familySpeciesMap: familySpeciesMap,
        count: settings.questionsPerQuiz,
        allObservations: observations,
      );

      if (questions.isEmpty) {
        state = const QuizState(
          errorMessage: 'Couldn\'t generate quiz questions. Try a different user.',
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

    question.selectedIndex = choiceIndex;
    // Force state update by creating new QuizState
    state = QuizState(session: session);
  }

  void nextQuestion() {
    final session = state.session;
    if (session == null) return;

    session.advance();
    state = QuizState(session: session);
  }
}

final quizProvider = NotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);
```

**Step 3: Verify compilation**

Run: `flutter analyze`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/providers/
git commit -m "feat: add observations and quiz state providers"
```

---

### Task 8: Home Screen

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Implement the home screen**

Replace `lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startQuiz() {
    if (!_formKey.currentState!.validate()) return;
    final username = _controller.text.trim();
    context.go('/loading/$username');
  }

  @override
  Widget build(BuildContext context) {
    final recentUsernames = ref.watch(recentUsernamesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('iNaturalist Quiz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Test your species knowledge!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter an iNaturalist username to quiz yourself on their observations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'iNaturalist Username',
                  hintText: 'e.g. kueda',
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.go,
                onFieldSubmitted: (_) => _startQuiz(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Quiz'),
            ),
            if (recentUsernames.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: recentUsernames.map((username) {
                  return ActionChip(
                    label: Text(username),
                    avatar: const Icon(Icons.history, size: 18),
                    onPressed: () {
                      _controller.text = username;
                      _startQuiz();
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: implement home screen with username input and recents"
```

---

### Task 9: Loading Screen

**Files:**
- Modify: `lib/screens/loading_screen.dart`

**Step 1: Implement the loading screen**

Replace `lib/screens/loading_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/observations_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  final String username;

  const LoadingScreen({super.key, required this.username});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _loadAndGenerate();
  }

  Future<void> _loadAndGenerate() async {
    // Save username to recents
    ref.read(recentUsernamesProvider.notifier).addUsername(widget.username);

    // Fetch observations
    await ref.read(observationsProvider.notifier).fetchForUser(widget.username);

    if (!mounted) return;

    final obsState = ref.read(observationsProvider);
    if (obsState.status == LoadingStatus.error) return; // stay on screen to show error

    // Generate quiz
    await ref.read(quizProvider.notifier).generateQuiz(widget.username);

    if (!mounted) return;

    final quizState = ref.read(quizProvider);
    if (quizState.session != null) {
      context.go('/quiz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final obsState = ref.watch(observationsProvider);
    final quizState = ref.watch(quizProvider);
    final theme = Theme.of(context);

    final hasError = obsState.status == LoadingStatus.error ||
        quizState.errorMessage != null;
    final errorMessage =
        obsState.errorMessage ?? quizState.errorMessage ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(widget.username),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!hasError) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                if (obsState.status == LoadingStatus.loading)
                  Text(
                    'Loading observations...',
                    style: theme.textTheme.titleMedium,
                  )
                else if (quizState.isGenerating) ...[
                  Text(
                    '${obsState.loadedCount} observations found',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generating quiz...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ] else ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadAndGenerate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/screens/loading_screen.dart
git commit -m "feat: implement loading screen with fetch and error states"
```

---

### Task 10: Quiz Screen + Widgets

**Files:**
- Modify: `lib/screens/quiz_screen.dart`
- Create: `lib/widgets/answer_button.dart`
- Create: `lib/widgets/photo_viewer.dart`
- Create: `lib/widgets/score_badge.dart`

**Step 1: Create AnswerButton widget**

Create `lib/widgets/answer_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quiz_question.dart';
import '../models/settings.dart';

class AnswerButton extends StatelessWidget {
  final AnswerChoice choice;
  final int index;
  final bool isAnswered;
  final int? selectedIndex;
  final AnswerFormat answerFormat;
  final bool hapticEnabled;
  final VoidCallback onTap;

  const AnswerButton({
    super.key,
    required this.choice,
    required this.index,
    required this.isAnswered,
    required this.selectedIndex,
    required this.answerFormat,
    required this.hapticEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color? backgroundColor;
    Color? foregroundColor;
    double opacity = 1.0;

    if (isAnswered) {
      if (choice.isCorrect) {
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade900;
      } else if (selectedIndex == index) {
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade900;
      } else {
        opacity = 0.4;
      }
    }

    return Opacity(
      opacity: opacity,
      child: Card(
        color: backgroundColor,
        child: InkWell(
          onTap: isAnswered
              ? null
              : () {
                  if (hapticEnabled) {
                    HapticFeedback.lightImpact();
                  }
                  onTap();
                },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (isAnswered) ...[
                  Icon(
                    choice.isCorrect
                        ? Icons.check_circle
                        : (selectedIndex == index
                            ? Icons.cancel
                            : Icons.circle_outlined),
                    color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (answerFormat != AnswerFormat.scientificOnly &&
                          choice.commonName.isNotEmpty)
                        Text(
                          choice.commonName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (answerFormat != AnswerFormat.commonOnly)
                        Text(
                          choice.scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foregroundColor?.withValues(alpha: 0.8) ??
                                theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
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

**Step 2: Create PhotoViewer widget**

Create `lib/widgets/photo_viewer.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PhotoViewer extends StatelessWidget {
  final String photoUrl;
  final bool showSwipeHints;

  const PhotoViewer({
    super.key,
    required this.photoUrl,
    this.showSwipeHints = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(color: Colors.white),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Photo unavailable', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Create ScoreBadge widget**

Create `lib/widgets/score_badge.dart`:

```dart
import 'package:flutter/material.dart';

class ScoreBadge extends StatelessWidget {
  final int score;
  final int total;

  const ScoreBadge({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$score / $total',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

**Step 4: Implement the quiz screen**

Replace `lib/screens/quiz_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/answer_button.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/score_badge.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizProvider);
    final settings = ref.watch(settingsProvider);
    final session = quizState.session;
    final theme = Theme.of(context);

    if (session == null) {
      // Shouldn't happen — navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }

    if (session.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/results'));
      return const SizedBox.shrink();
    }

    final question = session.currentQuestion;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showQuitDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showQuitDialog(context),
          ),
          title: Text('${session.currentIndex + 1} / ${session.totalQuestions}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ScoreBadge(
                score: session.score,
                total: session.answeredCount,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Photo area
                Expanded(
                  flex: 3,
                  child: PhotoViewer(
                    photoUrl: question.photoUrl,
                    showSwipeHints: settings.photoSwipeHints,
                  ),
                ),
                const SizedBox(height: 16),
                // Question prompt
                Text(
                  'What species is this?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                // Answer buttons
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
                // Next button
                if (question.isAnswered)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(quizProvider.notifier).nextQuestion();
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        session.currentIndex + 1 >= session.totalQuestions
                            ? 'See Results'
                            : 'Next',
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

  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Quiz?'),
        content: const Text('Progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }
}
```

**Step 5: Verify compilation**

Run: `flutter analyze`
Expected: No issues

**Step 6: Commit**

```bash
git add lib/screens/quiz_screen.dart lib/widgets/
git commit -m "feat: implement quiz screen with answer buttons, photo viewer, and score badge"
```

---

### Task 11: Results Screen

**Files:**
- Modify: `lib/screens/results_screen.dart`

**Step 1: Implement the results screen**

Replace `lib/screens/results_screen.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/quiz_provider.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizProvider);
    final session = quizState.session;
    final theme = Theme.of(context);

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }

    final missed = session.missedQuestions;
    final percentage = session.scorePercentage.round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score section
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    '$percentage%',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: percentage >= 70
                          ? Colors.green.shade700
                          : percentage >= 40
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.score} / ${session.totalQuestions} correct',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            // Missed questions section
            if (missed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Review missed (${missed.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: missed.length,
                  itemBuilder: (context, index) {
                    final question = missed[index];
                    final selected = question.selectedIndex != null
                        ? question.choices[question.selectedIndex!]
                        : null;
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: question.photoUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 24),
                            ),
                          ),
                        ),
                        title: Text(
                          question.correctCommonName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question.correctScientificName,
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                            if (selected != null)
                              Text(
                                'You picked: ${selected.displayName}',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, size: 64, color: Colors.amber.shade600),
                      const SizedBox(height: 16),
                      Text('Perfect score!', style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
              ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home),
                      label: const Text('New User'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final username = session.username;
                        context.go('/loading/$username');
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/screens/results_screen.dart
git commit -m "feat: implement results screen with score and missed review"
```

---

### Task 12: Settings Screen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Step 1: Implement the settings screen**

Replace `lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/settings.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

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
          // Questions per quiz
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

          // Quality grade
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

          // Answer format
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

          // Haptic feedback
          SwitchListTile(
            title: const Text('Haptic feedback'),
            subtitle: const Text('Vibrate on answer tap'),
            secondary: const Icon(Icons.vibration),
            value: settings.hapticFeedback,
            onChanged: (_) => notifier.toggleHapticFeedback(),
          ),
          const Divider(),

          // Photo swipe hints
          SwitchListTile(
            title: const Text('Photo swipe hints'),
            subtitle: const Text('Show dot indicators on multi-photo observations'),
            secondary: const Icon(Icons.swipe),
            value: settings.photoSwipeHints,
            onChanged: (_) => notifier.togglePhotoSwipeHints(),
          ),
        ],
      ),
    );
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
```

**Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: implement settings screen with all configurable options"
```

---

### Task 13: Integration — Handle questionsPerQuiz=0 (All) + Final Wiring

**Files:**
- Modify: `lib/providers/quiz_provider.dart` — handle `questionsPerQuiz == 0` meaning "all"
- Modify: `lib/services/quiz_engine.dart` — handle `count == 0`

**Step 1: Update quiz engine to handle count=0**

In `lib/services/quiz_engine.dart`, update `generateQuestions`:

```dart
// At the top of generateQuestions, replace the take line:
final effectiveCount = count == 0 ? shuffled.length : count;
final selected = shuffled.take(effectiveCount).toList();
```

**Step 2: Verify all tests still pass**

Run: `flutter test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add lib/services/quiz_engine.dart lib/providers/quiz_provider.dart
git commit -m "feat: support 'all questions' mode when count is 0"
```

---

### Task 14: Run Full Test Suite + Final Verification

**Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues

**Step 3: Test on device/emulator**

Run: `flutter run`
Manual verification:
- Home screen loads with text field and settings icon
- Enter "kueda" → loading screen appears → quiz starts
- 4 answer buttons with species names
- Tapping answer shows green/red feedback
- Next button advances to next question
- Results screen shows score and missed review
- Settings screen allows changing all options
- Recent usernames appear as chips on home screen

**Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```
