import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/shared/models/atm.dart';
import 'package:atm_scout/shared/widgets/confidence_badge.dart';

void main() {
  Future<void> pumpBadge(WidgetTester tester, AtmConfidence confidence) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConfidenceBadge(confidence: confidence)),
      ),
    );
  }

  testWidgets('shows the High confidence label', (tester) async {
    await pumpBadge(tester, AtmConfidence.high);
    expect(find.text('High confidence'), findsOneWidget);
  });

  testWidgets('shows the Medium confidence label', (tester) async {
    await pumpBadge(tester, AtmConfidence.medium);
    expect(find.text('Medium confidence'), findsOneWidget);
  });

  testWidgets('shows the Low confidence label', (tester) async {
    await pumpBadge(tester, AtmConfidence.low);
    expect(find.text('Low confidence'), findsOneWidget);
  });
}
