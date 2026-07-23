import 'package:geolocator/geolocator.dart';

import '../config/app_constants.dart';

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();
  @override
  String toString() => 'Location services are disabled on this device.';
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
  @override
  String toString() => 'Location permission was denied.';
}

class GeofenceService {
  GeofenceService._();

  static Future<Position> getCurrentPosition() async {
    final permission = await _ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException();
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<LocationPermission> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static double distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }

  static bool isWithinGeofence({
    required double userLat,
    required double userLng,
    required double atmLat,
    required double atmLng,
  }) {
    final distance = distanceMeters(
      fromLat: userLat,
      fromLng: userLng,
      toLat: atmLat,
      toLng: atmLng,
    );
    return distance <= AppConstants.geofenceRadiusMeters;
  }
}
