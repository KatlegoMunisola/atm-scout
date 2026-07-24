import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/location/geofence_service.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/atm.dart';
import '../data/atm_repository.dart';

final atmRepositoryProvider = Provider<AtmRepository>((ref) {
  return AtmRepository(supabase);
});

/// Resolved once per app session, as soon as something first watches it -
/// requests location permission/GPS lock the same way the report flows do.
final userLocationProvider = FutureProvider<Position>((ref) {
  return GeofenceService.getCurrentPosition();
});

class NearbyAtm {
  const NearbyAtm({required this.atm, required this.distanceMeters});

  final Atm atm;
  final double distanceMeters;
}

/// All known ATMs paired with their distance from the user, nearest first.
/// Empty (rather than an error state) whenever location isn't available yet
/// - this is a passive convenience list, not worth surfacing an error for.
final nearestAtmsProvider = Provider<List<NearbyAtm>>((ref) {
  final atms = ref.watch(atmListProvider).valueOrNull ?? const [];
  final position = ref.watch(userLocationProvider).valueOrNull;
  if (position == null || atms.isEmpty) return const [];

  final withDistance = atms
      .map((atm) => NearbyAtm(
            atm: atm,
            distanceMeters: GeofenceService.distanceMeters(
              fromLat: position.latitude,
              fromLng: position.longitude,
              toLat: atm.lat,
              toLng: atm.lng,
            ),
          ))
      .toList()
    ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return withDistance;
});

class AtmListNotifier extends StateNotifier<AsyncValue<List<Atm>>> {
  AtmListNotifier(this._repository) : super(const AsyncValue.loading()) {
    _load();
    _subscription = _repository.subscribeToReports(_load);
  }

  final AtmRepository _repository;
  late final RealtimeChannel _subscription;

  Future<void> _load() async {
    try {
      final atms = await _repository.fetchAtms();
      state = AsyncValue.data(atms);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _subscription.unsubscribe();
    super.dispose();
  }
}

final atmListProvider =
    StateNotifierProvider<AtmListNotifier, AsyncValue<List<Atm>>>((ref) {
  return AtmListNotifier(ref.watch(atmRepositoryProvider));
});
