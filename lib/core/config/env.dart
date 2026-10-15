import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment variable manager.
class Env {
  Env._();

  /// Loads the .env file from assets.
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
  }

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder-anon-key';

  static String get appDomain =>
      dotenv.env['APP_DOMAIN'] ?? 'splitbill.app';

  static String get revenueCatAppleApiKey =>
      dotenv.env['REVENUECAT_APPLE_API_KEY'] ?? '';

  static String get revenueCatGoogleApiKey =>
      dotenv.env['REVENUECAT_GOOGLE_API_KEY'] ?? '';

  static String? get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'];
}
