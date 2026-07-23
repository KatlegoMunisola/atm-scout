import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/config/app_constants.dart';
import '../../../shared/models/atm.dart';
import '../../atm_detail/presentation/atm_detail_sheet.dart';
import '../../quick_report/presentation/add_atm_sheet.dart';
import '../application/map_providers.dart';

// Default camera center: Gaborone, Botswana.
const _defaultCenterLng = 25.9231;
const _defaultCenterLat = -24.6282;

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  PointAnnotationManager? _annotationManager;
  final Map<String, Atm> _annotationIdToAtm = {};

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    final manager = await mapboxMap.annotations.createPointAnnotationManager();
    manager.addOnPointAnnotationClickListener(
      _AtmAnnotationClickListener(onTap: _onAnnotationTapped),
    );
    _annotationManager = manager;
    final atms = ref.read(atmListProvider).valueOrNull;
    if (atms != null) {
      await _syncAnnotations(atms);
    }
  }

  void _onAnnotationTapped(String annotationId) {
    final atm = _annotationIdToAtm[annotationId];
    if (atm != null) {
      _showAtmDetail(atm);
    }
  }

  void _showAtmDetail(Atm atm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AtmDetailSheet(atm: atm),
    );
  }

  Future<void> _syncAnnotations(List<Atm> atms) async {
    final manager = _annotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    _annotationIdToAtm.clear();
    for (final atm in atms) {
      final annotation = await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(atm.lng, atm.lat)),
          iconImage: 'marker-15',
          iconSize: 1.8,
          textField: atm.bankName,
          textOffset: [0, 1.5],
          textSize: 11,
        ),
      );
      _annotationIdToAtm[annotation.id] = atm;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Atm>>>(atmListProvider, (previous, next) {
      next.whenData(_syncAnnotations);
    });

    final atmsAsync = ref.watch(atmListProvider);

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

class _AtmAnnotationClickListener extends OnPointAnnotationClickListener {
  _AtmAnnotationClickListener({required this.onTap});

  final void Function(String annotationId) onTap;

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onTap(annotation.id);
  }
}
