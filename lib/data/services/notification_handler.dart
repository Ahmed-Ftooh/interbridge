import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' as callkit;
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationHandler {
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationHandler({required this.navigatorKey});

  /// Build a stable int UID from the authenticated user UUID
  static int _uidFromUuid(String uuid) {
    if (uuid.isNotEmpty) {
      final hex = uuid.replaceAll('-', '');
      final first8 =
          hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
      return int.tryParse(first8, radix: 16) ?? 1;
    }
    return 1;
  }

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

    // 4. Handle CallKit incoming call events (accept/decline from native UI)
    FlutterCallkitIncoming.onEvent.listen((callkit.CallEvent? event) {
      if (event == null) return;
      log('CallKit event received: ${event.event}');

      switch (event.event) {
        case callkit.Event.actionCallAccept:
          // User accepted the call from the native call UI
          final extra = event.body['extra'] as Map<String, dynamic>?;
          final requestId = extra?['request_id'] as String?;
          final callType = extra?['call_type'] as String? ?? 'voice';
          log(
            'Call accepted via CallKit: requestId=$requestId, callType=$callType',
          );
          if (requestId != null) {
            _handleCallAccepted(requestId, callType);
          }
          break;
        case callkit.Event.actionCallDecline:
          // User declined the call from the native call UI
          log('Call declined via CallKit');
          break;
        case callkit.Event.actionCallEnded:
          // Call ended
          log('Call ended via CallKit');
          break;
        default:
          log('Unhandled CallKit event: ${event.event}');
      }
    });
  }

  /// Handle accepting a call from the CallKit native UI
  Future<void> _handleCallAccepted(String requestId, String callType) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        log('User not authenticated, cannot accept call');
        return;
      }

      // Accept the interpreter request in the database
      await client
          .from('interpreter_requests')
          .update({
            'status': 'accepted',
            'accepted_by': currentUser.id,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'pending');

      // Navigate to the call screen
      final isVideoCall = callType == 'video';
      final myUid = _uidFromUuid(currentUser.id);

      _navigateToCallScreen(
        requestId: requestId,
        isVideoCall: isVideoCall,
        localUid: myUid,
      );
    } catch (e) {
      log('Error accepting call from CallKit: $e');
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final String? type = data['type'];
    final String? requestId = data['request_id'];
    final String? callType = data['call_type'] ?? 'voice';

    log('Handling notification navigation: type=$type, requestId=$requestId');

    // Handle incoming call notification tap (interpreter taps on the notification)
    if ((type == 'incoming_call' || type == 'INCOMING_CALL') &&
        requestId != null) {
      // Navigate to the interpreter home to see the job and accept it
      // Or show an accept dialog
      log('Incoming call notification tapped, navigating to accept');
      _navigateToJobAcceptance(requestId, callType ?? 'voice');
      return;
    }

    // Handle request accepted notification (requester gets notified)
    if ((type == 'REQUEST_ACCEPTED' || type == 'request_accepted') &&
        requestId != null) {
      final isVideoCall = callType == 'video';
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final myUid = _uidFromUuid(currentUser.id);
        _navigateToCallScreen(
          requestId: requestId,
          isVideoCall: isVideoCall,
          localUid: myUid,
        );
      }
    }
  }

  void _navigateToJobAcceptance(String requestId, String callType) {
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      log('Navigator not ready yet, waiting...');
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToJobAcceptance(requestId, callType);
      });
      return;
    }

    // Navigate to main/interpreter home so they can accept the job
    // The interpreter will see the job card and can tap accept
    navigator.pushNamedAndRemoveUntil('/main', (route) => false);
  }

  void _navigateToCallScreen({
    required String requestId,
    required bool isVideoCall,
    required int localUid,
  }) {
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      log('Navigator not ready yet, waiting...');
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToCallScreen(
          requestId: requestId,
          isVideoCall: isVideoCall,
          localUid: localUid,
        );
      });
      return;
    }

    log('Navigator ready, navigating to call screen');

    // Get the context from the navigator to access the CallBloc
    final navigatorContext = navigator.context;

    // Start the call via CallBloc before navigation
    try {
      navigatorContext.read<CallBloc>().add(
        StartCall(
          channelId: requestId,
          localUid: localUid,
          isVideoCall: isVideoCall,
        ),
      );
    } catch (e) {
      log('Error starting call from notification: $e');
    }

    // Navigate to the call screen
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (context) => EnhancedCallScreen(
              channelId: requestId,
              isVideoCall: isVideoCall,
            ),
      ),
      (route) => false,
    );
  }
}
