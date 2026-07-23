import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/atm.dart';
import '../../../shared/models/atm_report.dart';
import '../../../shared/models/denomination.dart';

class AtmRepository {
  AtmRepository(this._client);

  final SupabaseClient _client;

  Future<List<Atm>> fetchAtms() async {
    final rows = await _client
        .from('atms')
        .select(
          'id, bank_name, branch_label, atm_type, currency_code, lat, lng, address, last_status, last_report_at',
        )
        .order('created_at');
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Atm.fromJson)
        .toList();
  }

  Future<AtmReport?> fetchLatestReport(String atmId) async {
    final rows = await _client
        .from('atm_reports')
        .select(
          'id, atm_id, status, created_at, atm_report_notes(denomination_id, dispensed)',
        )
        .eq('atm_id', atmId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return AtmReport.fromJson(list.first);
  }

  Future<List<Denomination>> fetchDenominations(String currencyCode) async {
    final rows = await _client
        .from('denominations')
        .select('id, currency_code, value, label, sort_order')
        .eq('currency_code', currencyCode)
        .eq('active', true)
        .order('sort_order');
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Denomination.fromJson)
        .toList();
  }

  Future<void> submitReport({
    required String atmId,
    required double lat,
    required double lng,
    required double? accuracyMeters,
    required String status,
    required List<Map<String, dynamic>> denominations,
  }) {
    return _client.rpc<void>('submit_atm_report', params: {
      'p_atm_id': atmId,
      'p_lat': lat,
      'p_lng': lng,
      'p_accuracy_meters': accuracyMeters,
      'p_status': status,
      'p_denominations': denominations,
    });
  }

  Future<Atm> addAtm({
    required String bankName,
    required String atmType,
    required double lat,
    required double lng,
    String? branchLabel,
    String? address,
    String currencyCode = 'BWP',
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>('add_atm', params: {
      'p_bank_name': bankName,
      'p_atm_type': atmType,
      'p_lat': lat,
      'p_lng': lng,
      'p_branch_label': branchLabel,
      'p_address': address,
      'p_currency_code': currencyCode,
    });
    return Atm.fromJson(row);
  }

  RealtimeChannel subscribeToReports(void Function() onChange) {
    return _client
        .channel('atm-reports-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'atm_reports',
          callback: (payload) => onChange(),
        )
        .subscribe();
  }
}
