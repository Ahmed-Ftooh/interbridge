import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/firebase_service.dart';
import 'package:interbridge/core/network_service.dart';
import 'package:interbridge/core/error_service.dart';
import 'package:interbridge/data/services/notification_handler.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';

// Conditional import for app_links (not available on web)
import 'app_initializer_mobile.dart'
    if (dart.library.html) 'app_initializer_web.dart'
    as platform;

class AppInitializer {
  // Track if we've already handled the initial auth navigation to prevent
  // duplicate navigations that could interrupt user flow (e.g., during quizzes)
  static bool _hasHandledInitialAuth = false;

  /// Whether a deep link (magic link) is pending processing during cold start.
  /// The Splash / Auth Gate checks this to wait for the auth session to resolve
  /// instead of navigating prematurely.
  static bool deepLinkPending = false;

  /// Reset the auth navigation flag. Call this when the user signs out.
  static void resetAuthState() {
    _hasHandledInitialAuth = false;
    deepLinkPending = false;
  }

  /// Mark the initial auth as handled. Called by the Splash / Auth Gate once
  /// it has resolved the auth state and navigated.
  static void markInitialAuthHandled() {
    _hasHandledInitialAuth = true;
  }

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Reset flag on each initialization (e.g., hot restart)
      _hasHandledInitialAuth = false;
      deepLinkPending = false;

      // Initialize dependency injection first (fast - local operations only)
      await initAppModule();

