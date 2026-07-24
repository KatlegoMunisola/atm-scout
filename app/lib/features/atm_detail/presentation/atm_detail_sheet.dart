import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/atm.dart';
import '../../../shared/utils/time_ago.dart';
import '../../../shared/widgets/confidence_badge.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../quick_report/presentation/edit_atm_sheet.dart';
import '../../quick_report/presentation/quick_report_sheet.dart';
import '../application/atm_detail_providers.dart';

String _depositSupportLabel(DepositSupport value) {
  switch (value) {
    case DepositSupport.yes:
      return 'Accepts deposits';
    case DepositSupport.no:
      return 'Cash withdrawal only';
    case DepositSupport.unknown:
      return 'Deposit support unknown';
  }
}

class AtmDetailSheet extends ConsumerWidget {
  const AtmDetailSheet({super.key, required this.atm});

  final Atm atm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestReportAsync = ref.watch(latestReportProvider(atm.id));
    final denominationsAsync = ref.watch(denominationsProvider(atm.currencyCode));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(atm.bankName, style: Theme.of(context).textTheme.titleLarge),
              ),
              StatusBadge(status: atm.lastStatus),
              const SizedBox(width: 8),
              ConfidenceBadge(confidence: atm.confidence),
            ],
          ),
          if (atm.branchLabel != null) Text(atm.branchLabel!),
          if (atm.address != null)
            Text(atm.address!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(_depositSupportLabel(atm.depositSupport),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (atm.lastReportAt != null)
            Text('Last reported ${formatTimeAgo(atm.lastReportAt!)}',
                style: Theme.of(context).textTheme.bodySmall)
          else
            const Text('No reports yet — be the first!'),
          const SizedBox(height: 16),
          Text('Latest note tracker', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          latestReportAsync.when(
            data: (report) {
              if (report == null || report.denominationDispensed.isEmpty) {
                return const Text('No denomination data yet.');
              }
              return denominationsAsync.when(
                data: (denominations) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: denominations.map((d) {
                    final dispensed = report.denominationDispensed[d.id] ?? false;
                    return Chip(
                      label: Text(d.label),
                      backgroundColor:
                          dispensed ? Colors.green.shade100 : Colors.grey.shade200,
                      avatar: Icon(
                        dispensed ? Icons.check : Icons.close,
                        size: 16,
                        color: dispensed ? Colors.green : Colors.grey,
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('$error'),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Could not load report: $error'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Suggest an edit'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => EditAtmSheet(atm: atm),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_location_alt),
                  label: const Text('Report here'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => QuickReportSheet(atm: atm),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
