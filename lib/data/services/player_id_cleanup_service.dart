import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for cleaning up invalid or old OneSignal player IDs from the database
class PlayerIdCleanupService {
  static final PlayerIdCleanupService _instance =
      PlayerIdCleanupService._internal();
  factory PlayerIdCleanupService() => _instance;
  PlayerIdCleanupService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Clean up invalid player IDs from the database
  Future<void> cleanupInvalidPlayerIds(List<String> invalidPlayerIds) async {
    try {
      if (invalidPlayerIds.isEmpty) return;

      log(
        'Cleaning up ${invalidPlayerIds.length} invalid OneSignal player IDs',
      );

      // Delete invalid player IDs from database
      await _client
          .from('onesignal_player_ids')
          .delete()
          .inFilter('player_id', invalidPlayerIds);

      log('Successfully cleaned up invalid OneSignal player IDs');
    } catch (e) {
      log('Error cleaning up invalid OneSignal player IDs: $e');
    }
  }

  /// Clean up old player IDs (older than 30 days)
  Future<void> cleanupOldPlayerIds() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      log('Cleaning up OneSignal player IDs older than 30 days');

      await _client
          .from('onesignal_player_ids')
          .delete()
          .lt('created_at', thirtyDaysAgo.toIso8601String());

      log('Successfully cleaned up old OneSignal player IDs');
    } catch (e) {
      log('Error cleaning up old OneSignal player IDs: $e');
    }
  }

  /// Clean up player IDs for a specific user
  Future<void> cleanupUserPlayerIds(String userId) async {
    try {
      log('Cleaning up OneSignal player IDs for user: $userId');

      await _client.from('onesignal_player_ids').delete().eq('user_id', userId);

      log('Successfully cleaned up OneSignal player IDs for user');
    } catch (e) {
      log('Error cleaning up user OneSignal player IDs: $e');
    }
  }

  /// Get all player IDs for a user
  Future<List<String>> getUserPlayerIds(String userId) async {
    try {
      final response = await _client
          .from('onesignal_player_ids')
          .select('player_id')
          .eq('user_id', userId);

      return response
          .map((row) => row['player_id'] as String)
          .where((playerId) => playerId.isNotEmpty)
          .toList();
    } catch (e) {
      log('Error getting user OneSignal player IDs: $e');
      return [];
    }
  }

  /// Validate OneSignal player ID format
  /// OneSignal player IDs are UUIDs (36 characters with dashes)
  bool isValidPlayerIdFormat(String playerId) {
    // OneSignal player IDs are UUIDs like: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(playerId);
  }

  /// Clean up player IDs with invalid format
  Future<void> cleanupInvalidFormatPlayerIds() async {
    try {
      log('Cleaning up OneSignal player IDs with invalid format');

      // Get all player IDs
      final response = await _client
          .from('onesignal_player_ids')
          .select('player_id, user_id');

      final invalidPlayerIds = <String>[];

      for (final row in response) {
        final playerId = row['player_id'] as String;
        if (!isValidPlayerIdFormat(playerId)) {
          invalidPlayerIds.add(playerId);
        }
      }

      if (invalidPlayerIds.isNotEmpty) {
        await cleanupInvalidPlayerIds(invalidPlayerIds);
        log(
          'Cleaned up ${invalidPlayerIds.length} player IDs with invalid format',
        );
      }
    } catch (e) {
      log('Error cleaning up invalid format player IDs: $e');
    }
  }

  /// Get player ID statistics
  Future<Map<String, dynamic>> getPlayerIdStatistics() async {
    try {
      final response = await _client
          .from('onesignal_player_ids')
          .select('id, user_id, created_at');

      final totalCount = response.length;
      final uniqueUsers = response.map((r) => r['user_id']).toSet().length;

      // Calculate average player IDs per user
      final avgPerUser = totalCount / (uniqueUsers == 0 ? 1 : uniqueUsers);

      return {
        'total_player_ids': totalCount,
        'unique_users': uniqueUsers,
        'average_per_user': avgPerUser.toStringAsFixed(2),
      };
    } catch (e) {
      log('Error getting player ID statistics: $e');
      return {'error': e.toString()};
    }
  }
}
