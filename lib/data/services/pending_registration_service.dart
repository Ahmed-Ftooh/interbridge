import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/data/services/onesignal_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingRegistrationService {
  PendingRegistrationService._();
  static final PendingRegistrationService _instance =
      PendingRegistrationService._();
  factory PendingRegistrationService() => _instance;

  final AppPreferences _preferences = GetIt.I<AppPreferences>();
  final SupabaseService _supabaseService = GetIt.I<SupabaseService>();
  final OneSignalService _oneSignalService = GetIt.I<OneSignalService>();

  /// The in-flight finalization future, if one is running.
  /// Subsequent callers will await the same future instead of being
  /// rejected, preventing race conditions between AppInitializer and
  /// LoginViewWeb on web.
  Future<bool>? _activeFuture;

  /// Exposes the last human-readable error from finalization so the UI can
  /// surface it (e.g. "Organization email already taken").
  String? lastError;

  bool get hasPendingRegistration =>
      _preferences.getPendingRegistration()?.isNotEmpty ?? false;

  Future<bool> finalizePendingRegistration({
    bool refreshSession = false,
  }) async {
    // If already processing, await the in-flight operation so the caller
    // waits for finalization to actually complete before navigating.
    if (_activeFuture != null) {
      log('finalizePendingRegistration: already in progress — awaiting');
      return _activeFuture!;
    }

    final pendingJson = _preferences.getPendingRegistration();
    if (pendingJson == null || pendingJson.isEmpty) {
      return false;
    }

    _activeFuture = _doFinalize(pendingJson, refreshSession);
    try {
      return await _activeFuture!;
    } finally {
      _activeFuture = null;
    }
  }

  Future<bool> _doFinalize(String pendingJson, bool refreshSession) async {
    lastError = null;
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

      // Initialize OneSignal if not already initialized
      final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
      if (oneSignalAppId != null &&
          oneSignalAppId.isNotEmpty &&
          !_oneSignalService.isInitialized) {
        await _oneSignalService.initialize(oneSignalAppId);
      }
      // Refresh player ID to ensure it's registered
      await _oneSignalService.refreshPlayerId();
      return true;
    } catch (e, stackTrace) {
      log(
        'Pending registration finalization failed: $e',
        stackTrace: stackTrace,
      );
      // If the org email is a duplicate clear the stale pending data so the
      // user is not stuck in an infinite retry loop and can re-register.
      if (e.toString().contains('Organization email already exists') ||
          e.toString().contains('organizations_email_key')) {
        lastError =
            'An organization with that email is already registered. '
            'Please register again with a different organization email.';
        await _preferences.clearPendingRegistration();
      }
      return false;
    }
  }
}