      // Load environment variables in parallel with other fast operations
      // On web (cPanel etc.) the fetch may fail if the host blocks dotfiles,
      // so wrap with a timeout + catch so the rest of init can continue.
      try {
        await dotenv
            .load(fileName: "assets/config.env")
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                log('dotenv load timed out — continuing with defaults');
              },
            );
      } catch (envErr) {
        log('dotenv load failed: $envErr — continuing with defaults');
      }

      // Initialize Global Error Handler (no network calls)
      GlobalErrorHandler.initialize();

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

        final errorMsg =
            'Environment configuration issues:\n$issueText\n\n'
            'Please check your assets/.env file and ensure all required variables are set.';

        log(errorMsg);

        // On web, don't throw — the login page will still render and
        // show an error when the user tries to interact with the backend.
        if (!kIsWeb) {
          throw Exception(errorMsg);
        }
      }

      // Initialize services in parallel to reduce startup time
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
        await Future.wait([
          // Initialize Supabase — give it its own 15-second guard so a slow
          // network on cPanel does not silently hang the outer 10-second
          // timeout and cause runApp() to fire before Supabase is ready.
          Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseKey,
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              log('Supabase.initialize() timed out after 15 s');
              return Supabase.instance;
            },
          ),
          // Initialize Error Service (no network calls)
          ErrorService().initialize(),
        ]);
      } else {
        log('Supabase credentials missing — skipping Supabase init');
        await ErrorService().initialize();
      }

      // Initialize Stripe (non-web only)
      if (!kIsWeb) {
        final stripeKey = dotenv.env['STRIPEPUBLISHABLEKEY'] ?? '';
        if (stripeKey.isNotEmpty && stripeKey.startsWith('pk_')) {
          Stripe.publishableKey = stripeKey;
          log('Stripe initialized with publishable key');
        } else {
          log('Stripe publishable key not configured, payment sheet disabled');
        }
      }

      // OPTIMIZED: Initialize Firebase and Network Service in background
      // These are not critical for app startup and can complete after the app launches
      _initializeNonCriticalServices();

      // Set up deep link handling for auth callbacks (platform-specific)
      platform.setupDeepLinkHandling(_handleDeepLink);

      // Listen for Supabase auth deep-link redirects to handle password reset
      // and email verification inside the app.
      // Guard with try-catch: Supabase.instance throws if not initialized.
      try {
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

            // Determine whether this is a cold-start or warm-start sign-in.
            final wasColdStart = !_hasHandledInitialAuth;

            // Always run finalization / invite check regardless of cold/warm
            final didFinalize =
                await PendingRegistrationService()
                    .finalizePendingRegistration();

            final user = Supabase.instance.client.auth.currentUser;
            if (user != null && user.email != null && !didFinalize) {
              final supabaseService = SupabaseService();
              await supabaseService.checkAndProcessPendingInvite(
                user.id,
                user.email!,
              );
            }

            if (wasColdStart) {
              // Cold start: The Splash / Auth Gate will detect the session and
              // navigate. We just mark initial auth as handled to prevent the
              // Splash from racing with us.
              _hasHandledInitialAuth = true;
              log(
                'Auth event: signedIn (cold start) — splash will handle navigation',
              );
            } else {
              // Warm start: The user tapped a magic link while the app was
              // already running. Navigate from here.
              _hasHandledInitialAuth = true;
              // On web, the LoginViewWeb (or BlocListener) handles navigation
              // itself — including finalization. Skip here to avoid a race
              // condition where two navigations fire concurrently and the
              // first one queries the DB before finalization is done.
              if (!kIsWeb) {
                final navigator = MyApp.navigatorKey.currentState;
                if (user != null && navigator != null) {
                  log(
                    'Auth event: signedIn (warm start) — navigating based on role',
                  );
                  await _navigateBasedOnRole(navigator, user.id);
                }
              } else {
                log(
                  'Auth event: signedIn (warm start, web) — LoginViewWeb handles navigation',
                );
              }
            }
          }
          if (type == AuthChangeEvent.tokenRefreshed) {
            // Token refresh happens automatically and should NOT trigger navigation
            // as it would interrupt the user's current activity (e.g., taking a quiz)
            log('Auth event: tokenRefreshed (no navigation)');
          }
        });
      } catch (supabaseErr) {
        log(
          'Supabase auth listener setup failed (Supabase may not be initialized): $supabaseErr',
        );
      }

      log('App initialized successfully');
    } catch (e) {
      // Log error but don't crash the app
      log('Error during app initialization: $e');
      // On web: swallow the error so runApp() still executes and the
      // HTML loading screen is dismissed.  The login page will appear
      // and Supabase operations will fail gracefully if the backend is
      // unreachable.
      if (!kIsWeb) rethrow;
    }
  }

  static Future<void> _navigateBasedOnRole(
    NavigatorState navigator,
    String userId,
  ) async {
    try {
      final supabaseService = SupabaseService();
      final profile = await supabaseService.getUserProfile(userId);

      if (profile?.role == 'organization_admin') {
        navigator.pushNamedAndRemoveUntil(
          Routes.organizationDashboardRoute,
          (route) => false,
        );
      } else if (profile?.role == 'interpreter') {
        // Only check quizzes on first login — skip if already completed once
        final appPrefs = instance<AppPreferences>();
        if (appPrefs.isQuizOnboardingDone()) {
          navigator.pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        } else {
          // For interpreters, check if they still need to complete qualification quizzes
          try {
            // Query employment_type and badges directly to decide navigation
            final client = Supabase.instance.client;
            final profileData =
                await client
                    .from('users_profile')
                    .select('employment_type')
                    .eq('user_id', userId)
                    .maybeSingle();

            final badgesData = await client
                .from('interpreter_badges')
                .select('badge')
                .eq('user_id', userId);
            final fluencyData = await client
                .from('voice_samples')
                .select('id')
                .eq('user_id', userId)
                .eq('sentence_type', advancedFluencySentenceType);

            final employmentType =
                profileData?['employment_type'] ?? 'volunteer';
            final badges =
                (badgesData as List)
                    .map((b) => b['badge']?.toString() ?? '')
                    .where((b) => b.isNotEmpty)
                    .toSet();

            final hasGeneral = badges.contains('general');
            final medicalCount = badges.where((b) => b != 'general').length;
            final hasAdvancedFluency =
                (fluencyData as List).length >= advancedFluencyQuestionCount;

            final bool isExperienced = employmentType == 'paid';
            final bool allComplete =
                isExperienced
                    ? (hasGeneral && medicalCount >= 10 && hasAdvancedFluency)
                    : (hasGeneral && hasAdvancedFluency);

            if (allComplete) {
              await appPrefs.setQuizOnboardingDone();
              navigator.pushNamedAndRemoveUntil(
                Routes.mainRoute,
                (route) => false,
              );
            } else {
              navigator.pushNamedAndRemoveUntil(
                Routes.interpreterQuizHubRoute,
                (route) => false,
              );
            }
          } catch (e) {
            // On error, fallback to main route
            log('Error checking interpreter quiz status: $e');
            navigator.pushNamedAndRemoveUntil(
              Routes.mainRoute,
              (route) => false,
            );
          }
        }
      } else {
        navigator.pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      log('Error getting user profile for navigation: $e');
      navigator.pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

  static Future<void> _handleDeepLink(Uri uri) async {
    log('Processing deep link: $uri');

    // Check if this is a Supabase auth callback — be generous with matching
    // to handle custom domains, different URL formats, etc.
    final isAuthCallback =
        uri.scheme == 'io.supabase.flutter' ||
        uri.host == 'login-callback' ||
        uri.toString().contains('login-callback') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('token') ||
        uri.fragment.contains('access_token');

    if (isAuthCallback) {
      log('Deep link is auth callback — marking as pending');

      // Mark deep link as pending so the Splash / Auth Gate waits for
      // the auth session to resolve before navigating.
      deepLinkPending = true;

      // Do NOT push a route here. Supabase's internal PKCE handler will
      // process the auth code and fire onAuthStateChange.signedIn.
      // The Splash (mobile) or LoginViewWeb (web) will listen and navigate.
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
