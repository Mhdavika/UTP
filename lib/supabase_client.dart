import 'package:supabase_flutter/supabase_flutter.dart';

class SupaBaseClient {
  static const String url = "https://avztkbkbekvxfftvodui.supabase.co";
  static const String anonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."; // masukkan anon key kamu

  static Future<void> init() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
