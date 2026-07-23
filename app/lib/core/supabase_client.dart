import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase({required String url, required String anonKey}) {
  return Supabase.initialize(url: url, publishableKey: anonKey);
}
