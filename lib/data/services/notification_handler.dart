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

    log('Handling notification navigation: type=$type, requestId=$requestId');

    // --- THIS IS THE KEY LOGIC ---
    if (type == 'REQUEST_ACCEPTED' &&
        requestId != null &&
        interpreterId != null &&
        requesterId != null) {
      // Get the navigator state
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        log('Navigator state is null, cannot navigate');
        return;
      }

      // Navigate to the ChatView, clearing the stack
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
        (route) => false, // This removes all previous routes
      );
    } else {
      log('Notification data was not a valid REQUEST_ACCEPTED type');
    }
  }
}
