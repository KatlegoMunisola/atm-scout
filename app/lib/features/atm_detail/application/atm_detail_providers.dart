import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/atm_report.dart';
import '../../../shared/models/denomination.dart';
import '../../map/application/map_providers.dart';

final latestReportProvider =
    FutureProvider.family<AtmReport?, String>((ref, atmId) {
  return ref.watch(atmRepositoryProvider).fetchLatestReport(atmId);
});

final denominationsProvider =
    FutureProvider.family<List<Denomination>, String>((ref, currencyCode) {
  return ref.watch(atmRepositoryProvider).fetchDenominations(currencyCode);
});
