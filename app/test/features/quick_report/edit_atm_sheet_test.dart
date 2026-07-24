import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:atm_scout/features/quick_report/presentation/edit_atm_sheet.dart';
import 'package:atm_scout/features/map/application/map_providers.dart';
import 'package:atm_scout/shared/models/atm.dart';

import '../../mocks/mock_repositories.dart';

// Same constraint as quick_report_sheet_test.dart: GeofenceService.getCurrentPosition()
// has no injection seam, so only the deterministic "still resolving location"
// state is covered here.
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
    lastStatus: AtmStatus.unknown,
    depositSupport: DepositSupport.yes,
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
          home: Scaffold(body: EditAtmSheet(atm: atm)),
        ),
      ),
    );
  }

  testWidgets('pre-fills fields from the current ATM and keeps Submit disabled '
      'while location is resolving', (tester) async {
    await pumpSheet(tester);
    await tester.pump();

    expect(find.text('Checking your location...'), findsOneWidget);

    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields[0].controller?.text, 'First National Bank');
    expect(textFields[1].controller?.text, 'Main Mall');

    final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit correction'));
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('never calls submitCorrection while Submit stays disabled',
      (tester) async {
    await pumpSheet(tester);
    await tester.pump();

    verifyNever(() => repository.submitCorrection(
          atmId: any(named: 'atmId'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          accuracyMeters: any(named: 'accuracyMeters'),
          reposition: any(named: 'reposition'),
          bankName: any(named: 'bankName'),
          branchLabel: any(named: 'branchLabel'),
          atmType: any(named: 'atmType'),
          depositSupport: any(named: 'depositSupport'),
        ));
  });

  testWidgets('toggling reposition swaps the location hint', (tester) async {
    await pumpSheet(tester);
    await tester.pump();

    expect(find.text('This pin is in the wrong place'), findsOneWidget);

    await tester.tap(find.text('This pin is in the wrong place'));
    await tester.pump();

    // Still resolving location, so the reposition-specific hint doesn't show
    // yet either - but the toggle itself should now be on.
    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isTrue);
  });
}
