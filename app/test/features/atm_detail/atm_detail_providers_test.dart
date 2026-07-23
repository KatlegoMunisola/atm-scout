import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:atm_scout/features/atm_detail/application/atm_detail_providers.dart';
import 'package:atm_scout/features/map/application/map_providers.dart';
import 'package:atm_scout/shared/models/atm.dart';
import 'package:atm_scout/shared/models/atm_report.dart';
import 'package:atm_scout/shared/models/denomination.dart';

import '../../mocks/mock_repositories.dart';

void main() {
  setUpAll(registerRepositoryFallbackValues);

  late MockAtmRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockAtmRepository();
    container = ProviderContainer(overrides: [
      atmRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
  });

  test('latestReportProvider resolves through to fetchLatestReport', () async {
    final report = AtmReport(
      id: 'report-1',
      atmId: 'atm-1',
      status: AtmStatus.functional,
      createdAt: DateTime.now().toUtc(),
    );
    when(() => repository.fetchLatestReport('atm-1'))
        .thenAnswer((_) async => report);

    final result = await container.read(latestReportProvider('atm-1').future);

    expect(result, report);
    verify(() => repository.fetchLatestReport('atm-1')).called(1);
  });

  test('latestReportProvider resolves to null when there is no report yet', () async {
    when(() => repository.fetchLatestReport('atm-2'))
        .thenAnswer((_) async => null);

    final result = await container.read(latestReportProvider('atm-2').future);

    expect(result, isNull);
  });

  test('denominationsProvider resolves through to fetchDenominations', () async {
    const denominations = [
      Denomination(
        id: 'd1',
        currencyCode: 'BWP',
        value: 10,
        label: 'P10',
        sortOrder: 1,
      ),
    ];
    when(() => repository.fetchDenominations('BWP'))
        .thenAnswer((_) async => denominations);

    final result = await container.read(denominationsProvider('BWP').future);

    expect(result, denominations);
    verify(() => repository.fetchDenominations('BWP')).called(1);
  });
}
