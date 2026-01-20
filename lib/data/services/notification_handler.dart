import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' as callkit;
import 'package:flutter_callkit_incoming/entities/entities.dart';
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

    // 3. Handle foreground messages - show CallKit for incoming calls
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.notification?.title}');
      final data = message.data;
      final type = data['type']?.toString().toUpperCase();

      // If it's an incoming call, show CallKit
      if (type == 'INCOMING_CALL') {
        log('Incoming call notification in foreground, showing CallKit');
        _showIncomingCallUI(data);
      }
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

  /// Show incoming call UI using CallKit
  void _showIncomingCallUI(Map<String, dynamic> data) {
    final requestId = data['request_id'] as String?;
    final callerName = data['caller_name'] as String? ?? 'Unknown Caller';
    final callType = data['call_type'] as String? ?? 'voice';
    final interpreterType = data['interpreter_type'] as String? ?? 'general';
    final medicalSection = data['medical_section'] as String?;

    if (requestId == null) {
      log('No request_id in incoming call data, skipping CallKit');
      return;
    }

    FlutterCallkitIncoming.showCallkitIncoming(
      CallKitParams(
        id: requestId,
        nameCaller: callerName,
        appName: 'Interbridge',
        handle: requestId,
        type: callType == 'video' ? 1 : 0,
        textAccept: 'Answer',
        textDecline: 'Decline',
        duration: 30000, // 30 seconds
        extra: <String, dynamic>{
          'request_id': requestId,
          'call_type': callType,
          'interpreter_type': interpreterType,
          'medical_section': medicalSection,
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: true,
          ringtonePath: 'call_ring', // References res/raw/call_ring.mp3
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          isShowFullLockedScreen: true,
        ),
        ios: const IOSParams(
          iconName: 'CallKitIcon',
          handleType: 'generic',
          supportsVideo: true,
          ringtonePath: 'Call_Ring',
        ),
      ),
    );
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
