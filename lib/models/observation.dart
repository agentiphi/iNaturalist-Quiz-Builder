class Observation {
  final int id;
  final int taxonId;
  final String scientificName;
  final String? commonName;
  final int? familyId;
  final String? familyName;
  final int? orderId;
  final String? orderName;
  final String? iconicTaxonName;
  final List<String> photoUrls;
  final List<int> ancestorIds;

  const Observation({
    required this.id,
    required this.taxonId,
    required this.scientificName,
    this.commonName,
    this.familyId,
    this.familyName,
    this.orderId,
    this.orderName,
    this.iconicTaxonName,
    required this.photoUrls,
    this.ancestorIds = const [],
  });

  Observation copyWith({
    int? familyId,
    String? familyName,
    int? orderId,
    String? orderName,
  }) {
    return Observation(
      id: id,
      taxonId: taxonId,
      scientificName: scientificName,
      commonName: commonName,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      orderId: orderId ?? this.orderId,
      orderName: orderName ?? this.orderName,
      iconicTaxonName: iconicTaxonName,
      photoUrls: photoUrls,
      ancestorIds: ancestorIds,
    );
  }

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

    final ancestorIds = ((taxon['ancestor_ids'] as List<dynamic>?) ?? [])
        .whereType<int>()
        .toList();

    final photos = (json['photos'] as List<dynamic>?) ?? [];
    final photoUrls = photos
        .where((p) => p['url'] != null)
        .map((p) {
          final url = p['url'] as String;
          return url.replaceFirst('/square.', '/medium.');
        })
        .toList();

    return Observation(
      id: json['id'] as int,
      taxonId: taxon['id'] as int,
      scientificName: taxon['name'] as String,
      commonName: taxon['preferred_common_name'] as String?,
      familyId: familyId,
      familyName: familyName,
      orderId: orderId,
      orderName: orderName,
      iconicTaxonName: taxon['iconic_taxon_name'] as String?,
      photoUrls: photoUrls,
      ancestorIds: ancestorIds,
    );
  }

  String get displayName => commonName ?? scientificName;
}
