import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/env.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env)
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

  runApp(
    const ProviderScope(
      child: SplitBillApp(),
    ),
  );
}
