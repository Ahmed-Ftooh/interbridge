import 'dart:developer';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' as callkit;
import 'package:interbridge/data/services/onesignal_service.dart';

/// Mobile-specific CallKit listener initialization
void initializeCallKitListeners({
  required void Function(String requestId, String callType) onCallAccepted,
  required void Function() onCallDeclined,
  required void Function() onCallEnded,
  required void Function() onCallTimeout,
}) {
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
          onCallAccepted(requestId, callType);
        }
        break;
      case callkit.Event.actionCallDecline:
        log('Call declined via CallKit');
        onCallDeclined();
        break;
      case callkit.Event.actionCallEnded:
        log('Call ended via CallKit');
        onCallEnded();
        break;
      case callkit.Event.actionCallTimeout:
        log('Call timed out via CallKit');
        onCallTimeout();
        break;
      default:
        log('Unhandled CallKit event: ${event.event}');
    }
  });
}
