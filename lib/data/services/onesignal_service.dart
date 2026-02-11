import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/services/notification_service.dart';

// Import mobile packages only when on mobile platforms
// On web, we use Supabase realtime instead
import 'onesignal_mobile.dart'
    if (dart.library.html) 'onesignal_web.dart'
    as impl;

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  final impl.FlutterLocalNotificationsPlugin _localNotifications =
      impl.FlutterLocalNotificationsPlugin();

  String? _playerId;
  bool _isInitialized = false;

  // Track if we're currently showing an incoming call to prevent duplicates
  String? _activeIncomingCallId;

  // Lock to prevent concurrent calls to _showIncomingCall
  bool _isShowingIncomingCall = false;

  // Timestamp when the last incoming call was shown (to debounce)
  DateTime? _lastIncomingCallTime;

  /// Initialize OneSignal
  ///
  /// [appId] - Your OneSignal App ID from the dashboard
  Future<void> initialize(String appId) async {
    if (_isInitialized) {
      debugPrint('⚠ OneSignal already initialized');
      return;
    }

    // Skip native push notification setup on web
    if (kIsWeb) {
      debugPrint('📱 Web platform detected - using web notifications');
      _isInitialized = true;
      // On web, we'll use Supabase realtime for incoming calls
      // and browser notifications for alerts
      return;
    }

    try {
      // Local notifications setup (for custom notifications if needed)
      await _initializeLocalNotifications();

      // Enable verbose logging for debugging (remove in production)
      impl.OneSignal.Debug.setLogLevel(impl.OSLogLevel.verbose);

      // Initialize OneSignal
      impl.OneSignal.initialize(appId);

      // Request notification permission
      final permission = await impl.OneSignal.Notifications.requestPermission(
        true,
      );
      debugPrint('🔔 OneSignal notification permission: $permission');

      // Set up notification handlers
      _setupNotificationHandlers();

      // Get player ID (subscription ID) - may not be available immediately
      _playerId = impl.OneSignal.User.pushSubscription.id;
      debugPrint('📌 OneSignal Player ID (initial): $_playerId');
      debugPrint(
        '📌 OneSignal Token: ${impl.OneSignal.User.pushSubscription.token}',
      );
      debugPrint(
        '📌 OneSignal OptedIn: ${impl.OneSignal.User.pushSubscription.optedIn}',
      );

      // If player ID not available immediately, listen for changes
      impl.OneSignal.User.pushSubscription.addObserver((state) {
        debugPrint('🔄 OneSignal push subscription changed');
        debugPrint('   - ID: ${state.current.id}');
        debugPrint('   - Token: ${state.current.token}');
        debugPrint('   - Opted In: ${state.current.optedIn}');

        if (state.current.id != null && state.current.id != _playerId) {
          _playerId = state.current.id;
          debugPrint('📌 New OneSignal Player ID: $_playerId');
          _registerPlayerId(_playerId!);
        }
      });

      // Register player ID if available
      if (_playerId != null) {
        await _registerPlayerId(_playerId!);
      } else {
        // Player ID not available yet, try again after a delay
        debugPrint('⏳ OneSignal Player ID not available yet, will retry...');
        _retryGetPlayerId();
      }

      // Listen for auth changes to register player ID when user logs in
      _client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          if (_playerId != null) {
            _registerPlayerId(_playerId!);
          }
          // Also set external user ID for targeting
          final user = _client.auth.currentUser;
          if (user != null) {
            impl.OneSignal.login(user.id);
            debugPrint('🔗 OneSignal external user ID set: ${user.id}');
          }
        } else if (event == AuthChangeEvent.signedOut) {
          // Logout from OneSignal when user signs out
          impl.OneSignal.logout();
          debugPrint('👋 OneSignal user logged out');
        }
      });

      // Set initial external user ID if user is already logged in
      final currentUser = _client.auth.currentUser;
      if (currentUser != null) {
        impl.OneSignal.login(currentUser.id);
        debugPrint('🔗 OneSignal external user ID set: ${currentUser.id}');
      }

      _isInitialized = true;
      debugPrint('✅ OneSignal initialized');
    } catch (e) {
      debugPrint('❌ Error initializing OneSignal: $e');
    }
  }

  /// Set up notification handlers
  void _setupNotificationHandlers() {
    // Foreground notification received - app is open and visible
    impl.OneSignal.Notifications.addForegroundWillDisplayListener((
      event,
    ) async {
      debugPrint('📩 OneSignal foreground notification received');
      debugPrint('   - Title: ${event.notification.title}');
      debugPrint('   - Body: ${event.notification.body}');
      debugPrint('   - Data: ${event.notification.additionalData}');

      final data = event.notification.additionalData ?? {};

      // Check for incoming call
      if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
        debugPrint('📞 Incoming call notification received in foreground');
        // Don't display the notification banner, show CallKit instead
        event.preventDefault();

        // Check if interpreter is online before showing CallKit
        final isOnline = await _checkInterpreterOnlineStatus();
        if (!isOnline) {
          debugPrint(
            '📞 Interpreter is offline, ignoring incoming call notification',
          );
          return;
        }

        // Check if CallKit is already showing an active call
        final hasActiveCalls = await impl.hasActiveCallKitCalls();
        if (hasActiveCalls) {
          debugPrint(
            '📞 CallKit already has active calls, skipping foreground',
          );
          return;
        }

        await _showIncomingCall(data);
        return;
      }

      // Let OneSignal display the notification
      event.notification.display();

      // Also save to local notifications store
      NotificationService().createNotificationFromFCM(
        title: event.notification.title ?? 'Notification',
        body: event.notification.body ?? '',
        data: Map<String, dynamic>.from(data),
        type: data['type']?.toString() ?? 'general',
      );
    });

    // Notification clicked/opened - user tapped on notification
    impl.OneSignal.Notifications.addClickListener((event) async {
      debugPrint('📲 OneSignal notification clicked');
      debugPrint('   - Title: ${event.notification.title}');
      debugPrint('   - Data: ${event.notification.additionalData}');

      final data = event.notification.additionalData ?? {};

      // Check for incoming call
      if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
        debugPrint('📞 Incoming call notification tapped');

        // Check if CallKit is already showing an active call
        final hasActiveCalls = await impl.hasActiveCallKitCalls();
        if (hasActiveCalls) {
          debugPrint('📞 CallKit already has active calls, skipping');
          return;
        }

        await _showIncomingCall(data);
        return;
      }

      // Handle other notification types - navigation can be done here
      // The app will handle navigation based on the data
    });

    // Permission state changed
    impl.OneSignal.Notifications.addPermissionObserver((permission) {
      debugPrint('🔔 OneSignal permission changed: $permission');
    });
  }

  /// Show incoming call via CallKit
  Future<void> _showIncomingCall(Map<String, dynamic> data) async {
    // Prevent concurrent calls
    if (_isShowingIncomingCall) {
      debugPrint('📞 Already processing an incoming call, skipping');
      return;
    }

    try {
      _isShowingIncomingCall = true;

      final callerName =
          data['caller_name']?.toString() ??
          data['title']?.toString() ??
          'Incoming Call';
      final callerId =
          data['caller_id']?.toString() ??
          data['request_id']?.toString() ??
          'unknown';
      final callerAvatar = data['caller_avatar']?.toString() ?? '';
      final requestId = data['request_id']?.toString();
      final callType = data['call_type']?.toString() ?? 'voice';
      final interpreterType = data['interpreter_type']?.toString() ?? 'general';
      final medicalSection = data['medical_section']?.toString();

      // Check if we already have this call showing
      if (_activeIncomingCallId == requestId && requestId != null) {
        debugPrint('📞 Incoming call already showing for request: $requestId');
        _isShowingIncomingCall = false;
        return;
      }

      // Debounce - don't show another call within 2 seconds
      if (_lastIncomingCallTime != null) {
        final elapsed = DateTime.now().difference(_lastIncomingCallTime!);
        if (elapsed.inSeconds < 2) {
          debugPrint(
            '📞 Debouncing incoming call (${elapsed.inMilliseconds}ms since last)',
          );
          _isShowingIncomingCall = false;
          return;
        }
      }

      // Check if CallKit already has active calls
      final hasActiveCalls = await impl.hasActiveCallKitCalls();
      if (hasActiveCalls) {
        debugPrint('📞 CallKit already has active calls');
        _isShowingIncomingCall = false;
        return;
      }

      // Track the active call
      _activeIncomingCallId = requestId;
      _lastIncomingCallTime = DateTime.now();
      debugPrint('📞 Showing incoming call for request: $requestId');

      await impl.CallKitService().showIncomingCall(
        callerName: callerName,
        callerId: callerId,
        callerAvatar: callerAvatar,
        requestId: requestId,
        callType: callType,
        interpreterType: interpreterType,
        medicalSection: medicalSection,
      );
    } catch (e) {
      debugPrint('Error showing incoming call: $e');
      _activeIncomingCallId = null;
    } finally {
      _isShowingIncomingCall = false;
    }
  }

  /// Clear the active incoming call (call when call ends or is declined)
  void clearActiveIncomingCall() {
    debugPrint('📞 Clearing active incoming call: $_activeIncomingCallId');
    _activeIncomingCallId = null;
  }

  /// Check if the current interpreter is online
  Future<bool> _checkInterpreterOnlineStatus() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final response =
          await _client
              .from('interpreter_details')
              .select('is_online')
              .eq('user_id', userId)
              .maybeSingle();

      return response?['is_online'] == true;
    } catch (e) {
      debugPrint('Error checking interpreter online status: $e');
      return false;
    }
  }

  /// Local notification setup (for any custom notification needs)
  Future<void> _initializeLocalNotifications() async {
    await impl.initializeLocalNotifications(
      _localNotifications,
      _onNotificationTapped,
    );
    await _createNotificationChannel();
  }

  /// Android notification channel
  Future<void> _createNotificationChannel() async {
    await impl.createNotificationChannel(_localNotifications);
  }

  /// On local notification tap
  void _onNotificationTapped(impl.NotificationResponse response) {
    debugPrint('📲 Local notification tapped: ${response.payload}');
  }

  /// Retry getting player ID with exponential backoff
  Future<void> _retryGetPlayerId({int attempt = 1, int maxAttempts = 5}) async {
    if (attempt > maxAttempts) {
      debugPrint(
        '❌ Failed to get OneSignal Player ID after $maxAttempts attempts',
      );
      return;
    }

    // Wait with exponential backoff (2s, 4s, 8s, 16s, 32s)
    final delay = Duration(seconds: 2 * attempt);
    debugPrint(
      '⏳ Retry attempt $attempt/$maxAttempts in ${delay.inSeconds}s...',
    );
    await Future.delayed(delay);

    _playerId = impl.OneSignal.User.pushSubscription.id;
    debugPrint('📌 OneSignal Player ID (retry $attempt): $_playerId');

    if (_playerId != null) {
      debugPrint('✅ Got OneSignal Player ID on retry $attempt: $_playerId');
      await _registerPlayerId(_playerId!);
    } else {
      // Try again
      await _retryGetPlayerId(attempt: attempt + 1, maxAttempts: maxAttempts);
    }
  }

  /// Register player ID in Supabase
  Future<void> _registerPlayerId(String playerId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('⚠ User not authenticated, skipping player ID registration');
        return;
      }

      debugPrint('🔄 Registering player ID: $playerId for user: ${user.id}');

      // Clean up old player IDs for this user first
      await _cleanupOldUserPlayerIds(user.id);

      await _client.from('onesignal_player_ids').upsert({
        'user_id': user.id,
        'player_id': playerId,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,player_id');

      debugPrint('✅ OneSignal player ID registered in Supabase');
    } catch (e) {
      debugPrint('❌ Error registering player ID: $e');
    }
  }

  /// Clean up old player IDs for a user
  Future<void> _cleanupOldUserPlayerIds(String userId) async {
    try {
      // Keep only the 3 most recent player IDs per user
      final response = await _client
          .from('onesignal_player_ids')
          .select('id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response.length > 3) {
        final idsToDelete = response.skip(3).map((row) => row['id']).toList();

        await _client
            .from('onesignal_player_ids')
            .delete()
            .inFilter('id', idsToDelete);

        debugPrint(
          '🧹 Cleaned up ${idsToDelete.length} old player IDs for user',
        );
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up old player IDs: $e');
    }
  }

  /// Unregister player ID
  Future<void> unregisterPlayerId() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || _playerId == null) return;

      await _client
          .from('onesignal_player_ids')
          .delete()
          .eq('user_id', user.id)
          .eq('player_id', _playerId!);

      // Logout from OneSignal
      impl.OneSignal.logout();

      debugPrint('🗑 Player ID removed from Supabase');
    } catch (e) {
      debugPrint('❌ Error unregistering player ID: $e');
    }
  }

  /// Manually refresh and register player ID
  /// Call this after login to ensure player ID is registered
  Future<void> refreshPlayerId() async {
    debugPrint('🔄 Manually refreshing OneSignal Player ID...');
    _playerId = impl.OneSignal.User.pushSubscription.id;
    debugPrint('📌 Current Player ID: $_playerId');
    debugPrint(
      '📌 Current Token: ${impl.OneSignal.User.pushSubscription.token}',
    );
    debugPrint('📌 Opted In: ${impl.OneSignal.User.pushSubscription.optedIn}');

    if (_playerId != null) {
      await _registerPlayerId(_playerId!);
    } else {
      debugPrint('⚠ Player ID still null, starting retry...');
      await _retryGetPlayerId();
    }
  }

  /// Dispose (cleanup)
  void dispose() {
    _isInitialized = false;
  }

  String? get playerId => _playerId;
  bool get isInitialized => _isInitialized;
}
