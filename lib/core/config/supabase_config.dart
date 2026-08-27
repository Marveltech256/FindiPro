import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized configuration for the shared Supabase backend.
class SupabaseConfig {
  static const String supabaseUrl = 'https://jfrwwjwowjuxxvxlgaib.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_Zre0XvhBfswbi5PDIM4dTQ_XJjZtRen';
  static const String supabaseProjectRef = 'jfrwwjwowjuxxvxlgaib';
  static const String firebaseProjectId = 'findipro-7fe13';

  /// Initialize Supabase client
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      debug: false,
    );
  }

  /// Global Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;
}

