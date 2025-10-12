import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_translation_request.dart';

class TranslationCacheService {
  static const String _activeTranslationKey = 'active_translation_request';
  static const String _translationTextKey = 'translation_text';
  static const String _cacheTimestampKey = 'translation_cache_timestamp';
  static const String _userIdKey = 'cached_user_id';

  // Cache validity duration - 24 hours
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  // Singleton pattern
  static final TranslationCacheService _instance =
      TranslationCacheService._internal();
  factory TranslationCacheService() => _instance;
  TranslationCacheService._internal();

  /// Cache the active translation request and current user ID
  Future<void> cacheActiveTranslation({
    required DocumentTranslationRequest request,
    required String currentUserId,
    String? currentTranslationText,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store the request data
      final requestJson = jsonEncode(request.toJson());
      await prefs.setString(_activeTranslationKey, requestJson);

      // Store the user ID to ensure it's the same user
      await prefs.setString(_userIdKey, currentUserId);

      // Store the current translation text if provided
      if (currentTranslationText != null && currentTranslationText.isNotEmpty) {
        await prefs.setString(_translationTextKey, currentTranslationText);
      }

      // Store timestamp
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      log('Translation cache saved: ${request.id}');
    } catch (e) {
      log('Error caching translation: $e');
    }
  }

  /// Get cached active translation request if valid
  Future<CachedTranslation?> getCachedActiveTranslation(
    String currentUserId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user ID matches
      final cachedUserId = prefs.getString(_userIdKey);
      if (cachedUserId != currentUserId) {
        log('Cached translation belongs to different user, clearing cache');
        await clearCache();
        return null;
      }

      // Check if cache is still valid
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);
      if (cacheTimestamp == null) {
        return null; // No cache exists
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
      final now = DateTime.now();

      if (now.difference(cacheTime) > _cacheValidityDuration) {
        log('Translation cache expired, clearing cache');
        await clearCache();
        return null;
      }

      // Get cached request
      final requestJson = prefs.getString(_activeTranslationKey);
      if (requestJson == null) {
        return null;
      }

      final requestData = jsonDecode(requestJson) as Map<String, dynamic>;
      final request = DocumentTranslationRequest.fromJson(requestData);

      // Get cached translation text
      final cachedText = prefs.getString(_translationTextKey);

      return CachedTranslation(
        request: request,
        translationText: cachedText,
        cachedAt: cacheTime,
      );
    } catch (e) {
      log('Error reading cached translation: $e');
      return null;
    }
  }

  /// Update only the translation text in cache
  Future<void> updateTranslationText(String translationText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_translationTextKey, translationText);
    } catch (e) {
      log('Error updating translation text in cache: $e');
    }
  }

  /// Clear all cached translation data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeTranslationKey);
      await prefs.remove(_translationTextKey);
      await prefs.remove(_cacheTimestampKey);
      await prefs.remove(_userIdKey);
      log('Translation cache cleared');
    } catch (e) {
      log('Error clearing translation cache: $e');
    }
  }

  /// Check if there's a valid cached translation
  Future<bool> hasActiveTranslation(String currentUserId) async {
    final cached = await getCachedActiveTranslation(currentUserId);
    return cached != null;
  }

  /// Get cache info for debugging
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);
      final cachedUserId = prefs.getString(_userIdKey);
      final requestJson = prefs.getString(_activeTranslationKey);
      final translationText = prefs.getString(_translationTextKey);

      if (cacheTimestamp == null) {
        return {
          'hasCache': false,
          'cachedAt': null,
          'isValid': false,
          'userId': null,
          'requestId': null,
          'translationLength': 0,
        };
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
      final now = DateTime.now();
      final isValid = now.difference(cacheTime) <= _cacheValidityDuration;

      String? requestId;
      if (requestJson != null) {
        try {
          final requestData = jsonDecode(requestJson) as Map<String, dynamic>;
          requestId = requestData['id'] as String?;
        } catch (e) {
          requestId = null;
        }
      }

      return {
        'hasCache': true,
        'cachedAt': cacheTime.toIso8601String(),
        'isValid': isValid,
        'userId': cachedUserId,
        'requestId': requestId,
        'translationLength': translationText?.length ?? 0,
        'cacheAge': now.difference(cacheTime).inMinutes,
      };
    } catch (e) {
      return {
        'hasCache': false,
        'cachedAt': null,
        'isValid': false,
        'userId': null,
        'requestId': null,
        'translationLength': 0,
        'error': e.toString(),
      };
    }
  }
}

/// Data class to hold cached translation information
class CachedTranslation {
  final DocumentTranslationRequest request;
  final String? translationText;
  final DateTime cachedAt;

  CachedTranslation({
    required this.request,
    this.translationText,
    required this.cachedAt,
  });
}
