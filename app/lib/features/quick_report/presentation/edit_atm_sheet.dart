import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/geofence_service.dart';
import '../../../shared/models/atm.dart';
import '../../map/application/map_providers.dart';

/// Lets a user correct an existing ATM's static details (bank name, branch
/// label, type, deposit support), or flag that the pin itself is in the
/// wrong place and reposition it to their current location.
class EditAtmSheet extends ConsumerStatefulWidget {
  const EditAtmSheet({super.key, required this.atm});

  final Atm atm;

  @override
  ConsumerState<EditAtmSheet> createState() => _EditAtmSheetState();
}

class _EditAtmSheetState extends ConsumerState<EditAtmSheet> {
  late final TextEditingController _bankNameController;
  late final TextEditingController _branchLabelController;
  late AtmType _atmType;
  late DepositSupport _depositSupport;
  bool _reposition = false;

  Position? _position;
  Object? _locationError;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bankNameController = TextEditingController(text: widget.atm.bankName);
    _branchLabelController =
        TextEditingController(text: widget.atm.branchLabel ?? '');
    _atmType = widget.atm.atmType;
    _depositSupport = widget.atm.depositSupport;
    _resolveLocation();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _branchLabelController.dispose();
    super.dispose();
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

  bool get _canSubmit {
    if (_position == null || _submitting) return false;
    if (_bankNameController.text.trim().isEmpty) return false;
    return _reposition || _withinRange;
  }

  Future<void> _submit() async {
    final position = _position;
    if (position == null || !_canSubmit) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(atmRepositoryProvider).submitCorrection(
            atmId: widget.atm.id,
            lat: position.latitude,
            lng: position.longitude,
            accuracyMeters: position.accuracy,
            reposition: _reposition,
            bankName: _bankNameController.text.trim(),
            branchLabel: _branchLabelController.text.trim(),
            atmType: atmTypeToString(_atmType),
            depositSupport: depositSupportToString(_depositSupport),
          );
      await ref.read(atmListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! ATM info updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Suggest an edit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          _buildLocationStatus(),
          const SizedBox(height: 16),
          TextField(
            controller: _bankNameController,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _branchLabelController,
            decoration:
                const InputDecoration(labelText: 'Branch / landmark (optional)'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AtmType>(
            segments: const [
              ButtonSegment(value: AtmType.standalone, label: Text('Standalone')),
              ButtonSegment(value: AtmType.inBranch, label: Text('In-branch')),
            ],
            selected: {_atmType},
            onSelectionChanged: (selection) =>
                setState(() => _atmType = selection.first),
          ),
          const SizedBox(height: 12),
          Text('Accepts deposits?', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<DepositSupport>(
            segments: const [
              ButtonSegment(value: DepositSupport.yes, label: Text('Yes')),
              ButtonSegment(value: DepositSupport.no, label: Text('No')),
              ButtonSegment(
                  value: DepositSupport.unknown, label: Text("Don't know")),
            ],
            selected: {_depositSupport},
            onSelectionChanged: (selection) =>
                setState(() => _depositSupport = selection.first),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This pin is in the wrong place'),
            subtitle: const Text('Moves it to your current location'),
            value: _reposition,
            onChanged: (value) => setState(() => _reposition = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit correction'),
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
    if (_reposition) {
      return const Row(
        children: [
          Icon(Icons.pin_drop, color: Colors.blue, size: 18),
          SizedBox(width: 6),
          Expanded(child: Text('The pin will move to your current location')),
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
                ? "You're close enough to submit"
                : 'Move closer to edit details (${distance.round()}m away), or flag the pin as wrong below',
          ),
        ),
      ],
    );
  }
}
