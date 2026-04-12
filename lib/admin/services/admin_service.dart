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

  Future<void> setInterpreterVerification(
    String userId, {
    required bool verified,
  }) async {
    // Try to update directly if RLS allows admins
    await _client
        .from('interpreter_details')
        .update({'is_verified': verified})
        .eq('user_id', userId);
  }

  /// Send a verification-approved email to the interpreter.
  Future<void> sendVerificationEmail({
    required String to,
    required String interpreterName,
  }) async {
    await _client.functions.invoke(
      'send-verification-email',
      body: {'to': to, 'interpreterName': interpreterName},
    );
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
}
