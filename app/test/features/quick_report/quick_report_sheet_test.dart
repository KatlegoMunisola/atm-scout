import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:atm_scout/features/quick_report/presentation/quick_report_sheet.dart';
import 'package:atm_scout/features/map/application/map_providers.dart';
import 'package:atm_scout/shared/models/atm.dart';
import 'package:atm_scout/shared/models/denomination.dart';

import '../../mocks/mock_repositories.dart';

// QuickReportSheet resolves its position via GeofenceService.getCurrentPosition(),
// which calls the Geolocator plugin's platform channel directly with no
// injection seam. In `flutter test` there's no platform implementation
// registered, and how/when that unregistered call actually settles isn't
// something worth depending on here (observed to not reliably reject within
// pumpAndSettle's timeout). So these tests only assert the deterministic,
// synchronous "still resolving" state rendered on the first frame — the
// happy path (position resolves, submit becomes enabled, submitReport gets
// called) is not covered by this test file.
void main() {
  setUpAll(registerRepositoryFallbackValues);

  const atm = Atm(
    id: 'atm-1',
    bankName: 'First National Bank',
    atmType: AtmType.standalone,
    currencyCode: 'BWP',
    lat: -24.6282,
    lng: 25.9231,
    lastStatus: AtmStatus.unknown,
  );

  late MockAtmRepository repository;

  setUp(() {
    repository = MockAtmRepository();
    when(() => repository.fetchDenominations(any())).thenAnswer((_) async => const [
          Denomination(
              id: 'd10', currencyCode: 'BWP', value: 10, label: 'P10', sortOrder: 1),
          Denomination(
              id: 'd20', currencyCode: 'BWP', value: 20, label: 'P20', sortOrder: 2),
        ]);
  });

  Future<void> pumpSheet(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [atmRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: QuickReportSheet(atm: atm)),
        ),
      ),
    );
  }

  testWidgets('shows a checking-location state and keeps Submit disabled initially',
      (tester) async {
    await pumpSheet(tester);
    await tester.pump();

    expect(find.text('Checking your location...'), findsOneWidget);

    final submitButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'));
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('selecting Functional reveals the denomination checklist',
      (tester) async {
    await pumpSheet(tester);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Functional'));
    await tester.pump();
    await tester.pump(); // let denominationsProvider resolve

    expect(find.text('Which notes came out?'), findsOneWidget);
    expect(find.text('P10'), findsOneWidget);
    expect(find.text('P20'), findsOneWidget);
  });

  testWidgets('selecting "No longer here" shows a corroboration notice and no denominations',
      (tester) async {
    await pumpSheet(tester);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('No longer here'));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining("We'll double-check with other reports"),
      findsOneWidget,
    );
    expect(find.text('Which notes came out?'), findsNothing);
  });

  testWidgets('never calls submitReport while Submit stays disabled', (tester) async {
    await pumpSheet(tester);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Functional'));
    await tester.pump();
    await tester.pump();

    // Submit is disabled (no resolved position), so tapping it is a no-op —
    // there's nothing to tap through since a disabled FilledButton ignores
    // taps. This just confirms the repository was never called as a result
    // of rendering/selecting a status alone.
    verifyNever(() => repository.submitReport(
          atmId: any(named: 'atmId'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          accuracyMeters: any(named: 'accuracyMeters'),
          status: any(named: 'status'),
          denominations: any(named: 'denominations'),
        ));
  });
}
