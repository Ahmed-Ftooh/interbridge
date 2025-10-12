import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/services/translation_cache_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_translation_view.dart';
import 'package:interbridge/app/di.dart';

class AppStateRestorationService {
  static final AppStateRestorationService _instance =
      AppStateRestorationService._internal();
  factory AppStateRestorationService() => _instance;
  AppStateRestorationService._internal();

  final TranslationCacheService _cacheService =
      instance<TranslationCacheService>();

  /// Check for cached translation and restore if found
  Future<bool> checkAndRestoreTranslation(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        log('No authenticated user, skipping translation restoration');
        return false;
      }

      final cachedTranslation = await _cacheService.getCachedActiveTranslation(
        user.id,
      );
      if (cachedTranslation == null) {
        log('No cached translation found');
        return false;
      }

      log('Found cached translation: ${cachedTranslation.request.id}');
      
      // Show dialog to ask user if they want to continue
      final shouldRestore = await _showRestoreDialog(
        context,
        cachedTranslation.request,
      );

      if (shouldRestore == true) {
        await _restoreTranslationScreen(context, cachedTranslation);
        return true;
      } else {
        // User chose not to restore, clear the cache
        await _cacheService.clearCache();
        return false;
      }
    } catch (e) {
      log('Error during translation restoration: $e');
      return false;
    }
  }

  /// Show dialog asking user if they want to continue previous translation
  Future<bool?> _showRestoreDialog(
    BuildContext context,
    DocumentTranslationRequest request,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restore, color: Colors.blue),
              SizedBox(width: 8),
              Text('Continue Translation?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You have an unfinished translation session:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.fromLanguage} → ${request.toLanguage}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (request.specialization != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Specialization: ${request.specialization}',
                        style: TextStyle(color: Colors.blue[700], fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Started: ${_formatDateTime(request.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Would you like to continue where you left off?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Start Fresh',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /// Restore the translation screen with cached data
  Future<void> _restoreTranslationScreen(
    BuildContext context,
    CachedTranslation cachedTranslation,
  ) async {
    // Navigate to the translation screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => InterpreterTranslationView(
              request: cachedTranslation.request,
              cachedTranslationText: cachedTranslation.translationText,
            ),
      ),
    );
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Clear all cached state (useful for logout)
  Future<void> clearAllCachedState() async {
    await _cacheService.clearCache();
  }
}
