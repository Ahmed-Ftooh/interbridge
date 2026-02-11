// import 'package:flutter/material.dart';
// import 'package:interbridge/data/services/session_service.dart';
// import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';
// import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
// import 'dart:developer';

// class AppLifecycleService {
//   static bool _isInitialized = false;

//   /// Initialize the app lifecycle service
//   static void initialize() {
//     if (_isInitialized) return;
//     _isInitialized = true;
//     log('App lifecycle service initialized');
//   }

//   /// Check for active session and restore if needed
//   static Future<Widget?> checkAndRestoreSession(BuildContext context) async {
//     try {
//       final session = await SessionService.getSession();

//       if (session == null) {
//         log('No active session found');
//         return null;
//       }

//       final requestId = session['requestId'] as String;
//       final requesterId = session['requesterId'] as String;
//       final interpreterId = session['interpreterId'] as String;
//       final currentScreen = session['currentScreen'] as String?;

//       log('Found active session: $currentScreen for request: $requestId');

//       switch (currentScreen) {
//         case 'chat':
//           return ChatView(
//             requestId: requestId,
//             requesterId: requesterId,
//             interpreterId: interpreterId,
//           );
//         case 'call':
//           return EnhancedCallScreen(channelId: requestId);
//         default:
//           log('Unknown screen type: $currentScreen');
//           return null;
//       }
//     } catch (e) {
//       log('Error restoring session: $e');
//       return null;
//     }
//   }

//   /// Handle app lifecycle changes
//   static void handleAppLifecycleState(AppLifecycleState state) {
//     switch (state) {
//       case AppLifecycleState.resumed:
//         log('App resumed - checking for active session');
//         break;
//       case AppLifecycleState.paused:
//         log('App paused - session state preserved');
//         break;
//       case AppLifecycleState.inactive:
//         log('App inactive - session state preserved');
//         break;
//       case AppLifecycleState.detached:
//         log('App detached - session state preserved');
//         break;
//       case AppLifecycleState.hidden:
//         log('App hidden - session state preserved');
//         break;
//     }
//   }

//   /// Clear session when app is terminated
//   static Future<void> clearSessionOnTerminate() async {
//     await SessionService.clearSession();
//     log('Session cleared on app terminate');
//   }
// }
