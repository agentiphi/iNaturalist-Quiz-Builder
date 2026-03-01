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

class INaturalistApi {
  static const _baseUrl = 'https://api.inaturalist.org/v1';
  final http.Client _client;

  INaturalistApi({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Observation>> fetchObservations({
    required String username,
    required String qualityGrade,
    String locale = 'en',
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
        'locale': locale,
        'per_page': perPage.toString(),
        'order': 'asc',
        'order_by': 'id',
        if (lastId != null) 'id_above': lastId.toString(),
      };

      final uri =
          Uri.parse('$_baseUrl/observations').replace(queryParameters: params);
      final response = await _client
          .get(uri, headers: {
            'Accept': 'application/json',
            'User-Agent': 'iNaturalistQuizApp/1.0',
          })
          .timeout(const Duration(seconds: 15));

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

      if (results.length < perPage) break;
    }

    return allObservations;
  }

  /// Batch-resolve ancestor IDs to populate family/order data on observations.
  /// The iNaturalist observations API returns ancestor_ids but not full ancestor
  /// objects. This fetches the taxa for those IDs and maps family/order back.
  Future<List<Observation>> resolveAncestry(List<Observation> observations) async {
    // Collect all unique ancestor IDs
    final allAncestorIds = <int>{};
    for (final obs in observations) {
      allAncestorIds.addAll(obs.ancestorIds);
    }

    if (allAncestorIds.isEmpty) return observations;

    // Batch-fetch taxa in parallel, chunked by 100 IDs
    final ancestorMap = <int, _AncestorInfo>{};
    final idList = allAncestorIds.toList();
    final chunks = <List<int>>[];
    for (var i = 0; i < idList.length; i += 100) {
      chunks.add(idList.skip(i).take(100).toList());
    }

    final futures = chunks.map((chunk) async {
      final ids = chunk.join(',');
      try {
        final uri = Uri.parse('$_baseUrl/taxa/$ids');
        final response = await _client
            .get(uri, headers: {
              'Accept': 'application/json',
              'User-Agent': 'iNaturalistQuizApp/1.0',
            })
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>;
          return results;
        }
      } catch (_) {
        // Skip failed chunk, we'll just miss some ancestry data
      }
      return <dynamic>[];
    });

    final results = await Future.wait(futures);
    for (final resultList in results) {
      for (final r in resultList) {
        final id = r['id'] as int;
        final rank = r['rank'] as String?;
        final name = r['name'] as String?;
        if (rank != null && name != null) {
          ancestorMap[id] = _AncestorInfo(rank: rank, name: name);
        }
      }
    }

    // Map family/order back to observations
    return observations.map((obs) {
      int? familyId;
      String? familyName;
      int? orderId;
      String? orderName;

      for (final id in obs.ancestorIds) {
        final info = ancestorMap[id];
        if (info == null) continue;
        if (info.rank == 'family') {
          familyId = id;
          familyName = info.name;
        } else if (info.rank == 'order') {
          orderId = id;
          orderName = info.name;
        }
      }

      if (familyId != null || orderId != null) {
        return obs.copyWith(
          familyId: familyId,
          familyName: familyName,
          orderId: orderId,
          orderName: orderName,
        );
      }
      return obs;
    }).toList();
  }

  Future<List<TaxonSummary>> fetchFamilySpecies({
    required int familyId,
    String locale = 'en',
    int perPage = 30,
  }) async {
    final params = {
      'taxon_id': familyId.toString(),
      'rank': 'species',
      'locale': locale,
      'per_page': perPage.toString(),
      'order_by': 'observations_count',
      'order': 'desc',
    };

    final uri = Uri.parse('$_baseUrl/taxa').replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: {
          'Accept': 'application/json',
          'User-Agent': 'iNaturalistQuizApp/1.0',
        })
        .timeout(const Duration(seconds: 15));

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

class _AncestorInfo {
  final String rank;
  final String name;
  const _AncestorInfo({required this.rank, required this.name});
}
