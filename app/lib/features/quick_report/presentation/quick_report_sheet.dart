import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/geofence_service.dart';
import '../../../shared/models/atm.dart';
import '../../../shared/widgets/denomination_chip.dart';
import '../../atm_detail/application/atm_detail_providers.dart';
import '../../map/application/map_providers.dart';

/// The tap-and-go report flow: pick a status, optionally confirm which notes
/// dispensed, submit. Designed for a "2 taps" common case (status + submit).
class QuickReportSheet extends ConsumerStatefulWidget {
  const QuickReportSheet({super.key, required this.atm});

  final Atm atm;

  @override
  ConsumerState<QuickReportSheet> createState() => _QuickReportSheetState();
}

class _QuickReportSheetState extends ConsumerState<QuickReportSheet> {
  Position? _position;
  Object? _locationError;
  AtmStatus? _selectedStatus;
  final Set<String> _dispensedDenominationIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    setState(() => _locationError = null);
    try {
      final position = await GeofenceService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _position = position);
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error);
    }
  }

  double? get _distanceMeters {
    final position = _position;
    if (position == null) return null;
    return GeofenceService.distanceMeters(
      fromLat: position.latitude,
      fromLng: position.longitude,
      toLat: widget.atm.lat,
      toLng: widget.atm.lng,
    );
  }

  bool get _withinRange {
    final distance = _distanceMeters;
    return distance != null && distance <= 50;
  }

  void _selectStatus(AtmStatus status) {
    setState(() {
      _selectedStatus = status;
      _dispensedDenominationIds.clear();
    });
  }

  Future<void> _submit() async {
    final status = _selectedStatus;
    final position = _position;
    if (status == null ||
        status == AtmStatus.unknown ||
        position == null ||
        !_withinRange) {
      return;
    }

    setState(() => _submitting = true);
    try {
      List<Map<String, dynamic>> payload = const [];
      if (status == AtmStatus.functional) {
        final denominations =
            ref.read(denominationsProvider(widget.atm.currencyCode)).value ??
                const [];
        payload = denominations
            .map((d) => {
                  'denomination_id': d.id,
                  'dispensed': _dispensedDenominationIds.contains(d.id),
                })
            .toList();
      }

      await ref.read(atmRepositoryProvider).submitReport(
            atmId: widget.atm.id,
            lat: position.latitude,
            lng: position.longitude,
            accuracyMeters: position.accuracy,
            status: atmStatusToDbString(status),
            denominations: payload,
          );

      await ref.read(atmListProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Report submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final denominationsAsync =
        ref.watch(denominationsProvider(widget.atm.currencyCode));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.atm.bankName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          _buildLocationStatus(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _StatusButton(
                label: 'Functional',
                color: Colors.green,
                selected: _selectedStatus == AtmStatus.functional,
                onTap: () => _selectStatus(AtmStatus.functional),
              ),
              _StatusButton(
                label: 'No Cash',
                color: Colors.orange,
                selected: _selectedStatus == AtmStatus.noCash,
                onTap: () => _selectStatus(AtmStatus.noCash),
              ),
              _StatusButton(
                label: 'Out of Order',
                color: Colors.red,
                selected: _selectedStatus == AtmStatus.outOfOrder,
                onTap: () => _selectStatus(AtmStatus.outOfOrder),
              ),
            ],
          ),
          if (_selectedStatus == AtmStatus.functional) ...[
            const SizedBox(height: 16),
            Text('Which notes came out?',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            denominationsAsync.when(
              data: (denominations) {
                if (_dispensedDenominationIds.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _dispensedDenominationIds.isEmpty) {
                      setState(() => _dispensedDenominationIds
                          .addAll(denominations.map((d) => d.id)));
                    }
                  });
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: denominations
                      .map((d) => DenominationChip(
                            label: d.label,
                            selected: _dispensedDenominationIds.contains(d.id),
                            onTap: () => setState(() {
                              if (_dispensedDenominationIds.contains(d.id)) {
                                _dispensedDenominationIds.remove(d.id);
                              } else {
                                _dispensedDenominationIds.add(d.id);
                              }
                            }),
                          ))
                      .toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text('Could not load denominations: $error'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                (_selectedStatus != null && _withinRange && !_submitting)
                    ? _submit
                    : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    if (_locationError != null) {
      return Row(
        children: [
          const Icon(Icons.location_off, color: Colors.red, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text('Location error: ${_locationError!}')),
          TextButton(onPressed: _resolveLocation, child: const Text('Retry')),
        ],
      );
    }
    if (_position == null) {
      return const Row(
        children: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking your location...'),
        ],
      );
    }
    final distance = _distanceMeters!;
    final withinRange = _withinRange;
    return Row(
      children: [
        Icon(
          withinRange ? Icons.check_circle : Icons.location_searching,
          color: withinRange ? Colors.green : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            withinRange
                ? "You're close enough to report"
                : 'Move closer to report (${distance.round()}m away)',
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.85),
      onSelected: (_) => onTap(),
    );
  }
}
