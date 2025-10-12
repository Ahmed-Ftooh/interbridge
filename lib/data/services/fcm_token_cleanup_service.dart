import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

class FCMTokenCleanupService {
  static final FCMTokenCleanupService _instance =
      FCMTokenCleanupService._internal();
  factory FCMTokenCleanupService() => _instance;
  FCMTokenCleanupService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Clean up invalid FCM tokens from the database
  Future<void> cleanupInvalidTokens(List<String> invalidTokens) async {
    try {
      if (invalidTokens.isEmpty) return;

      log('Cleaning up ${invalidTokens.length} invalid FCM tokens');

      // Delete invalid tokens from database
      await _client
          .from('fcm_tokens')
          .delete()
          .inFilter('token', invalidTokens);

      log('Successfully cleaned up invalid FCM tokens');
    } catch (e) {
      log('Error cleaning up invalid FCM tokens: $e');
    }
  }

  /// Clean up old FCM tokens (older than 30 days)
  Future<void> cleanupOldTokens() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      log('Cleaning up FCM tokens older than 30 days');

      await _client
          .from('fcm_tokens')
          .delete()
          .lt('created_at', thirtyDaysAgo.toIso8601String());

      log('Successfully cleaned up old FCM tokens');
    } catch (e) {
      log('Error cleaning up old FCM tokens: $e');
    }
  }

  /// Clean up tokens for a specific user
  Future<void> cleanupUserTokens(String userId) async {
    try {
      log('Cleaning up FCM tokens for user: $userId');

      await _client.from('fcm_tokens').delete().eq('user_id', userId);

      log('Successfully cleaned up FCM tokens for user');
    } catch (e) {
      log('Error cleaning up user FCM tokens: $e');
    }
  }

  /// Get all FCM tokens for a user
  Future<List<String>> getUserTokens(String userId) async {
    try {
      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', userId);

      return response
          .map((row) => row['token'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
    } catch (e) {
      log('Error getting user FCM tokens: $e');
      return [];
    }
  }

  /// Validate FCM token format
  bool isValidTokenFormat(String token) {
    // FCM tokens are typically 163 characters long and contain alphanumeric characters
    return token.length >= 100 &&
        token.length <= 200 &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token);
  }

  /// Clean up tokens with invalid format
  Future<void> cleanupInvalidFormatTokens() async {
    try {
      log('Cleaning up FCM tokens with invalid format');

      // Get all tokens
      final response = await _client
          .from('fcm_tokens')
          .select('token, user_id');

      final invalidTokens = <String>[];

      for (final row in response) {
        final token = row['token'] as String;
        if (!isValidTokenFormat(token)) {
          invalidTokens.add(token);
        }
      }

      if (invalidTokens.isNotEmpty) {
        await cleanupInvalidTokens(invalidTokens);
        log('Cleaned up ${invalidTokens.length} tokens with invalid format');
      }
    } catch (e) {
      log('Error cleaning up invalid format tokens: $e');
    }
  }

  /// Get token statistics
  Future<Map<String, dynamic>> getTokenStatistics() async {
    try {
      final response = await _client
          .from('fcm_tokens')
          .select('user_id, created_at');

      final totalTokens = response.length;
      final uniqueUsers =
          response.map((row) => row['user_id'] as String).toSet().length;

      // Count tokens by age
      final now = DateTime.now();
      final recentTokens =
          response.where((row) {
            final createdAt = DateTime.parse(row['created_at'] as String);
            return now.difference(createdAt).inDays <= 7;
          }).length;

      return {
        'total_tokens': totalTokens,
        'unique_users': uniqueUsers,
        'recent_tokens': recentTokens,
        'old_tokens': totalTokens - recentTokens,
      };
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
