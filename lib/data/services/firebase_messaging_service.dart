// import 'dart:async';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:interbridge/data/services/notification_service.dart';
// import 'package:interbridge/data/services/callkit_service.dart';

// class FirebaseMessagingService {
//   static final FirebaseMessagingService _instance =
//       FirebaseMessagingService._internal();
//   factory FirebaseMessagingService() => _instance;
//   FirebaseMessagingService._internal();

//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   SupabaseClient get _client => Supabase.instance.client;

//   final FlutterLocalNotificationsPlugin _localNotifications =
//       FlutterLocalNotificationsPlugin();

//   String? _fcmToken;
//   bool _isInitialized = false;

//   StreamSubscription<RemoteMessage>? _onMessageSubscription;
//   StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
//   StreamSubscription<String>? _onTokenRefreshSubscription;

//   /// Initialize Firebase Messaging
//   Future<void> initialize() async {
//     if (_isInitialized) {
//       debugPrint('⚠ Firebase Messaging already initialized');
//       return;
//     }

//     try {
//       // Local notifications setup
//       await _initializeLocalNotifications();

//       // Request permission explicitly
//       NotificationSettings settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//       debugPrint(
//         '🔔 Notification permission status: ${settings.authorizationStatus}',
//       );

//       // Get token
//       _fcmToken = await _messaging.getToken();
//       debugPrint('📌 Initial FCM Token: $_fcmToken');

//       if (_fcmToken != null) {
//         await _registerFCMToken(_fcmToken!);
//       }

//       // Listen for auth changes to register token when user logs in
//       _client.auth.onAuthStateChange.listen((data) {
//         final event = data.event;
//         if (event == AuthChangeEvent.signedIn ||
//             event == AuthChangeEvent.tokenRefreshed ||
//             event == AuthChangeEvent.initialSession) {
//           if (_fcmToken != null) {
//             _registerFCMToken(_fcmToken!);
//           }
//         }
//       });

//       // Foreground message handler
//       _onMessageSubscription = FirebaseMessaging.onMessage.listen(
//         _handleForegroundMessage,
//       );

//       // App opened via notification
//       _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
//           .listen(_handleBackgroundMessage);

//       // Token refresh
//       _onTokenRefreshSubscription = _messaging.onTokenRefresh.listen((
//         newToken,
//       ) {
//         debugPrint('🔄 Token refreshed: $newToken');
//         _fcmToken = newToken;
//         _registerFCMToken(newToken);
//       });

//       _isInitialized = true;
//       debugPrint('✅ Firebase Messaging initialized');
//     } catch (e) {
//       debugPrint('❌ Error initializing Firebase Messaging: $e');
//     }
//   }

//   /// Dispose listeners
//   void dispose() {
//     _onMessageSubscription?.cancel();
//     _onMessageOpenedAppSubscription?.cancel();
//     _onTokenRefreshSubscription?.cancel();
//     _isInitialized = false;
//   }

//   /// Local notification setup
//   Future<void> _initializeLocalNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     const DarwinInitializationSettings initializationSettingsIOS =
//         DarwinInitializationSettings();

//     const InitializationSettings initializationSettings =
//         InitializationSettings(
//           android: initializationSettingsAndroid,
//           iOS: initializationSettingsIOS,
//         );

//     await _localNotifications.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: _onNotificationTapped,
//     );

//     await _createNotificationChannel();
//   }

//   /// Android notification channel
//   Future<void> _createNotificationChannel() async {
//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'high_importance_channel',
//       'High Importance Notifications',
//       description: 'Channel for critical notifications.',
//       importance: Importance.high,
//     );

//     await _localNotifications
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(channel);
//   }

//   /// On notification tap
//   void _onNotificationTapped(NotificationResponse response) {
//     debugPrint('📲 Notification tapped: ${response.payload}');

//     // Parse payload and navigate appropriately
//     if (response.payload != null && response.payload!.isNotEmpty) {
//       try {
//         // The payload is the message.data converted to string
//         // Extract navigation info if present
//         debugPrint(
//           '📲 Notification payload for navigation: ${response.payload}',
//         );
//         // Navigation will be handled by the app's routing logic
//         // when it comes to foreground
//       } catch (e) {
//         debugPrint('Error parsing notification payload: $e');
//       }
//     }
//   }

//   /// Foreground message handling
//   void _handleForegroundMessage(RemoteMessage message) {
//     debugPrint('📩 Foreground message: ${message.data}');

//     // Check for incoming call - show CallKit UI even in foreground
//     if (message.data['type'] == 'INCOMING_CALL' ||
//         message.data['type'] == 'incoming_call') {
//       debugPrint('📞 Incoming call notification received in foreground');
//       _showIncomingCall(message.data);
//       return; // Don't show regular notification for calls
//     }

//     if (message.notification != null) {
//       _showLocalNotification(message);

