import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:atm_scout/features/auth/application/auth_providers.dart';
import 'package:atm_scout/features/auth/data/auth_repository.dart';

import '../../mocks/mock_repositories.dart';

void main() {
  setUpAll(registerRepositoryFallbackValues);

  group('AuthRepository', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late AuthRepository repository;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);
      repository = AuthRepository(client);
    });

    test('sendOtp forwards to signInWithOtp with the given email', () async {
      when(() => auth.signInWithOtp(email: any(named: 'email')))
          .thenAnswer((_) async {});

      await repository.sendOtp('scout@example.com');

      verify(() => auth.signInWithOtp(email: 'scout@example.com')).called(1);
    });

    test('verifyOtp forwards to verifyOTP with type email', () async {
      when(() => auth.verifyOTP(
            email: any(named: 'email'),
            token: any(named: 'token'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => AuthResponse());

      await repository.verifyOtp(email: 'scout@example.com', token: '123456');

      verify(() => auth.verifyOTP(
            email: 'scout@example.com',
            token: '123456',
            type: OtpType.email,
          )).called(1);
    });

    test('signOut forwards to GoTrueClient.signOut', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => auth.signOut()).called(1);
    });

    test('currentUser reads through to GoTrueClient.currentUser', () {
      when(() => auth.currentUser).thenReturn(null);
      expect(repository.currentUser, isNull);
    });

    test('onAuthStateChange relays the underlying stream', () async {
      final controller = StreamController<AuthState>();
      when(() => auth.onAuthStateChange).thenAnswer((_) => controller.stream);

      final events = <AuthState>[];
      final sub = repository.onAuthStateChange.listen(events.add);

      final state = AuthState(AuthChangeEvent.signedIn, null);
      controller.add(state);
      await Future<void>.delayed(Duration.zero);

      expect(events, [state]);

      await sub.cancel();
      await controller.close();
    });
  });

  group('authStateProvider', () {
    test('relays events from the repository onAuthStateChange stream', () async {
      final mockAuthRepository = MockAuthRepository();
      final controller = StreamController<AuthState>();
      when(() => mockAuthRepository.onAuthStateChange)
          .thenAnswer((_) => controller.stream);

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(authStateProvider, (_, _) {});
      addTearDown(sub.close);

      final state = AuthState(AuthChangeEvent.signedIn, null);
      controller.add(state);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authStateProvider).value, state);

      await controller.close();
    });
  });
}
