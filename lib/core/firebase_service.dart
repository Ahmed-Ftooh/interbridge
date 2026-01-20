import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:interbridge/firebase_options.dart';
import 'package:interbridge/data/services/firebase_messaging_service.dart';
import 'package:interbridge/data/services/callkit_service.dart';

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

    // Check for incoming call
    if (message.data['type'] == 'INCOMING_CALL' ||
        message.data['type'] == 'incoming_call') {
      final callerName = message.data['caller_name'] ?? 'Incoming Call Request';
      final callerId = message.data['caller_id'] ?? 'unknown';
      final callerAvatar = message.data['caller_avatar'] ?? '';
      final requestId = message.data['request_id'];
      final callType = message.data['call_type'] ?? 'voice';
      final interpreterType = message.data['interpreter_type'] ?? 'general';
      final medicalSection = message.data['medical_section'];

      await CallKitService().showIncomingCall(
        callerName: callerName,
        callerId: callerId,
        callerAvatar: callerAvatar,
        requestId: requestId,
        callType: callType,
        interpreterType: interpreterType,
        medicalSection: medicalSection,
      );
    }

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
