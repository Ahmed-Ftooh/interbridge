import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'package:interbridge/firebase_options.dart';
import 'package:interbridge/data/services/onesignal_service.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  Future<void> initialize() async {
    // Initialize Firebase Core (still needed for other Firebase features if any)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize OneSignal for push notifications
    // Get OneSignal App ID from environment variables
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
    if (oneSignalAppId != null && oneSignalAppId.isNotEmpty) {
      final oneSignalService = GetIt.instance<OneSignalService>();
      await oneSignalService.initialize(oneSignalAppId);
      debugPrint('✅ OneSignal initialized successfully');
      // Refresh player ID in case user is already logged in
      await oneSignalService.refreshPlayerId();
    } else {
      debugPrint('⚠ ONESIGNAL_APP_ID not found in environment variables');
      debugPrint('   Add ONESIGNAL_APP_ID=your-app-id to assets/.env');
    }
  }
}
