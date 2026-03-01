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
          'ancestor_ids': [47126, 211194, 48150, 78212, 78213],
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
      expect(obs.orderId, isNull);
      expect(obs.ancestorIds, [47126, 211194, 48150, 78212, 78213]);
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
