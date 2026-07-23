import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  /// Max distance (meters) a user may be from an ATM to submit a report.
  /// Must match the 50m check enforced server-side in submit_atm_report().
  static const double geofenceRadiusMeters = 50.0;

  static const String defaultCurrencyCode = 'BWP';
}
