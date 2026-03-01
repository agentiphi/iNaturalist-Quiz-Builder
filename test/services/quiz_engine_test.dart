import 'package:flutter_test/flutter_test.dart';
import 'package:inaturalist_quiz/models/observation.dart';
import 'package:inaturalist_quiz/models/quiz_question.dart';
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
        count: 100,
      );

      expect(questions.length, 3);
    });

    test('getUniqueFamilyIds returns distinct family IDs', () {
      final familyIds = QuizEngine.getUniqueFamilyIds(observations);
      expect(familyIds, containsAll([42, 55]));
      expect(familyIds.length, 2);
    });

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
      for (final choice in questions[0].choices) {
        expect(choice.photoUrl, isNotNull);
      }
      expect(questions[0].choices.where((c) => c.isCorrect).length, 1);
    });

    test('generateQuestions with familyId produces family name choices', () {
      final familySpecies = {
        42: [
          TaxonSummary(id: 100, scientificName: 'Canis lupus', commonName: 'Wolf'),
        ],
        55: [
          TaxonSummary(id: 200, scientificName: 'Aquila chrysaetos', commonName: 'Golden Eagle'),
        ],
      };

      // Need 4+ unique families
      final obsWithFamilies = [
        ...observations,
        Observation(id: 4, taxonId: 300, scientificName: 'Rana temporaria',
          commonName: 'Common Frog', familyId: 66, familyName: 'Ranidae',
          photoUrls: ['https://example.com/frog.jpg']),
        Observation(id: 5, taxonId: 400, scientificName: 'Salmo salar',
          commonName: 'Atlantic Salmon', familyId: 77, familyName: 'Salmonidae',
          photoUrls: ['https://example.com/salmon.jpg']),
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
      final correct = questions[0].choices.firstWhere((c) => c.isCorrect);
      expect(correct.scientificName, 'Canidae');
      expect(questions[0].choices.length, 4);
    });
  });
}
