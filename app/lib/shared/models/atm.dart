enum AtmType { inBranch, standalone }

enum AtmStatus { functional, outOfOrder, noCash, unknown }

enum DepositSupport { yes, no, unknown }

DepositSupport depositSupportFromString(String? value) {
  switch (value) {
    case 'yes':
      return DepositSupport.yes;
    case 'no':
      return DepositSupport.no;
    default:
      return DepositSupport.unknown;
  }
}

String depositSupportToString(DepositSupport value) {
  switch (value) {
    case DepositSupport.yes:
      return 'yes';
    case DepositSupport.no:
      return 'no';
    case DepositSupport.unknown:
      return 'unknown';
  }
}

/// Populated by the M2 `refresh_atm_confidence()` scheduled job (see
/// supabase/migrations/20260723071545_atm_confidence_decay.sql) from recent
/// atm_reports agreement/recency — not something the client computes.
enum AtmConfidence { high, medium, low }

AtmConfidence atmConfidenceFromString(String? value) {
  switch (value) {
    case 'high':
      return AtmConfidence.high;
    case 'medium':
      return AtmConfidence.medium;
    default:
      return AtmConfidence.low;
  }
}

AtmType atmTypeFromString(String value) =>
    value == 'in_branch' ? AtmType.inBranch : AtmType.standalone;

String atmTypeToString(AtmType type) =>
    type == AtmType.inBranch ? 'in_branch' : 'standalone';

AtmStatus atmStatusFromString(String? value) {
  switch (value) {
    case 'functional':
      return AtmStatus.functional;
    case 'out_of_order':
      return AtmStatus.outOfOrder;
    case 'no_cash':
      return AtmStatus.noCash;
    default:
      return AtmStatus.unknown;
  }
}

/// Converts a submittable status to the literal expected by submit_atm_report().
/// AtmStatus.unknown has no server-side representation and cannot be submitted.
String atmStatusToDbString(AtmStatus status) {
  switch (status) {
    case AtmStatus.functional:
      return 'functional';
    case AtmStatus.outOfOrder:
      return 'out_of_order';
    case AtmStatus.noCash:
      return 'no_cash';
    case AtmStatus.unknown:
      throw ArgumentError('AtmStatus.unknown cannot be submitted as a report');
  }
}

class Atm {
  const Atm({
    required this.id,
    required this.bankName,
    this.branchLabel,
    required this.atmType,
    required this.currencyCode,
    required this.lat,
    required this.lng,
    this.address,
    required this.lastStatus,
    this.lastReportAt,
    this.confidence = AtmConfidence.low,
    this.depositSupport = DepositSupport.unknown,
  });

  final String id;
  final String bankName;
  final String? branchLabel;
  final AtmType atmType;
  final String currencyCode;
  final double lat;
  final double lng;
  final String? address;
  final AtmStatus lastStatus;
  final DateTime? lastReportAt;
  final AtmConfidence confidence;
  final DepositSupport depositSupport;

  factory Atm.fromJson(Map<String, dynamic> json) {
    return Atm(
      id: json['id'] as String,
      bankName: json['bank_name'] as String,
      branchLabel: json['branch_label'] as String?,
      atmType: atmTypeFromString(json['atm_type'] as String),
      currencyCode: json['currency_code'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
      lastStatus: atmStatusFromString(json['last_status'] as String?),
      lastReportAt: json['last_report_at'] != null
          ? DateTime.parse(json['last_report_at'] as String)
          : null,
      confidence: atmConfidenceFromString(json['confidence'] as String?),
      depositSupport: depositSupportFromString(json['deposit_support'] as String?),
    );
  }
}
