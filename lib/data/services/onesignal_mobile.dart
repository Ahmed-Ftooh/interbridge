/// Mobile-specific OneSignal implementation
/// Exports mobile-only types and functions

export 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
export 'package:flutter_local_notifications/flutter_local_notifications.dart';
export 'package:onesignal_flutter/onesignal_flutter.dart';
export 'package:interbridge/data/services/callkit_service.dart';

// Re-export for convenience
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Mobile-specific initialization
Future<void> initializeLocalNotifications(
  FlutterLocalNotificationsPlugin localNotifications,
  void Function(NotificationResponse) onTap,
) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await localNotifications.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onTap,
  );
}

/// Create notification channel (Android)
Future<void> createNotificationChannel(
  FlutterLocalNotificationsPlugin localNotifications,
) async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Channel for critical notifications.',
    importance: Importance.high,
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

/// Check for active CallKit calls
Future<bool> hasActiveCallKitCalls() async {
  final activeCalls = await FlutterCallkitIncoming.activeCalls();
  return activeCalls is List && activeCalls.isNotEmpty;
}
