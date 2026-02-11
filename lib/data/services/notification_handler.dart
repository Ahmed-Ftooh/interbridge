import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification handler for processing incoming notifications and call events.
/// OneSignal handles the actual notification delivery - this class handles
/// the navigation and call logic when notifications are acted upon.
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
    // On web, we don't need CallKit - we use Supabase realtime
    // and in-app dialogs for incoming calls
    if (kIsWeb) {
      log('NotificationHandler: Web platform - using in-app notifications');
      return;
    }

    // On mobile, initialize CallKit listeners via platform-specific code
    // This is now handled by the OneSignalService
    log(
      'NotificationHandler: Mobile platform - CallKit handled by OneSignalService',
    );
  }

  /// Handle accepting a call - called from CallKit (mobile) or in-app dialog (web)
  Future<void> handleCallAccepted(String requestId, String callType) async {
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
      log('Error accepting call: $e');
    }
  }

  void handleNotificationNavigation(Map<String, dynamic> data) {
    final String? type = data['type'];
    final String? requestId = data['request_id'];
    final String? callType = data['call_type'] ?? 'voice';

    log('Handling notification navigation: type=$type, requestId=$requestId');

    // Handle incoming call notification tap (interpreter taps on the notification)
    if ((type == 'incoming_call' || type == 'INCOMING_CALL') &&
        requestId != null) {
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

    final navigatorContext = navigator.context;

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
