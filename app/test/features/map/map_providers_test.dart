import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import 'package:atm_scout/features/map/application/map_providers.dart';
import 'package:atm_scout/shared/models/atm.dart';

import '../../mocks/mock_repositories.dart';

Position _testPosition({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 1, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  setUpAll(registerRepositoryFallbackValues);

  const atm = Atm(
    id: 'atm-1',
    bankName: 'FNB',
    atmType: AtmType.standalone,
    currencyCode: 'BWP',
    lat: -24.6282,
    lng: 25.9231,
    lastStatus: AtmStatus.functional,
  );

  late MockAtmRepository repository;
  late MockRealtimeChannel channel;

  setUp(() {
    repository = MockAtmRepository();
    channel = MockRealtimeChannel();
    when(() => repository.subscribeToReports(any())).thenReturn(channel);
    when(() => channel.unsubscribe()).thenAnswer((_) async => 'ok');
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      atmRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('starts in a loading state before the initial fetch resolves', () {
    when(() => repository.fetchAtms()).thenAnswer((_) async => [atm]);

    final container = buildContainer();

    expect(container.read(atmListProvider).isLoading, isTrue);
  });

  test('resolves to data on a successful fetch', () async {
    when(() => repository.fetchAtms()).thenAnswer((_) async => [atm]);

    final container = buildContainer();
    // Providers are lazy: reading triggers the notifier's constructor (and
    // its fire-and-forget _load() call) *now*, so the delay below actually
    // has something in flight to wait for.
    container.read(atmListProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(atmListProvider).value, [atm]);
  });

  test('resolves to an error state when fetchAtms throws', () async {
    when(() => repository.fetchAtms()).thenThrow(Exception('boom'));

    final container = buildContainer();
    container.read(atmListProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(atmListProvider).hasError, isTrue);
  });

  test('refresh() re-invokes fetchAtms()', () async {
    when(() => repository.fetchAtms()).thenAnswer((_) async => [atm]);

    final container = buildContainer();
    container.read(atmListProvider);
    await Future<void>.delayed(Duration.zero); // let the constructor's load finish

    await container.read(atmListProvider.notifier).refresh();

    verify(() => repository.fetchAtms()).called(2);
  });

  test('subscribes to report changes on creation and unsubscribes on dispose', () async {
    when(() => repository.fetchAtms()).thenAnswer((_) async => [atm]);

    // Built directly (not via buildContainer/addTearDown) since this test
    // disposes the container itself to assert on the resulting unsubscribe.
    final container = ProviderContainer(overrides: [
      atmRepositoryProvider.overrideWithValue(repository),
    ]);
    // Force creation of the notifier (providers are lazy until read).
    container.read(atmListProvider);
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.subscribeToReports(any())).called(1);

    container.dispose();
    verify(() => channel.unsubscribe()).called(1);
  });

  group('nearestAtmsProvider', () {
    const nearAtm = Atm(
      id: 'near',
      bankName: 'Near Bank',
      atmType: AtmType.standalone,
      currencyCode: 'BWP',
      lat: -24.6282,
      lng: 25.9231,
      lastStatus: AtmStatus.unknown,
    );
    const farAtm = Atm(
      id: 'far',
      bankName: 'Far Bank',
      atmType: AtmType.standalone,
      currencyCode: 'BWP',
      lat: -25.9692, // Lobatse - tens of km further from Gaborone
      lng: 25.6785,
      lastStatus: AtmStatus.unknown,
    );

    test('sorts ATMs by distance from the user, nearest first', () async {
      when(() => repository.fetchAtms())
          .thenAnswer((_) async => [farAtm, nearAtm]);

      final container = ProviderContainer(overrides: [
        atmRepositoryProvider.overrideWithValue(repository),
        userLocationProvider.overrideWith(
          (ref) async => _testPosition(latitude: -24.6282, longitude: 25.9231),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(atmListProvider);
      await Future<void>.delayed(Duration.zero);
      await container.read(userLocationProvider.future);

      final nearest = container.read(nearestAtmsProvider);
      expect(nearest.map((n) => n.atm.id).toList(), ['near', 'far']);
      expect(nearest[0].distanceMeters, lessThan(nearest[1].distanceMeters));
    });

    test('is empty while location has not resolved yet', () async {
      when(() => repository.fetchAtms()).thenAnswer((_) async => [nearAtm]);

      final container = ProviderContainer(overrides: [
        atmRepositoryProvider.overrideWithValue(repository),
        userLocationProvider.overrideWith(
          (ref) => Completer<Position>().future, // never resolves
        ),
      ]);
      addTearDown(container.dispose);

      container.read(atmListProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(nearestAtmsProvider), isEmpty);
    });
  });
}
