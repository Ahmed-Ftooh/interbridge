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

    try {
      // Initialize dependency injection (fast - local operations only)
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
          'Please check your assets/.env file and ensure all required variables are set.\n'
          'You can copy env.template to assets/.env and fill in your actual values.',
        );
      }

      // Initialize Global Error Handler first (no network calls)
      GlobalErrorHandler.initialize();

      // Initialize Error Service (no network calls)
      await ErrorService().initialize();

      // Initialize services in parallel to reduce startup time
      await Future.wait([
        // Initialize Supabase
        Supabase.initialize(
          url: dotenv.env['SUPABASE_URL']!,
          anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
        ),
        // Initialize Network Service (with timeout)
        NetworkService().initialize().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Continue with initialization even if network check fails
            print('Network service initialization timed out, continuing...');
          },
        ),
      ]);

      // Initialize Firebase after Supabase is ready
      await instance<FirebaseService>().initialize();
    } catch (e) {
      // Log error but don't crash the app
      print('Error during app initialization: $e');
      // You might want to show a user-friendly error screen instead
      rethrow;
    }
  }
}
