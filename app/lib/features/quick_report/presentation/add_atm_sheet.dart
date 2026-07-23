import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/geofence_service.dart';
import '../../../shared/models/atm.dart';
import '../../map/application/map_providers.dart';

class AddAtmSheet extends ConsumerStatefulWidget {
  const AddAtmSheet({super.key});

  @override
  ConsumerState<AddAtmSheet> createState() => _AddAtmSheetState();
}

class _AddAtmSheetState extends ConsumerState<AddAtmSheet> {
  final _bankNameController = TextEditingController();
  final _branchLabelController = TextEditingController();
  AtmType _atmType = AtmType.standalone;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bankNameController.dispose();
    _branchLabelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bankName = _bankNameController.text.trim();
    if (bankName.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final position = await GeofenceService.getCurrentPosition();
      await ref.read(atmRepositoryProvider).addAtm(
            bankName: bankName,
            atmType: atmTypeToString(_atmType),
            lat: position.latitude,
            lng: position.longitude,
            branchLabel: _branchLabelController.text.trim().isEmpty
                ? null
                : _branchLabelController.text.trim(),
          );
      await ref.read(atmListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ATM added — thanks for expanding the map!')),
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
          Text('Add a new ATM', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
              "Uses your current location as the ATM's position — stand next to it."),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add ATM'),
          ),
        ],
      ),
    );
  }
}
