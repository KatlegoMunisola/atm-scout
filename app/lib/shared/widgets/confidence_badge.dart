import 'package:flutter/material.dart';

import '../models/atm.dart';

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.confidence});

  final AtmConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      AtmConfidence.high => ('High confidence', Colors.green),
      AtmConfidence.medium => ('Medium confidence', Colors.amber),
      AtmConfidence.low => ('Low confidence', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
