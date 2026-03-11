/// Web-specific stub implementations for OneSignal service
/// Provides no-op implementations for mobile-specific features
library;

import 'dart:developer';

// Stub classes for web platform
class FlutterLocalNotificationsPlugin {
  Future<void> initialize(
    dynamic settings, {
    Function? onDidReceiveNotificationResponse,
  }) async {}
}

class NotificationResponse {
  final String? payload;
  NotificationResponse({this.payload});
}

class FlutterCallkitIncoming {
  static Future<dynamic> activeCalls() async => [];
  static Future<void> showCallkitIncoming(dynamic params) async {}
  static Future<void> endCall(String uuid) async {}
}

class CallKitService {
  Future<void> showIncomingCall({
    required String callerName,
    required String callerId,
    String? callerAvatar,
    String? requestId,
    String callType = 'voice',
    String interpreterType = 'general',
    String? medicalSection,
  }) async {
    log('Web: CallKit not available, incoming call shown via in-app UI');
  }
}

// OneSignal stubs
class OneSignal {
  static final Debug = _DebugStub();
  static final Notifications = _NotificationsStub();
  static final User = _UserStub();

  static void initialize(String appId) {
    log('Web: OneSignal not available, using web notifications');
  }

  static void login(String userId) {}
  static void logout() {}
}

class _DebugStub {
  void setLogLevel(OSLogLevel level) {}
}

enum OSLogLevel { verbose, debug, info, warn, error }

class _NotificationsStub {
  Future<bool> requestPermission(bool show) async => false;
  void addForegroundWillDisplayListener(Function(dynamic) listener) {}
  void addClickListener(Function(dynamic) listener) {}
  void addPermissionObserver(Function(bool) listener) {}
}

class _UserStub {
  final pushSubscription = _PushSubscriptionStub();
}

class _PushSubscriptionStub {
  String? get id => null;
  String? get token => null;
  bool? get optedIn => false;
  void addObserver(Function(dynamic) observer) {}
}

// Helper functions that match mobile API
Future<void> initializeLocalNotifications(
  FlutterLocalNotificationsPlugin localNotifications,
  void Function(NotificationResponse) onTap,
) async {
  // No-op on web
}

Future<void> createNotificationChannel(
  FlutterLocalNotificationsPlugin localNotifications,
) async {
  // No-op on web
}

Future<bool> hasActiveCallKitCalls() async {
  return false;
}
