import 'dart:developer';

/// Web-specific notification handler - CallKit not available on web
/// Web will use browser notifications and in-app UI for incoming calls
void initializeCallKitListeners({
  required void Function(String requestId, String callType) onCallAccepted,
  required void Function() onCallDeclined,
  required void Function() onCallEnded,
  required void Function() onCallTimeout,
}) {
  // CallKit is not available on web
  // Incoming calls will be handled via Supabase realtime subscriptions
  // and shown as in-app dialogs/notifications
  log('Web platform: CallKit not available, using browser notifications');
}
