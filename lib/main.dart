import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/config/env.dart';
import 'core/config/supabase_config.dart';
import 'core/storage/local_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (app.env)
  try {
    await Env.init();
  } catch (e) {
    debugPrint('Env init warning: $e');
  }

  // Initialize Supabase client
  try {
    await SupabaseConfig.init();
  } catch (e) {
    debugPrint('Supabase init warning: $e');
  }

  // On-device storage for groups, expenses and settlements
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const SplitBillApp(),
    ),
  );
}
