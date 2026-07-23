import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/shared/utils/time_ago.dart';

void main() {
  group('formatTimeAgo', () {
    test('reports "just now" for under a minute', () {
      final dateTime = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
      expect(formatTimeAgo(dateTime), 'just now');
    });

    test('reports minutes for under an hour', () {
      final dateTime = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      expect(formatTimeAgo(dateTime), '5m ago');
    });

    test('reports hours for under a day', () {
      final dateTime = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      expect(formatTimeAgo(dateTime), '3h ago');
    });

    test('reports days beyond 24 hours', () {
      final dateTime = DateTime.now().toUtc().subtract(const Duration(days: 2));
      expect(formatTimeAgo(dateTime), '2d ago');
    });

    test('handles non-UTC input by normalizing internally', () {
      final dateTime = DateTime.now().subtract(const Duration(minutes: 10));
      expect(formatTimeAgo(dateTime), '10m ago');
    });
  });
}
