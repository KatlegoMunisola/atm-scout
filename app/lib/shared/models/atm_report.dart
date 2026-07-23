import 'atm.dart';

class AtmReport {
  const AtmReport({
    required this.id,
    required this.atmId,
    required this.status,
    required this.createdAt,
    this.denominationDispensed = const {},
  });

  final String id;
  final String atmId;
  final AtmStatus status;
  final DateTime createdAt;

  /// denominationId -> whether it was dispensed on this report.
  final Map<String, bool> denominationDispensed;

  factory AtmReport.fromJson(Map<String, dynamic> json) {
    final notes = (json['atm_report_notes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return AtmReport(
      id: json['id'] as String,
      atmId: json['atm_id'] as String,
      status: atmStatusFromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      denominationDispensed: {
        for (final note in notes)
          note['denomination_id'] as String: note['dispensed'] as bool,
      },
    );
  }
}
