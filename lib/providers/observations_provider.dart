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

  ObservationsState copyWith({
    LoadingStatus? status,
    List<Observation>? observations,
    String? errorMessage,
    int? loadedCount,
    int? currentUserIndex,
    int? totalUsers,
  }) {
    return ObservationsState(
      status: status ?? this.status,
      observations: observations ?? this.observations,
      errorMessage: errorMessage,
      loadedCount: loadedCount ?? this.loadedCount,
      currentUserIndex: currentUserIndex ?? this.currentUserIndex,
      totalUsers: totalUsers ?? this.totalUsers,
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
        locale: settings.locale,
      );

      if (observations.isEmpty) {
        state = state.copyWith(
          status: LoadingStatus.error,
          errorMessage: 'No photo observations found for "$username".',
        );
        return;
      }

      final uniqueSpecies = observations.map((o) => o.taxonId).toSet();
      if (uniqueSpecies.length < 2) {
        state = state.copyWith(
          status: LoadingStatus.error,
          errorMessage:
              'Need observations of at least 2 species to generate a quiz.',
        );
        return;
      }

      // Resolve ancestry (family/order) from ancestor IDs
      final resolved = await api.resolveAncestry(observations);

      state = state.copyWith(
        status: LoadingStatus.success,
        observations: resolved,
        loadedCount: resolved.length,
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

  Future<void> fetchForUsers(List<String> usernames) async {
    state = state.copyWith(
      status: LoadingStatus.loading,
      loadedCount: 0,
      currentUserIndex: 0,
      totalUsers: usernames.length,
    );

    try {
      final api = ref.read(inaturalistApiProvider);
      final settings = ref.read(settingsProvider);
      final allObservations = <Observation>[];

      for (var i = 0; i < usernames.length; i++) {
        state = state.copyWith(currentUserIndex: i);

        final observations = await api.fetchObservations(
          username: usernames[i],
          qualityGrade: settings.qualityGradeParam,
          locale: settings.locale,
        );

        allObservations.addAll(observations);
      }

      if (allObservations.isEmpty) {
        state = state.copyWith(
          status: LoadingStatus.error,
          errorMessage:
              'No photo observations found for the selected users.',
        );
        return;
      }

      final uniqueSpecies =
          allObservations.map((o) => o.taxonId).toSet();
      if (uniqueSpecies.length < 2) {
        state = state.copyWith(
          status: LoadingStatus.error,
          errorMessage:
              'Need observations of at least 2 species to generate a quiz.',
        );
        return;
      }

      // Resolve ancestry (family/order) from ancestor IDs
      final resolved = await api.resolveAncestry(allObservations);

      state = state.copyWith(
        status: LoadingStatus.success,
        observations: resolved,
        loadedCount: resolved.length,
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
}

final observationsProvider =
    NotifierProvider<ObservationsNotifier, ObservationsState>(
  ObservationsNotifier.new,
);