//       NotificationService().createNotificationFromFCM(
//         title: message.notification?.title ?? 'Notification',
//         body: message.notification?.body ?? '',
//         data: message.data,
//         type: message.data['type'] ?? 'general',
//       );
//     } else if (message.data.isNotEmpty) {
//       // Handle data-only messages (like incoming calls)
//       final title = message.data['title'] ?? 'Notification';
//       final body = message.data['body'] ?? '';

//       NotificationService().createNotificationFromFCM(
//         title: title,
//         body: body,
//         data: message.data,
//         type: message.data['type'] ?? 'general',
//       );
//     }
//   }

//   /// Show incoming call via CallKit
//   Future<void> _showIncomingCall(Map<String, dynamic> data) async {
//     try {
//       final callerName =
//           data['caller_name'] ?? data['title'] ?? 'Incoming Call';
//       final callerId = data['caller_id'] ?? data['request_id'] ?? 'unknown';
//       final callerAvatar = data['caller_avatar'] ?? '';
//       final requestId = data['request_id'];
//       final callType = data['call_type'] ?? 'voice';
//       final interpreterType = data['interpreter_type'] ?? 'general';
//       final medicalSection = data['medical_section'];

//       await CallKitService().showIncomingCall(
//         callerName: callerName,
//         callerId: callerId,
//         callerAvatar: callerAvatar,
//         requestId: requestId,
//         callType: callType,
//         interpreterType: interpreterType,
//         medicalSection: medicalSection,
//       );
//     } catch (e) {
//       debugPrint('Error showing incoming call: $e');
//     }
//   }

//   /// Background message handling
//   void _handleBackgroundMessage(RemoteMessage message) {
//     debugPrint('📩 Background message: ${message.data}');

//     // Check for incoming call
//     if (message.data['type'] == 'INCOMING_CALL' ||
//         message.data['type'] == 'incoming_call') {
//       debugPrint('📞 Incoming call notification opened from background');
//       _showIncomingCall(message.data);
//       return;
//     }

//     if (message.notification != null) {
//       NotificationService().createNotificationFromFCM(
//         title: message.notification?.title ?? 'Notification',
//         body: message.notification?.body ?? '',
//         data: message.data,
//         type: message.data['type'] ?? 'general',
//       );
//     }
//   }

//   /// Show local notification
//   Future<void> _showLocalNotification(RemoteMessage message) async {
//     if (message.notification == null) return;

//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//           'high_importance_channel',
//           'High Importance Notifications',
//           channelDescription: 'Channel for critical notifications.',
//           importance: Importance.high,
//           priority: Priority.high,
//           showWhen: true,
//         );

//     const NotificationDetails platformChannelSpecifics = NotificationDetails(
//       android: androidPlatformChannelSpecifics,
//     );

//     await _localNotifications.show(
//       message.hashCode,
//       message.notification!.title,
//       message.notification!.body,
//       platformChannelSpecifics,
//       payload: message.data.toString(),
//     );
//   }

//   /// Register FCM token in Supabase
//   Future<void> _registerFCMToken(String token) async {
//     try {
//       final user = _client.auth.currentUser;
//       if (user == null) {
//         debugPrint('⚠ User not authenticated, skipping FCM token registration');
//         return;
//       }

//       // Clean up old tokens for this user first
//       await _cleanupOldUserTokens(user.id);

//       await _client.from('fcm_tokens').upsert({
//         'user_id': user.id,
//         'token': token,
//         'created_at': DateTime.now().toIso8601String(),
//       });

//       debugPrint('✅ FCM token registered in Supabase');
//     } catch (e) {
//       debugPrint('❌ Error registering FCM token: $e');
//     }
//   }

//   /// Clean up old tokens for a user
//   Future<void> _cleanupOldUserTokens(String userId) async {
//     try {
//       // Keep only the 3 most recent tokens per user
//       final response = await _client
//           .from('fcm_tokens')
//           .select('id, created_at')
//           .eq('user_id', userId)
//           .order('created_at', ascending: false);

//       if (response.length > 3) {
//         final tokensToDelete =
//             response.skip(3).map((row) => row['id']).toList();

//         await _client
//             .from('fcm_tokens')
//             .delete()
//             .inFilter('id', tokensToDelete);

//         debugPrint(
//           '🧹 Cleaned up ${tokensToDelete.length} old FCM tokens for user',
//         );
//       }
//     } catch (e) {
//       debugPrint('❌ Error cleaning up old user tokens: $e');
//     }
//   }

//   /// Unregister token
//   Future<void> unregisterToken() async {
//     try {
//       final user = _client.auth.currentUser;
//       if (user == null || _fcmToken == null) return;

//       await _client
//           .from('fcm_tokens')
//           .delete()
//           .eq('user_id', user.id)
//           .eq('token', _fcmToken!);

//       debugPrint('🗑 Token removed from Supabase');
//     } catch (e) {
//       debugPrint('❌ Error unregistering token: $e');
//     }
//   }

//   String? get fcmToken => _fcmToken;
//   bool get isInitialized => _isInitialized;
// }
