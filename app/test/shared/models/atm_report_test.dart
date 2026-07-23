import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/shared/models/atm.dart';
import 'package:atm_scout/shared/models/atm_report.dart';

void main() {
  group('AtmReport.fromJson', () {
    test('parses denomination notes into a lookup map', () {
      final report = AtmReport.fromJson(const {
        'id': 'report-1',
        'atm_id': 'atm-1',
        'status': 'functional',
        'created_at': '2026-07-22T10:00:00Z',
        'atm_report_notes': [
          {'denomination_id': 'denom-10', 'dispensed': true},
          {'denomination_id': 'denom-20', 'dispensed': false},
        ],
      });

      expect(report.id, 'report-1');
      expect(report.atmId, 'atm-1');
      expect(report.status, AtmStatus.functional);
      expect(report.createdAt, DateTime.parse('2026-07-22T10:00:00Z'));
      expect(report.denominationDispensed, {
        'denom-10': true,
        'denom-20': false,
      });
    });

    test('defaults to an empty map when notes are absent', () {
      final report = AtmReport.fromJson(const {
        'id': 'report-2',
        'atm_id': 'atm-2',
        'status': 'no_cash',
        'created_at': '2026-07-22T10:00:00Z',
      });

      expect(report.denominationDispensed, isEmpty);
    });

    test('defaults to an empty map when notes is an empty list', () {
      final report = AtmReport.fromJson(const {
        'id': 'report-3',
        'atm_id': 'atm-3',
        'status': 'out_of_order',
        'created_at': '2026-07-22T10:00:00Z',
        'atm_report_notes': <Map<String, dynamic>>[],
      });

      expect(report.denominationDispensed, isEmpty);
    });
  });
}
