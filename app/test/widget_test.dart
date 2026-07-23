// Unit tests for the pure logic pieces that don't require booting the full
// app (which needs live Supabase/Mapbox credentials at startup).

import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/core/location/geofence_service.dart';
import 'package:atm_scout/shared/models/atm.dart';

void main() {
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

  group('GeofenceService.isWithinGeofence', () {
    test('is true at the exact same coordinates', () {
      final within = GeofenceService.isWithinGeofence(
        userLat: -24.6282,
        userLng: 25.9231,
        atmLat: -24.6282,
        atmLng: 25.9231,
      );
      expect(within, isTrue);
    });

    test('is false when far away from the ATM', () {
      final within = GeofenceService.isWithinGeofence(
        userLat: -24.6282,
        userLng: 25.9231,
        atmLat: -25.9692, // Gaborone vs Francistown, ~300km away
        atmLng: 27.5142,
      );
      expect(within, isFalse);
    });
  });
}
