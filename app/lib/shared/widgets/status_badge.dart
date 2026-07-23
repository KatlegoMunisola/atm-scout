import 'package:flutter/material.dart';

import '../models/atm.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final AtmStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AtmStatus.functional => ('Functional', Colors.green),
      AtmStatus.outOfOrder => ('Out of Order', Colors.red),
      AtmStatus.noCash => ('No Cash', Colors.orange),
      AtmStatus.unknown => ('Unknown', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
