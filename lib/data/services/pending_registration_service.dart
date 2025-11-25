import 'dart:convert';
import 'dart:developer';

import 'package:get_it/get_it.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/data/services/firebase_messaging_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingRegistrationService {
  PendingRegistrationService._();
  static final PendingRegistrationService _instance =
      PendingRegistrationService._();
  factory PendingRegistrationService() => _instance;

  final AppPreferences _preferences = GetIt.I<AppPreferences>();
  final SupabaseService _supabaseService = GetIt.I<SupabaseService>();
  final FirebaseMessagingService _messagingService =
      GetIt.I<FirebaseMessagingService>();

  bool _isProcessing = false;

  bool get hasPendingRegistration =>
      _preferences.getPendingRegistration()?.isNotEmpty ?? false;

  Future<bool> finalizePendingRegistration({
    bool refreshSession = false,
  }) async {
    if (_isProcessing) return false;

    final pendingJson = _preferences.getPendingRegistration();
    if (pendingJson == null || pendingJson.isEmpty) {
      return false;
    }

    _isProcessing = true;
    try {
      if (refreshSession) {
        await Supabase.instance.client.auth.refreshSession();
      }

      final userResponse = await Supabase.instance.client.auth.getUser();
      final user = userResponse.user;
      if (user == null || user.emailConfirmedAt == null) {
        return false;
      }

      final payload = jsonDecode(pendingJson) as Map<String, dynamic>;
      await _supabaseService.finalizePendingRegistrationData(payload, user.id);

      await _preferences.clearPendingRegistration();
      await _preferences.setLoginViewed();
      await _messagingService.initialize();
      return true;
    } catch (e, stackTrace) {
      log(
        'Pending registration finalization failed: $e',
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _isProcessing = false;
    }
  }
}
