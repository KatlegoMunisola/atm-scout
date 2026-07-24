import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/shared/models/atm.dart';

void main() {
  group('AtmType mapping', () {
    test('round-trips known type literals', () {
      expect(atmTypeFromString('in_branch'), AtmType.inBranch);
      expect(atmTypeFromString('standalone'), AtmType.standalone);
      // Anything unrecognized falls back to standalone rather than throwing.
      expect(atmTypeFromString('garbage'), AtmType.standalone);
    });

    test('converts back to db literals', () {
      expect(atmTypeToString(AtmType.inBranch), 'in_branch');
      expect(atmTypeToString(AtmType.standalone), 'standalone');
    });
  });

  group('AtmStatus mapping', () {
    test('round-trips known status literals', () {
      expect(atmStatusFromString('functional'), AtmStatus.functional);
      expect(atmStatusFromString('out_of_order'), AtmStatus.outOfOrder);
      expect(atmStatusFromString('no_cash'), AtmStatus.noCash);
      expect(atmStatusFromString(null), AtmStatus.unknown);
      expect(atmStatusFromString('garbage'), AtmStatus.unknown);
    });

    test('converts submittable statuses back to db literals', () {
      expect(atmStatusToDbString(AtmStatus.functional), 'functional');
      expect(atmStatusToDbString(AtmStatus.outOfOrder), 'out_of_order');
      expect(atmStatusToDbString(AtmStatus.noCash), 'no_cash');
    });

    test('refuses to submit AtmStatus.unknown', () {
      expect(() => atmStatusToDbString(AtmStatus.unknown), throwsArgumentError);
    });
  });

  group('AtmConfidence mapping', () {
    test('round-trips known confidence literals', () {
      expect(atmConfidenceFromString('high'), AtmConfidence.high);
      expect(atmConfidenceFromString('medium'), AtmConfidence.medium);
      expect(atmConfidenceFromString('low'), AtmConfidence.low);
    });

    test('defaults to low for null or unrecognized values', () {
      expect(atmConfidenceFromString(null), AtmConfidence.low);
      expect(atmConfidenceFromString('garbage'), AtmConfidence.low);
    });
  });

  group('DepositSupport mapping', () {
    test('round-trips known deposit-support literals', () {
      expect(depositSupportFromString('yes'), DepositSupport.yes);
      expect(depositSupportFromString('no'), DepositSupport.no);
      expect(depositSupportFromString('unknown'), DepositSupport.unknown);
    });

    test('defaults to unknown for null or unrecognized values', () {
      expect(depositSupportFromString(null), DepositSupport.unknown);
      expect(depositSupportFromString('garbage'), DepositSupport.unknown);
    });

    test('converts back to db literals', () {
      expect(depositSupportToString(DepositSupport.yes), 'yes');
      expect(depositSupportToString(DepositSupport.no), 'no');
      expect(depositSupportToString(DepositSupport.unknown), 'unknown');
    });
  });

  group('Atm.fromJson', () {
    test('parses a fully populated row', () {
      final atm = Atm.fromJson(const {
        'id': 'atm-1',
        'bank_name': 'First National Bank',
        'branch_label': 'Main Mall',
        'atm_type': 'in_branch',
        'currency_code': 'BWP',
        'lat': -24.6282,
        'lng': 25.9231,
        'address': 'Main Mall, Gaborone',
        'last_status': 'functional',
        'last_report_at': '2026-07-22T10:00:00Z',
        'confidence': 'high',
        'deposit_support': 'yes',
      });

      expect(atm.id, 'atm-1');
      expect(atm.bankName, 'First National Bank');
      expect(atm.branchLabel, 'Main Mall');
      expect(atm.atmType, AtmType.inBranch);
      expect(atm.currencyCode, 'BWP');
      expect(atm.lat, -24.6282);
      expect(atm.lng, 25.9231);
      expect(atm.address, 'Main Mall, Gaborone');
      expect(atm.lastStatus, AtmStatus.functional);
      expect(atm.lastReportAt, DateTime.parse('2026-07-22T10:00:00Z'));
      expect(atm.confidence, AtmConfidence.high);
      expect(atm.depositSupport, DepositSupport.yes);
    });

    test('parses a row with nullable fields absent', () {
      final atm = Atm.fromJson(const {
        'id': 'atm-2',
        'bank_name': 'Standard Chartered',
        'branch_label': null,
        'atm_type': 'standalone',
        'currency_code': 'BWP',
        'lat': -24.0,
        'lng': 25.0,
        'address': null,
        'last_status': null,
        'last_report_at': null,
        'confidence': null,
      });

      expect(atm.branchLabel, isNull);
      expect(atm.address, isNull);
      expect(atm.lastStatus, AtmStatus.unknown);
      expect(atm.lastReportAt, isNull);
      expect(atm.confidence, AtmConfidence.low);
      expect(atm.depositSupport, DepositSupport.unknown);
    });

    test('accepts integer lat/lng (num, not just double)', () {
      final atm = Atm.fromJson(const {
        'id': 'atm-3',
        'bank_name': 'Bank Gaborone',
        'branch_label': null,
        'atm_type': 'standalone',
        'currency_code': 'BWP',
        'lat': -24,
        'lng': 25,
        'address': null,
        'last_status': null,
        'last_report_at': null,
      });

      expect(atm.lat, -24.0);
      expect(atm.lng, 25.0);
    });
  });
}
