import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/firebase_service.dart';
import 'package:interbridge/core/network_service.dart';
import 'package:interbridge/core/error_service.dart';

class AppInitializer {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize dependency injection
    await initAppModule();

    // Load environment variables
    await dotenv.load(fileName: "assets/.env");

    // Validate required environment variables
    final requiredVars = [
      'AGORA_APP_ID',
      'AGORA_APP_CERTIFICATE',
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
    ];

    final missingVars = <String>[];
    for (final varName in requiredVars) {
      if (dotenv.env[varName] == null || dotenv.env[varName]!.isEmpty) {
        missingVars.add(varName);
      }
    }

    if (missingVars.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missingVars.join(', ')}\n'
        'Please check your assets/.env file and ensure all required variables are set.',
      );
    }

    // Initialize Supabase FIRST (before Firebase services that depend on it)
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    // Initialize Firebase using GetIt (after Supabase is ready)
    await instance<FirebaseService>().initialize();

    // Initialize Network Service
    await NetworkService().initialize();

    // Initialize Error Service
    await ErrorService().initialize();

    // Initialize Global Error Handler
    GlobalErrorHandler.initialize();
  }
}
