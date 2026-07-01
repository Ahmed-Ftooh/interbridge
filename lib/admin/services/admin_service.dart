import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;
  static const Map<String, String> _adminPortalHeaders = {
    'x-portal-context': 'admin',
  };

  Future<List<dynamic>> listInterpreters({
    String? search,
    int? limit,
    int? offset,
    String? filterStatus, // 'all', 'verified', 'unverified'
    String? filterAccount, // 'all', 'active', 'suspended'
    bool includeEmail = false,
  }) async {
    final res = await _client.functions.invoke(
      'admin-list-interpreters',
      headers: _adminPortalHeaders,
      body: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
        if (filterStatus != null && filterStatus != 'all')
          'status': filterStatus,
        if (filterAccount != null && filterAccount != 'all')
          'account': filterAccount,
        if (includeEmail) 'include_email': true,
      },
    );
    final data = res.data;
    if (data is Map && data['items'] is List) {
      return data['items'] as List<dynamic>;
    }
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getInterpreterDetails(String userId) async {
    final res = await _client.functions.invoke(
      'admin-interpreter-details',
      headers: _adminPortalHeaders,
      body: {'id': userId},
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<String?> getFreshCertificateUrl({
    String? certificateId,
    String? url,
  }) async {
    final res = await _client.functions.invoke(
      'admin-certificate-signed-url',
      headers: _adminPortalHeaders,
      body: {
        if (certificateId != null) 'certificate_id': certificateId,
        if (url != null) 'url': url,
      },
    );
    final data = res.data;
    if (data is Map && data['signed_url'] is String) {
      return data['signed_url'] as String;
    }
    return null;
  }

  Future<void> approveCertificate(String certificateId, {String? note}) async {
    await _client.functions.invoke(
      'admin-certificate-approve',
      headers: _adminPortalHeaders,
      body: {
        'certificate_id': certificateId,
        if (note != null && note.isNotEmpty) 'approve_note': note,
      },
    );
  }

  Future<void> rejectCertificate(String certificateId, {String? note}) async {
    await _client.functions.invoke(
      'admin-certificate-reject',
      headers: _adminPortalHeaders,
      body: {
        'certificate_id': certificateId,
        if (note != null && note.isNotEmpty) 'reject_note': note,
      },
    );
  }

  Future<String?> setInterpreterVerification(
    String userId, {
    required bool verified,
  }) async {
    // Try to update directly if RLS allows admins
    await _client
        .from('interpreter_details')
        .update({'is_verified': verified})
        .eq('user_id', userId);

    if (verified) {
      return _cleanupVoiceSamples(userId);
    }

    return null;
  }

  Future<String?> _cleanupVoiceSamples(String userId) async {
    final errors = <String>[];

    try {
      final rows = await _client
          .from('voice_samples')
          .select('id, storage_path, url')
          .eq('user_id', userId);

      final paths = <String>{};
      for (final row in rows as List) {
        final storagePath = row['storage_path']?.toString();
        if (storagePath != null && storagePath.isNotEmpty) {
          paths.add(storagePath);
          continue;
        }
        final url = row['url']?.toString();
        final extracted = _extractStoragePathFromUrl(url, 'voice_samples');
        if (extracted != null && extracted.isNotEmpty) {
          paths.add(extracted);
        }
      }

      if (paths.isNotEmpty) {
        final list = paths.toList();
        for (var i = 0; i < list.length; i += 100) {
          var end = i + 100;
          if (end > list.length) end = list.length;
          final batch = list.sublist(i, end);
          await _client.storage.from('voice_samples').remove(batch);
        }
      }
    } catch (e) {
      log('Voice samples storage cleanup failed: $e');
      errors.add('storage cleanup failed');
    }

    try {
      await _client.from('voice_samples').delete().eq('user_id', userId);
    } catch (e) {
      log('Voice samples metadata cleanup failed: $e');
      errors.add('metadata cleanup failed');
    }

    if (errors.isEmpty) return null;
    return 'Interpreter verified, but voice samples cleanup failed.';
  }

  String? _extractStoragePathFromUrl(String? url, String bucket) {
    if (url == null || url.isEmpty) return null;
    final pattern = RegExp(
      '(?:/storage/v1)?/object/(?:public|sign)/${RegExp.escape(bucket)}/(.+?)(?:\\?|\$)',
    );
    final match = pattern.firstMatch(url);
    return match?.group(1);
  }

  /// Send a verification-approved email to the interpreter.
  Future<void> sendVerificationEmail({
    required String userId,
    required String interpreterName,
    String? to,
  }) async {
    final response = await _client.functions.invoke(
      'send-verification-email',
      headers: _adminPortalHeaders,
      body: {
        'userId': userId,
        'interpreterName': interpreterName,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );

    final data = response.data;
    if (data is Map && data['success'] == false) {
      final message =
          (data['message'] ?? data['error'] ?? 'Failed to send email')
              .toString();
      throw Exception(message);
    }
  }

  Future<void> updateGovernmentIdStatus(
    String governmentIdId, {
    required String status,
    String? reviewerNotes,
  }) async {
    await _client
        .from('government_ids')
        .update({
          'status': status,
          if (reviewerNotes != null && reviewerNotes.isNotEmpty)
            'reviewer_notes': reviewerNotes,
        })
        .eq('id', governmentIdId);
  }

  Future<Map<String, dynamic>> sendAdminBroadcast({
    required String subject,
    required String message,
    required bool sendEmail,
    required bool sendPush,
  }) async {
    final response = await _client.functions.invoke(
      'admin-broadcast',
      headers: _adminPortalHeaders,
      body: {
        'subject': subject,
        'message': message,
        'sendEmail': sendEmail,
        'sendPush': sendPush,
      },
    );
    if (response.data is Map<String, dynamic>) {
      return response.data;
    }
    return {};
  }
}
