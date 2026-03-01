import 'dart:math';

import '../models/observation.dart';
import '../models/quiz_question.dart';
import 'inaturalist_api.dart';

class QuizEngine {
  static final _random = Random();

  static List<int> getUniqueFamilyIds(List<Observation> observations) {
    return observations
        .where((o) => o.familyId != null)
        .map((o) => o.familyId!)
        .toSet()
        .toList();
  }

  static List<QuizQuestion> generateQuestions({
    required List<Observation> observations,
    required Map<int, List<TaxonSummary>> familySpeciesMap,
    required int count,
    List<Observation>? allObservations,
    QuizType quizType = QuizType.photoToName,
  }) {
    final shuffled = List<Observation>.from(observations)..shuffle(_random);
    final effectiveCount = count == 0 ? shuffled.length : count;
    final selected = shuffled.take(effectiveCount).toList();

    // Build order-level species map by aggregating families within each order
    final orderSpeciesMap = <int, List<TaxonSummary>>{};
    final allObs = allObservations ?? observations;
    for (final obs in allObs) {
      if (obs.orderId != null &&
          obs.familyId != null &&
          familySpeciesMap.containsKey(obs.familyId)) {
        final orderList = orderSpeciesMap.putIfAbsent(obs.orderId!, () => []);
        for (final species in familySpeciesMap[obs.familyId]!) {
          if (!orderList.any((s) => s.id == species.id)) {
            orderList.add(species);
          }
        }
      }
    }

    final questions = <QuizQuestion>[];

    for (final obs in selected) {
      QuizQuestion? q;
      switch (quizType) {
        case QuizType.photoToName:
          q = _buildPhotoToNameQuestion(obs, familySpeciesMap, orderSpeciesMap, allObs);
        case QuizType.nameToPhoto:
          q = _buildNameToPhotoQuestion(obs, familySpeciesMap, orderSpeciesMap, allObs);
        case QuizType.familyId:
          q = _buildFamilyIdQuestion(obs, allObs);
      }
      if (q != null) questions.add(q);
    }

    return questions;
  }

