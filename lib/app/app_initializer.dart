import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/firebase_service.dart';
import 'package:interbridge/core/network_service.dart';
import 'package:interbridge/core/error_service.dart';
import 'package:interbridge/data/services/notification_handler.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';

class AppInitializer {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Initialize dependency injection first (fast - local operations only)
      await initAppModule();

      // Load environment variables in parallel with other fast operations
      final envFuture = dotenv.load(fileName: "assets/.env");

      // Initialize Global Error Handler (no network calls)
      GlobalErrorHandler.initialize();

      // Wait for environment variables to load
      await envFuture;

      // Validate required environment variables
      final requiredVars = [
        'AGORA_APP_ID',
        'AGORA_APP_CERTIFICATE',
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
      ];

      final missingVars = <String>[];
      final placeholderVars = <String>[];

      for (final varName in requiredVars) {
        final value = dotenv.env[varName];
        if (value == null || value.isEmpty) {
          missingVars.add(varName);
        } else if (value.startsWith('your_') ||
            value.startsWith('PLACEHOLDER_')) {
          placeholderVars.add(varName);
        }
      }

      // Combine missing and placeholder variables
      final invalidVars = [...missingVars, ...placeholderVars];

      if (invalidVars.isNotEmpty) {
        final missingText =
            missingVars.isNotEmpty ? 'Missing: ${missingVars.join(', ')}' : '';
        final placeholderText =
            placeholderVars.isNotEmpty
                ? 'Placeholder values: ${placeholderVars.join(', ')}'
                : '';
        final issueText = [
          missingText,
          placeholderText,
        ].where((text) => text.isNotEmpty).join('\n');

        throw Exception(
          'Environment configuration issues:\n$issueText\n\n'
          'Please check your assets/.env file and ensure all required variables are set.\n'
          'You can copy env.template to assets/.env and fill in your actual values.\n\n'
          'Steps to fix:\n'
          '1. Copy env.template to assets/.env\n'
          '2. Fill in your actual Supabase and Agora credentials\n'
          '3. Restart the app\n\n'
          'Current environment variables found: ${dotenv.env.keys.isEmpty ? "None" : dotenv.env.keys.join(", ")}',
        );
      }

      // Initialize services in parallel to reduce startup time
      await Future.wait([
        // Initialize Supabase
        Supabase.initialize(
          url: dotenv.env['SUPABASE_URL']!,
          anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        ),
        // Initialize Error Service (no network calls)
        ErrorService().initialize(),
      ]);

      // OPTIMIZED: Initialize Firebase and Network Service in background
      // These are not critical for app startup and can complete after the app launches
      _initializeNonCriticalServices();

      // Listen for Supabase auth deep-link redirects to handle password reset
      // and email verification inside the app.
      Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
        final AuthChangeEvent type = event.event;
        // When a password recovery link is opened, the session is updated
        // and event type is passwordRecovery. Route to reset screen.
        if (type == AuthChangeEvent.passwordRecovery) {
          // We cannot navigate here (no BuildContext). Screens will check
          // current session and route accordingly. Nothing more needed.
          log('Auth event: passwordRecovery');
        }
        if (type == AuthChangeEvent.signedIn) {
          log('Auth event: signedIn');
          final didFinalize =
              await PendingRegistrationService().finalizePendingRegistration();
          if (didFinalize) {
            final navigator = MyApp.navigatorKey.currentState;
            navigator?.pushNamedAndRemoveUntil(
              Routes.mainRoute,
              (route) => false,
            );
          }
        }
        if (type == AuthChangeEvent.tokenRefreshed) {
          log('Auth event: tokenRefreshed');
          final didFinalize =
              await PendingRegistrationService().finalizePendingRegistration();
          if (didFinalize) {
            final navigator = MyApp.navigatorKey.currentState;
            navigator?.pushNamedAndRemoveUntil(
              Routes.mainRoute,
              (route) => false,
            );
          }
        }
      });

      log('App initialized successfully');
    } catch (e) {
      // Log error but don't crash the app
      log('Error during app initialization: $e');
      // You might want to show a user-friendly error screen instead
      rethrow;
    }
  }

  // OPTIMIZED: Non-blocking initialization for services not needed at startup
  static void _initializeNonCriticalServices() {
    // Run in background without blocking app launch
    Future.microtask(() async {
      try {
        // Initialize Network Service with short timeout
        await NetworkService().initialize().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            log('Network service initialization timed out, continuing...');
          },
        );
      } catch (e) {
        log('Network service initialization failed: $e');
      }

      try {
        // Initialize Firebase after other services are ready with timeout
        await instance<FirebaseService>().initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            log('Firebase initialization timed out, continuing...');
          },
        );

        // Initialize notification handler after Firebase is ready
        final notificationHandler = NotificationHandler(
          navigatorKey: MyApp.navigatorKey,
        );
        await notificationHandler.initialize();
        log('Notification handler initialized successfully');
      } catch (e) {
        log('Firebase initialization failed: $e');
      }
    });
  }
}
