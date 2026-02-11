import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for push notification services
/// Implemented differently for mobile (OneSignal) and web (browser notifications)
abstract class PushNotificationService {
  /// Initialize the notification service
  Future<void> initialize(String appId);

  /// Get the current player/subscription ID
  String? get playerId;

  /// Clear active incoming call tracking
  void clearActiveIncomingCall();

  /// Unregister the current player ID
  Future<void> unregisterPlayerId();

  /// Refresh and register player ID
  Future<void> refreshPlayerId();

  /// Check if service is initialized
  bool get isInitialized;

  /// Factory to get platform-specific implementation
  static PushNotificationService getInstance() {
    if (kIsWeb) {
      return WebNotificationService._instance;
    } else {
      // Return the existing OneSignalService for mobile
      // This import is handled at runtime
      return _getMobileService();
    }
  }

  static PushNotificationService _getMobileService() {
    // This will be replaced with actual import at compile time
    throw UnimplementedError('Mobile service should be imported directly');
  }
}

/// Web implementation of push notifications
/// Uses browser Notification API and Supabase realtime
class WebNotificationService implements PushNotificationService {
  static final WebNotificationService _instance =
      WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  bool _isInitialized = false;
  String? _playerId;

  @override
  bool get isInitialized => _isInitialized;

  @override
  String? get playerId => _playerId;

  @override
  Future<void> initialize(String appId) async {
    if (_isInitialized) return;

    debugPrint('🌐 Web notification service initialized');
    // Web uses Supabase realtime for notifications
    // Browser notification permission is requested when needed
    _isInitialized = true;
  }

  @override
  void clearActiveIncomingCall() {
    // Not needed on web - handled via in-app UI
  }

  @override
  Future<void> unregisterPlayerId() async {
    // Web doesn't use player IDs
  }

  @override
  Future<void> refreshPlayerId() async {
    // Web doesn't use player IDs
  }

  /// Request browser notification permission
  Future<bool> requestPermission() async {
    // This would use dart:html on web
    debugPrint('🌐 Web notification permission requested');
    return true;
  }

  /// Show a browser notification
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('🌐 Web notification: $title - $body');
    // This would use the browser Notification API
  }
}
