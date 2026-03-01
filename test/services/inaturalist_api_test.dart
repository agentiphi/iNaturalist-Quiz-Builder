import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
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

    test('fetchFamilySpecies parses default_photo.medium_url into photoUrl', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            'total_results': 2,
            'results': [
              {
                'id': 100,
                'name': 'Canis lupus',
                'preferred_common_name': 'Wolf',
                'default_photo': {
                  'medium_url': 'https://static.inaturalist.org/photos/100/medium.jpg',
                },
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
      expect(species[0].photoUrl, 'https://static.inaturalist.org/photos/100/medium.jpg');
      expect(species[1].photoUrl, isNull);
    });
  });
}
