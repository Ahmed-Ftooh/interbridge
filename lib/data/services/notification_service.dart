import 'dart:convert';
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/notification_model.dart';
import 'package:interbridge/data/services/fcm_token_cleanup_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Save a notification to the database
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      await _client.from('notifications').insert({
        'user_id': user.id,
        'title': notification.title,
        'body': notification.body,
        'data': notification.data,
        'timestamp': notification.timestamp.toIso8601String(),
        'is_read': notification.isRead,
        'type': notification.type,
      });
    } catch (e) {
      log('Error saving notification: $e');
      rethrow;
    }
  }

  /// Get all notifications for the current user
  Future<List<NotificationModel>> getUserNotifications() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('timestamp', ascending: false);

      return response.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      log('Error getting notifications: $e');
      return [];
    }
  }

  /// Test notification via Edge Function
  Future<bool> testNotificationSystem() async {
    try {
      log('DEBUG: Testing notification system...');

      final user = _client.auth.currentUser;
      if (user == null) {
        log('DEBUG: No authenticated user found');
        return false;
      }

      // Get tokens from DB
      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', user.id);

      final tokens =
          response
              .map((t) => t['token'] as String?)
              .where((t) => t != null && t.isNotEmpty)
              .toList();

      log('DEBUG: Found ${tokens.length} FCM tokens for current user');

      if (tokens.isEmpty) {
        log('DEBUG: No FCM tokens found for current user');
        return false;
      }

      // Build request body
      final notificationData = {
        'title': 'Test Notification',
        'body': 'This is a test notification to verify the system.',
        'data': {
          'test': 'true',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'test',
        },
        'tokens': tokens,
      };

      log('DEBUG: Sending notification with: $notificationData');

      // IMPORTANT: Ensure JSON body and proper headers
      final edgeResponse = await _client.functions.invoke(
        'send-notification',
        body: jsonEncode(notificationData),
        headers: {'Content-Type': 'application/json'},
      );

      log('DEBUG: Edge function status: ${edgeResponse.status}');
      log('DEBUG: Edge function data: ${edgeResponse.data}');

      if (edgeResponse.status == 200) {
        await createNotificationFromFCM(
          title: 'Test Notification',
          body: 'This is a test notification to verify the system.',
          data: {
            'test': 'true',
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'test',
          },
          type: 'test',
        );
        return true;
      } else {
        log('DEBUG: Notification failed: ${edgeResponse.data}');
        return false;
      }
    } catch (e, st) {
      log('Error testing notification system: $e\n$st');
      return false;
    }
  }

  Future<void> createNotificationFromFCM({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String type,
  }) async {
    try {
      final uuid = '${DateTime.now().millisecondsSinceEpoch}_fcm';
      final notification = NotificationModel(
        id: uuid,
        title: title,
        body: body,
        data: data,
        timestamp: DateTime.now(),
        type: type,
      );
      await saveNotification(notification);
    } catch (e) {
      log('Error creating notification from FCM: $e');
    }
  }

  /// Clean up invalid FCM tokens
  Future<void> cleanupInvalidTokens() async {
    try {
      log('Starting FCM token cleanup...');

      final cleanupService = FCMTokenCleanupService();

      // Clean up old tokens (older than 30 days)
      await cleanupService.cleanupOldTokens();

      // Clean up tokens with invalid format
      await cleanupService.cleanupInvalidFormatTokens();

      // Get statistics
      final stats = await cleanupService.getTokenStatistics();
      log('FCM token cleanup completed. Stats: $stats');
    } catch (e) {
      log('Error during FCM token cleanup: $e');
    }
  }

  /// Get FCM token statistics
  Future<Map<String, dynamic>> getTokenStatistics() async {
    try {
      final cleanupService = FCMTokenCleanupService();
      return await cleanupService.getTokenStatistics();
    } catch (e) {
      log('Error getting token statistics: $e');
      return {
        'total_tokens': 0,
        'unique_users': 0,
        'recent_tokens': 0,
        'old_tokens': 0,
      };
    }
  }
}
