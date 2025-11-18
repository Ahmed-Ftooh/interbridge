import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';

class NotificationHandler {
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationHandler({required this.navigatorKey});

  Future<void> initialize() async {
    // 1. Handle notification tap when app is in background or terminated
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        log('App opened from terminated state by notification');
        _handleNotificationNavigation(message.data);
      }
    });

    // 2. Handle notification tap when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('App opened from background by notification');
      _handleNotificationNavigation(message.data);
    });

    // 3. Handle foreground messages (optional, good for in-app alerts)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.notification?.title}');
      // You could show an in-app banner here if you want
    });
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final String? type = data['type'];
    final String? requestId = data['request_id'];
    final String? interpreterId = data['interpreter_id'];
    final String? requesterId =
        data['requester_id']; // Make sure your function sends this!

    log(
      'Handling notification navigation: type=$type, requestId=$requestId, interpreterId=$interpreterId, requesterId=$requesterId',
    );

    // --- THIS IS THE KEY LOGIC ---
    // Support both 'REQUEST_ACCEPTED' and 'request_accepted' (case-insensitive)
    if ((type == 'REQUEST_ACCEPTED' || type == 'request_accepted') &&
        requestId != null &&
        interpreterId != null &&
        requesterId != null) {
      // Wait for navigator to be ready (especially important when app is starting)
      _navigateWhenReady(requestId, requesterId, interpreterId);
    } else {
      log('Notification data was not a valid REQUEST_ACCEPTED type');
    }
  }

  void _navigateWhenReady(
    String requestId,
    String requesterId,
    String interpreterId,
  ) {
    // Try to get navigator state
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      log('Navigator not ready yet, waiting...');
      // Wait a bit and try again (app might still be initializing)
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateWhenReady(requestId, requesterId, interpreterId);
      });
      return;
    }

    log('Navigator ready, navigating to chat screen');

    // Navigate to the ChatView, clearing the entire stack
    // This ensures the request waiting screen is removed
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider(
              create: (_) => ChatBloc(service: ChatService()),
              child: ChatView(
                requestId: requestId,
                requesterId: requesterId,
                interpreterId: interpreterId,
              ),
            ),
      ),
      (route) =>
          false, // Remove ALL previous routes including request waiting screen
    );
  }
}
