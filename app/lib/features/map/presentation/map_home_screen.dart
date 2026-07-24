import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Aliased: geolocator's Position (a GPS reading) would otherwise collide
// with mapbox_maps_flutter's Position (a geographic coordinate), which this
// file also needs.
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/config/app_constants.dart';
import '../../../shared/models/atm.dart';
import '../../../shared/utils/format_distance.dart';
import '../../atm_detail/presentation/atm_detail_sheet.dart';
import '../../quick_report/presentation/add_atm_sheet.dart';
import '../application/map_providers.dart';

// Default camera center: Gaborone, Botswana.
const _defaultCenterLng = 25.9231;
const _defaultCenterLat = -24.6282;

const _atmSourceId = 'atm-source';
const _clusterLayerId = 'atm-clusters';
const _clusterCountLayerId = 'atm-cluster-count';
const _unclusteredCircleLayerId = 'atm-unclustered-circle';
const _unclusteredLabelLayerId = 'atm-unclustered-label';

const _emptyFeatureCollection = '{"type":"FeatureCollection","features":[]}';

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  MapboxMap? _mapboxMap;
  GeoJsonSource? _atmSource;
  Map<String, Atm> _atmById = {};
  bool _hasCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.addInteraction(TapInteraction.onMap(_onMapTapped));
  }

  // Sources/layers must be added after the style has finished loading -
  // adding them from onMapCreated (which fires before that) is a no-op.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final source = GeoJsonSource(
      id: _atmSourceId,
      data: _emptyFeatureCollection,
      cluster: true,
      clusterMaxZoom: 14,
      clusterRadius: 50,
    );
    await mapboxMap.style.addSource(source);
    _atmSource = source;

    await mapboxMap.style.addLayer(CircleLayer(
      id: _clusterLayerId,
      sourceId: _atmSourceId,
      filter: const [
        'has',
        'point_count',
      ],
      circleColorExpression: const [
        'step',
        ['get', 'point_count'],
        ['rgba', 33, 150, 149, 1],
        10,
        ['rgba', 33, 111, 149, 1],
        30,
        ['rgba', 25, 76, 110, 1],
      ],
      circleRadiusExpression: const [
        'step',
        ['get', 'point_count'],
        16.0,
        10,
        20.0,
        30,
        26.0,
      ],
      circleStrokeWidth: 2,
      circleStrokeColorExpression: const ['rgba', 255, 255, 255, 1],
    ));

    await mapboxMap.style.addLayer(SymbolLayer(
      id: _clusterCountLayerId,
      sourceId: _atmSourceId,
      filter: const [
        'has',
        'point_count',
      ],
      textFieldExpression: const ['get', 'point_count_abbreviated'],
      textSize: 12,
      textColorExpression: const ['rgba', 255, 255, 255, 1],
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ));

    const unclusteredFilter = [
      '!',
      ['has', 'point_count'],
    ];

    // A plain CircleLayer for individual ATMs rather than an icon: the
    // default style's sprite doesn't reliably include Maki icons like
    // "marker-15" (SymbolLayer would silently render no icon at all), while
    // a circle is guaranteed to draw and is easier to spot against the
    // basemap than a bare text label was.
    await mapboxMap.style.addLayer(CircleLayer(
      id: _unclusteredCircleLayerId,
      sourceId: _atmSourceId,
      filter: unclusteredFilter,
      circleRadius: 8,
      circleColorExpression: const ['rgba', 214, 69, 33, 1],
      circleStrokeWidth: 2,
      circleStrokeColorExpression: const ['rgba', 255, 255, 255, 1],
    ));

    await mapboxMap.style.addLayer(SymbolLayer(
      id: _unclusteredLabelLayerId,
      sourceId: _atmSourceId,
      filter: unclusteredFilter,
      textFieldExpression: const ['get', 'bankName'],
      textOffset: [0, 1.6],
      textSize: 11,
      textHaloColorExpression: const ['rgba', 255, 255, 255, 1],
      textHaloWidth: 1.5,
    ));

    final atms = ref.read(atmListProvider).valueOrNull;
    if (atms != null) {
      await _syncAnnotations(atms);
    }
  }

  Future<void> _onMapTapped(MapContentGestureContext context) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final features = await mapboxMap.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(context.touchPosition),
      RenderedQueryOptions(layerIds: [_clusterLayerId, _unclusteredCircleLayerId, _unclusteredLabelLayerId]),
    );
    if (features.isEmpty || features.first == null) return;

    final feature = features.first!.queriedFeature.feature;
    final properties = feature['properties'];
    if (properties is! Map) return;

    if (properties.containsKey('point_count')) {
      // Tapped a cluster: zoom in around the tap location to break it apart.
      final cameraState = await mapboxMap.getCameraState();
      await mapboxMap.flyTo(
        CameraOptions(center: context.point, zoom: cameraState.zoom + 2),
        MapAnimationOptions(duration: 300),
      );
      return;
    }

    final atmId = properties['atmId'] as String?;
    final atm = atmId != null ? _atmById[atmId] : null;
    if (atm != null) {
      _showAtmDetail(atm);
    }
  }

  Future<void> _centerOnUser(geolocator.Position position) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || _hasCenteredOnUser) return;
    _hasCenteredOnUser = true;
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(position.longitude, position.latitude)),
        zoom: 14,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _showAtmDetail(Atm atm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AtmDetailSheet(atm: atm),
    );
  }

  Future<void> _syncAnnotations(List<Atm> atms) async {
    final source = _atmSource;
    if (source == null) return;
    _atmById = {for (final atm in atms) atm.id: atm};

    final featureCollection = {
      'type': 'FeatureCollection',
      'features': [
        for (final atm in atms)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [atm.lng, atm.lat],
            },
            'properties': {
              'atmId': atm.id,
              'bankName': atm.bankName,
            },
          },
      ],
    };
    await source.updateGeoJSON(jsonEncode(featureCollection));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Atm>>>(atmListProvider, (previous, next) {
      next.whenData(_syncAnnotations);
    });
    ref.listen(userLocationProvider, (previous, next) {
      next.whenData(_centerOnUser);
    });

    final atmsAsync = ref.watch(atmListProvider);
    final nearestAtms = ref.watch(nearestAtmsProvider).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('ATM Scout')),
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_defaultCenterLng, _defaultCenterLat)),
              zoom: 12,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          if (atmsAsync.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (atmsAsync.hasError)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Failed to load ATMs: ${atmsAsync.error}'),
                ),
              ),
            ),
          if (nearestAtms.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 84,
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: nearestAtms.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final nearby = nearestAtms[index];
                    return ActionChip(
                      backgroundColor: Colors.white,
                      avatar: const Icon(Icons.place, size: 16),
                      label: Text(
                        '${nearby.atm.bankName} • ${formatDistance(nearby.distanceMeters)}',
                      ),
                      onPressed: () => _showAtmDetail(nearby.atm),
                    );
                  },
                ),
              ),
            ),
          const Positioned(
            bottom: 4,
            left: 8,
            child: IgnorePointer(
              child: Text(
                'ATM data © OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  backgroundColor: Color(0x99FFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAtmSheet(context),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add ATM'),
      ),
    );
  }

  void _showAddAtmSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddAtmSheet(),
    );
  }
}
