import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Initializes and exposes the Supabase client.
class SupabaseConfig {
  SupabaseConfig._();

  static Future<void> init() async {
    // Only initialize if non-placeholder credentials exist
    if (Env.supabaseUrl.startsWith('http')) {
      try {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: Env.supabaseAnonKey,
        );
      } catch (_) {
        // Fallback for offline or local preview when credentials are not yet configured
      }
    }
  }

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
