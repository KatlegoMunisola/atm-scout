import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:atm_scout/features/auth/data/auth_repository.dart';
import 'package:atm_scout/features/map/data/atm_repository.dart';

class MockAtmRepository extends Mock implements AtmRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

/// Registers fallback values mocktail needs for any non-primitive argument
/// matched with `any()`/`captureAny()` in stubs or verifications. Call once
/// from a `setUpAll` in any test file that stubs these argument shapes.
void registerRepositoryFallbackValues() {
  registerFallbackValue(<Map<String, dynamic>>[]);
  registerFallbackValue(OtpType.email);
}
