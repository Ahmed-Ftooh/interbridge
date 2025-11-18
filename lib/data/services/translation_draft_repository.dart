import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

class DraftData {
  final String requestId;
  final String interpreterId;
  final String? draftText;
  final String? draftFileUrl;
  final DateTime? autosavedAt;

  DraftData({
    required this.requestId,
    required this.interpreterId,
    this.draftText,
    this.draftFileUrl,
    this.autosavedAt,
  });

  factory DraftData.fromMap(Map<String, dynamic> map) {
    return DraftData(
      requestId: map['request_id'] as String,
      interpreterId: map['interpreter_id'] as String,
      draftText: map['draft_text'] as String?,
      draftFileUrl: map['draft_file_url'] as String?,
      autosavedAt:
          map['autosaved_at'] != null
              ? DateTime.tryParse(map['autosaved_at'] as String)
              : null,
    );
  }
}

class TranslationDraftRepository {
  final SupabaseClient _client;
  TranslationDraftRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _table = 'translation_drafts';

  Future<DraftData?> getDraft({
    required String requestId,
    required String interpreterId,
  }) async {
    try {
      final res =
          await _client.from(_table).select().match({
            'request_id': requestId,
            'interpreter_id': interpreterId,
          }).maybeSingle();

      if (res == null) return null;
      return DraftData.fromMap(res);
    } catch (e) {
      log('getDraft error: $e');
      return null;
    }
  }

  Future<void> upsertDraft({
    required String requestId,
    required String interpreterId,
    String? draftText,
    String? draftFileUrl,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      await _client.from(_table).upsert({
        'request_id': requestId,
        'interpreter_id': interpreterId,
        'draft_text': draftText,
        'draft_file_url': draftFileUrl,
        'autosaved_at': nowIso,
      }, onConflict: 'request_id,interpreter_id');
    } catch (e) {
      log('upsertDraft error: $e');
      rethrow;
    }
  }

  Future<void> clearDraft({
    required String requestId,
    required String interpreterId,
  }) async {
    try {
      await _client.from(_table).delete().match({
        'request_id': requestId,
        'interpreter_id': interpreterId,
      });
    } catch (e) {
      log('clearDraft error: $e');
      rethrow;
    }
  }
}
