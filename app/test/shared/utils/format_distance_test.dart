import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/shared/utils/format_distance.dart';

void main() {
  test('formats sub-kilometre distances in whole metres', () {
    expect(formatDistance(0), '0 m');
    expect(formatDistance(42.4), '42 m');
    expect(formatDistance(999), '999 m');
  });

  test('formats kilometre-plus distances with one decimal place', () {
    expect(formatDistance(1000), '1.0 km');
    expect(formatDistance(1549), '1.5 km');
    expect(formatDistance(25000), '25.0 km');
  });
}