  static QuizQuestion? _buildPhotoToNameQuestion(
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

    if (distractors.length < 3) return null;

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

    return QuizQuestion(
      taxonId: obs.taxonId,
      photoUrl: obs.photoUrls.first,
      allPhotoUrls: obs.photoUrls,
      correctCommonName: obs.commonName ?? obs.scientificName,
      correctScientificName: obs.scientificName,
      choices: choices,
      type: QuizType.photoToName,
    );
  }

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
      requirePhoto: true,
    );

    if (distractors.length < 3) return null;

    final correctChoice = AnswerChoice(
      commonName: obs.commonName ?? '',
      scientificName: obs.scientificName,
      isCorrect: true,
      photoUrl: obs.photoUrls.first,
    );

    final wrongChoices = distractors.map((t) => AnswerChoice(
      commonName: t.commonName ?? '',
      scientificName: t.scientificName,
      isCorrect: false,
      photoUrl: t.photoUrl,
    )).toList();

    final choices = [correctChoice, ...wrongChoices]..shuffle(_random);

    return QuizQuestion(
      taxonId: obs.taxonId,
      photoUrl: obs.photoUrls.first,
      allPhotoUrls: obs.photoUrls,
      correctCommonName: obs.commonName ?? obs.scientificName,
      correctScientificName: obs.scientificName,
      choices: choices,
      type: QuizType.nameToPhoto,
    );
  }

  static QuizQuestion? _buildFamilyIdQuestion(
    Observation obs,
    List<Observation> allObservations,
  ) {
    if (obs.familyId == null || obs.familyName == null) return null;

    // Collect distinct family names from all observations, excluding the correct family
    final familyNames = <int, String>{};
    for (final o in allObservations) {
      if (o.familyId != null &&
          o.familyName != null &&
          o.familyId != obs.familyId &&
          !familyNames.containsKey(o.familyId)) {
        familyNames[o.familyId!] = o.familyName!;
      }
    }

    // Prefer same iconicTaxonName for distractors
    final sameGroup = <MapEntry<int, String>>[];
    final otherGroup = <MapEntry<int, String>>[];
    for (final entry in familyNames.entries) {
      final matchingObs = allObservations.firstWhere(
        (o) => o.familyId == entry.key,
      );
      if (obs.iconicTaxonName != null &&
          matchingObs.iconicTaxonName == obs.iconicTaxonName) {
        sameGroup.add(entry);
      } else {
        otherGroup.add(entry);
      }
    }

    sameGroup.shuffle(_random);
    otherGroup.shuffle(_random);

    final distractorFamilies = <MapEntry<int, String>>[];
    for (final entry in sameGroup) {
      if (distractorFamilies.length >= 3) break;
      distractorFamilies.add(entry);
    }
    for (final entry in otherGroup) {
      if (distractorFamilies.length >= 3) break;
      distractorFamilies.add(entry);
    }

    if (distractorFamilies.length < 3) return null;

    final correctChoice = AnswerChoice(
      commonName: '',
      scientificName: obs.familyName!,
      isCorrect: true,
    );

    final wrongChoices = distractorFamilies.take(3).map((entry) => AnswerChoice(
      commonName: '',
      scientificName: entry.value,
      isCorrect: false,
    )).toList();

    final choices = [correctChoice, ...wrongChoices]..shuffle(_random);

    return QuizQuestion(
      taxonId: obs.taxonId,
      photoUrl: obs.photoUrls.first,
      allPhotoUrls: obs.photoUrls,
      correctCommonName: obs.commonName ?? obs.scientificName,
      correctScientificName: obs.scientificName,
      choices: choices,
      type: QuizType.familyId,
    );
  }

  static List<TaxonSummary> _pickDistractors({
    required Observation obs,
    required Map<int, List<TaxonSummary>> familySpeciesMap,
    required Map<int, List<TaxonSummary>> orderSpeciesMap,
    required List<Observation> allObservations,
    bool requirePhoto = false,
  }) {
    final distractors = <TaxonSummary>[];

    bool isValid(TaxonSummary t) =>
        t.id != obs.taxonId &&
        !distractors.any((d) => d.id == t.id) &&
        (!requirePhoto || t.photoUrl != null);

    // Try same family
    if (obs.familyId != null && familySpeciesMap.containsKey(obs.familyId)) {
      final siblings = familySpeciesMap[obs.familyId]!
          .where((t) => isValid(t))
          .toList()
        ..shuffle(_random);
      distractors.addAll(siblings.take(3));
    }

    // If not enough, try order-level species
    if (distractors.length < 3 && obs.orderId != null && orderSpeciesMap.containsKey(obs.orderId)) {
      final orderSiblings = orderSpeciesMap[obs.orderId]!
          .where((t) => isValid(t))
          .toList()
        ..shuffle(_random);
      distractors.addAll(orderSiblings.take(3 - distractors.length));
    }

    // Last resort: use other species from the user's observations,
    // preferring same iconic taxon (e.g. Insecta, Plantae, Aves)
    if (distractors.length < 3) {
      final candidates = allObservations
          .where((o) => o.taxonId != obs.taxonId && !distractors.any((d) => d.id == o.taxonId))
          .toList()
        ..shuffle(_random);

      bool canAdd(Observation o) =>
          !distractors.any((d) => d.id == o.taxonId);

      // Try same iconic taxon first
      if (obs.iconicTaxonName != null) {
        final sameGroup = candidates
            .where((o) => o.iconicTaxonName == obs.iconicTaxonName);
        for (final o in sameGroup) {
          if (distractors.length >= 3) break;
          if (!canAdd(o)) continue;
          final photoUrl = o.photoUrls.isNotEmpty ? o.photoUrls.first : null;
          if (requirePhoto && photoUrl == null) continue;
          distractors.add(TaxonSummary(
            id: o.taxonId,
            scientificName: o.scientificName,
            commonName: o.commonName,
            photoUrl: photoUrl,
          ));
        }
      }

      // Fill remaining from any observation
      for (final o in candidates) {
        if (distractors.length >= 3) break;
        if (!canAdd(o)) continue;
        final photoUrl = o.photoUrls.isNotEmpty ? o.photoUrls.first : null;
        if (requirePhoto && photoUrl == null) continue;
        distractors.add(TaxonSummary(
          id: o.taxonId,
          scientificName: o.scientificName,
          commonName: o.commonName,
          photoUrl: photoUrl,
        ));
      }
    }

    return distractors.take(3).toList();
  }
}
