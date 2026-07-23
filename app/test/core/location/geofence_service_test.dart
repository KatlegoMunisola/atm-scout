import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:atm_scout/core/config/app_constants.dart';
import 'package:atm_scout/core/location/geofence_service.dart';

/// Returns a latitude offset (degrees, due north) that puts a point
/// approximately [meters] away from [fromLat], using a spherical-earth
/// approximation. Accurate to well under a meter at these distances, which
/// is precise enough to bracket the 50m geofence boundary without relying on
/// fragile floating-point-exact equality.
double _latDegreesForMeters(double meters) {
  const earthRadiusMeters = 6371000.0;
  final radians = meters / earthRadiusMeters;
  return radians * (180 / math.pi);
}

void main() {
  const gaboroneLat = -24.6282;
  const gaboroneLng = 25.9231;

  group('GeofenceService.isWithinGeofence', () {
    test('is true at the exact same coordinates', () {
      final within = GeofenceService.isWithinGeofence(
        userLat: gaboroneLat,
        userLng: gaboroneLng,
        atmLat: gaboroneLat,
        atmLng: gaboroneLng,
      );
      expect(within, isTrue);
    });

    test('is false when far away from the ATM', () {
      final within = GeofenceService.isWithinGeofence(
        userLat: gaboroneLat,
        userLng: gaboroneLng,
        atmLat: -25.9692, // Gaborone vs Francistown, ~300km away
        atmLng: 27.5142,
      );
      expect(within, isFalse);
    });

    test('respects the exact AppConstants.geofenceRadiusMeters boundary', () {
      expect(AppConstants.geofenceRadiusMeters, 50.0);

      final justInsideLat = gaboroneLat + _latDegreesForMeters(49);
      final justOutsideLat = gaboroneLat + _latDegreesForMeters(51);

      final distanceInside = GeofenceService.distanceMeters(
        fromLat: gaboroneLat,
        fromLng: gaboroneLng,
        toLat: justInsideLat,
        toLng: gaboroneLng,
      );
      final distanceOutside = GeofenceService.distanceMeters(
        fromLat: gaboroneLat,
        fromLng: gaboroneLng,
        toLat: justOutsideLat,
        toLng: gaboroneLng,
      );

      // Sanity-check the constructed offsets actually bracket 50m before
      // trusting the isWithinGeofence assertions below.
      expect(distanceInside, lessThan(50.0));
      expect(distanceOutside, greaterThan(50.0));

      expect(
        GeofenceService.isWithinGeofence(
          userLat: gaboroneLat,
          userLng: gaboroneLng,
          atmLat: justInsideLat,
          atmLng: gaboroneLng,
        ),
        isTrue,
      );
      expect(
        GeofenceService.isWithinGeofence(
          userLat: gaboroneLat,
          userLng: gaboroneLng,
          atmLat: justOutsideLat,
          atmLng: gaboroneLng,
        ),
        isFalse,
      );
    });
  });
}
