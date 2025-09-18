import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language.dart';

class LanguageCacheService {
  static const String _languagesKey = 'cached_languages';
  static const String _lastFetchTimeKey = 'languages_last_fetch';
  static const Duration _cacheValidityDuration = Duration(
    hours: 6,
  ); // Reduced from 24 hours to 6 hours

  // Singleton pattern
  static final LanguageCacheService _instance =
      LanguageCacheService._internal();
  factory LanguageCacheService() => _instance;
  LanguageCacheService._internal();

  /// Get cached languages if available and not expired
  Future<List<Language>?> getCachedLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTime = prefs.getInt(_lastFetchTimeKey);

      if (lastFetchTime == null) {
        return null; // No cache exists
      }

      final lastFetch = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);
      final now = DateTime.now();

      if (now.difference(lastFetch) > _cacheValidityDuration) {
        return null; // Cache expired
      }

      final languagesJson = prefs.getString(_languagesKey);
      if (languagesJson != null) {
        final List<dynamic> decoded = jsonDecode(languagesJson);
        return decoded.map((e) => Language.fromJson(e)).toList();
      }
    } catch (e) {
      // If there's any error reading cache, return null to force fresh fetch
      return null;
    }
    return null;
  }

  /// Cache languages with current timestamp
  Future<void> cacheLanguages(List<Language> languages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languagesJson = jsonEncode(
        languages.map((e) => e.toJson()).toList(),
      );
      final now = DateTime.now();

      await prefs.setString(_languagesKey, languagesJson);
      await prefs.setInt(_lastFetchTimeKey, now.millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail if caching fails
    }
  }

  /// Clear cached languages
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languagesKey);
      await prefs.remove(_lastFetchTimeKey);
    } catch (e) {
      // Silently fail if clearing fails
    }
  }

  /// Check if cache is valid
  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTime = prefs.getInt(_lastFetchTimeKey);

      if (lastFetchTime == null) {
        return false;
      }

      final lastFetch = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);
      final now = DateTime.now();

      return now.difference(lastFetch) <= _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }

  /// Force refresh cache by clearing it
  Future<void> forceRefresh() async {
    await clearCache();
  }

  /// Get cache info for debugging
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTime = prefs.getInt(_lastFetchTimeKey);
      final languagesJson = prefs.getString(_languagesKey);

      if (lastFetchTime == null) {
        return {
          'hasCache': false,
          'lastFetch': null,
          'isValid': false,
          'cachedLanguagesCount': 0,
        };
      }

      final lastFetch = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);
      final now = DateTime.now();
      final isValid = now.difference(lastFetch) <= _cacheValidityDuration;

      int cachedCount = 0;
      if (languagesJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(languagesJson);
          cachedCount = decoded.length;
        } catch (e) {
          cachedCount = 0;
        }
      }

      return {
        'hasCache': true,
        'lastFetch': lastFetch.toIso8601String(),
        'isValid': isValid,
        'cachedLanguagesCount': cachedCount,
        'cacheAge': now.difference(lastFetch).inMinutes,
      };
    } catch (e) {
      return {
        'hasCache': false,
        'lastFetch': null,
        'isValid': false,
        'cachedLanguagesCount': 0,
        'error': e.toString(),
      };
    }
  }
}
