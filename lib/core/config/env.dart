import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment variable manager.
class Env {
  Env._();

  /// Bundled configuration file. Its name must not start with a dot, because
  /// Android's asset packaging silently drops dot-files from the APK.
  static const String fileName = 'app.env';

  /// Loads [fileName] from assets.
  static Future<void> init() async {
    await dotenv.load(fileName: fileName);
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

  static String get geminiModel =>
      dotenv.env['GEMINI_MODEL'] ?? 'gemini-flash-lite-latest';
}
