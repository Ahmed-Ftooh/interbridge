import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:interbridge/firebase_options.dart';
import 'package:interbridge/data/services/firebase_messaging_service.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  // Top-level function for background message handling
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Handling a background message: ${message.messageId}');

    // Background message handling is minimal - just log for now
    // The main FirebaseMessagingService handles the rest when app is active
  }

  Future<void> initialize() async {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize the comprehensive Firebase messaging service using GetIt
    await GetIt.instance<FirebaseMessagingService>().initialize();
  }
}
