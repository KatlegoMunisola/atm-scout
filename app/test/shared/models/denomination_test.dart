import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/shared/models/denomination.dart';

void main() {
  group('Denomination.fromJson', () {
    test('parses a row, coercing numeric value to double', () {
      final denomination = Denomination.fromJson(const {
        'id': 'denom-1',
        'currency_code': 'BWP',
        'value': 50,
        'label': 'P50',
        'sort_order': 3,
      });

      expect(denomination.id, 'denom-1');
      expect(denomination.currencyCode, 'BWP');
      expect(denomination.value, 50.0);
      expect(denomination.label, 'P50');
      expect(denomination.sortOrder, 3);
    });
  });
}
