import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:atm_scout/features/atm_detail/presentation/atm_detail_sheet.dart';
import 'package:atm_scout/features/map/application/map_providers.dart';
import 'package:atm_scout/shared/models/atm.dart';
import 'package:atm_scout/shared/models/atm_report.dart';
import 'package:atm_scout/shared/models/denomination.dart';

import '../../mocks/mock_repositories.dart';

void main() {
  setUpAll(registerRepositoryFallbackValues);

  const atm = Atm(
    id: 'atm-1',
    bankName: 'First National Bank',
    branchLabel: 'Main Mall',
    atmType: AtmType.inBranch,
    currencyCode: 'BWP',
    lat: -24.6282,
    lng: 25.9231,
    address: 'Main Mall, Gaborone',
    lastStatus: AtmStatus.functional,
  );

  late MockAtmRepository repository;

  setUp(() {
    repository = MockAtmRepository();
  });

  Future<void> pumpSheet(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [atmRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: AtmDetailSheet(atm: atm)),
        ),
      ),
    );
  }

  testWidgets('shows bank name, branch, address, and status badge', (tester) async {
    when(() => repository.fetchLatestReport(any())).thenAnswer((_) async => null);
    when(() => repository.fetchDenominations(any())).thenAnswer((_) async => const []);

    await pumpSheet(tester);
    await tester.pump();

    expect(find.text('First National Bank'), findsOneWidget);
    expect(find.text('Main Mall'), findsOneWidget);
    expect(find.text('Main Mall, Gaborone'), findsOneWidget);
    expect(find.text('Functional'), findsOneWidget); // StatusBadge label
  });

  testWidgets('shows "no reports yet" when the ATM has no last report', (tester) async {
    when(() => repository.fetchLatestReport(any())).thenAnswer((_) async => null);
    when(() => repository.fetchDenominations(any())).thenAnswer((_) async => const []);

    await pumpSheet(tester);
    await tester.pump();

    expect(find.text('No reports yet — be the first!'), findsOneWidget);
  });

  testWidgets('renders denomination chips from the latest report', (tester) async {
    final report = AtmReport(
      id: 'report-1',
      atmId: 'atm-1',
      status: AtmStatus.functional,
      createdAt: DateTime.now().toUtc(),
      denominationDispensed: const {'denom-50': true, 'denom-100': false},
    );
    const denominations = [
      Denomination(
          id: 'denom-50',
          currencyCode: 'BWP',
          value: 50,
          label: 'P50',
          sortOrder: 3),
      Denomination(
          id: 'denom-100',
          currencyCode: 'BWP',
          value: 100,
          label: 'P100',
          sortOrder: 4),
    ];
    when(() => repository.fetchLatestReport(any())).thenAnswer((_) async => report);
    when(() => repository.fetchDenominations(any()))
        .thenAnswer((_) async => denominations);

    await pumpSheet(tester);
    await tester.pump();
    await tester.pump(); // let the nested denominationsProvider resolve too

    expect(find.text('P50'), findsOneWidget);
    expect(find.text('P100'), findsOneWidget);
  });

  testWidgets('shows an error message when the latest report fails to load',
      (tester) async {
    when(() => repository.fetchLatestReport(any()))
        .thenThrow(Exception('network down'));
    when(() => repository.fetchDenominations(any())).thenAnswer((_) async => const []);

    await pumpSheet(tester);
    await tester.pump();

    expect(find.textContaining('Could not load report'), findsOneWidget);
  });
}
