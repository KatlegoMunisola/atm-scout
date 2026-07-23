import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/atm.dart';
import '../data/atm_repository.dart';

final atmRepositoryProvider = Provider<AtmRepository>((ref) {
  return AtmRepository(supabase);
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
