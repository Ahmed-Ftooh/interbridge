import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/presentation/screens/interpreter/incoming_call_screen.dart';
import 'package:interbridge/presentation/screens/interpreter/incoming_call_web_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to listen for incoming call requests and show ringing screen
class IncomingCallService {
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  RealtimeChannel? _subscription;
  bool _isListening = false;
  final Set<String> _shownRequestIds = {};
  Set<String> _declinedRequestIds = {};
  bool _isShowingIncomingCall = false;
  List<String>? _interpreterLanguageIds;
  String _employmentType = 'volunteer';
  Timer? _periodicResyncTimer;

  /// Start listening for incoming calls for the interpreter.
  /// Set [skipOnlineCheck] to true when the caller has already ensured
  /// the interpreter is online (e.g. right after writing is_online=true to DB)
  /// to avoid a race-condition stale read.
  Future<void> startListening({bool skipOnlineCheck = false}) async {
    if (_isListening) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      log('IncomingCallService: User not authenticated');
      return;
    }

    // Check if interpreter is online before starting to listen
    if (!skipOnlineCheck) {
      final isOnline = await _checkIsOnline(userId);
      if (!isOnline) {
        log(
          'IncomingCallService: Interpreter is offline, not listening for calls',
        );
        return;
      }
    } else {
      log('IncomingCallService: Skipping online check (caller verified)');
    }

    // Load interpreter's languages and employment type
    await _loadInterpreterLanguages(userId);
    await _loadEmploymentType(userId);

    if (_interpreterLanguageIds == null || _interpreterLanguageIds!.isEmpty) {
      log('IncomingCallService: No languages found for interpreter');
      return;
    }

    _isListening = true;
    _shownRequestIds.clear();

    // Build a short race-window watermark so we can catch requests created
    // while the realtime channel is still becoming active.
    final startupWatermark = DateTime.now().toUtc().subtract(
      const Duration(seconds: 5),
    );

    // First, load current pending requests.
    await _checkExistingPendingRequests(limit: 10);

    // Subscribe to new interpreter requests
    _subscription =
        Supabase.instance.client
            .channel('incoming_calls_$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'interpreter_requests',
              callback: (payload) async {
                log('IncomingCallService: New request detected');
                await _handleNewRequest(payload.newRecord);
              },
            )
            .subscribe();

    log('IncomingCallService: Started listening for incoming calls');

    // Then run a bounded catch-up query to close the startup race window.
    await Future.delayed(const Duration(milliseconds: 250));
    await _checkExistingPendingRequests(
      createdAfter: startupWatermark,
      limit: 10,
    );

    _periodicResyncTimer?.cancel();
    _periodicResyncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isListening || _isShowingIncomingCall) {
        return;
      }
      _checkExistingPendingRequests(limit: 5);
    });
  }

  /// Stop listening for incoming calls
  void stopListening() {
    if (_subscription != null) {
      // removeChannel() fully tears down the channel so a fresh one
      // is created next time startListening() is called.  Plain
      // unsubscribe() leaves a stale object in the Supabase client
      // cache, which prevents reconnection.
      try {
        Supabase.instance.client.removeChannel(_subscription!);
      } catch (_) {
        // Fallback: at least unsubscribe
        _subscription?.unsubscribe();
      }
      _subscription = null;
    }
    _isListening = false;
    _isShowingIncomingCall = false;
    _periodicResyncTimer?.cancel();
    _periodicResyncTimer = null;
    _shownRequestIds.clear();
    _declinedRequestIds.clear();
    log('IncomingCallService: Stopped listening');
  }

  Future<void> _loadInterpreterLanguages(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('interpreter_languages')
          .select('language_id')
          .eq('user_id', userId);

      _interpreterLanguageIds =
          response.map((row) => row['language_id'].toString()).toList();

      log(
        'IncomingCallService: Loaded ${_interpreterLanguageIds!.length} languages',
      );
    } catch (e) {
      log('IncomingCallService: Error loading languages: $e');
      _interpreterLanguageIds = [];
    }
  }

  /// Load the interpreter's employment type to filter by interpreter_type
  Future<void> _loadEmploymentType(String userId) async {
    try {
      final response =
          await Supabase.instance.client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();

      _employmentType =
          (response?['employment_type'] as String?) ?? 'volunteer';
      log('IncomingCallService: employment_type=$_employmentType');
    } catch (e) {
      log('IncomingCallService: Error loading employment_type: $e');
      _employmentType = 'volunteer';
    }
  }

  /// Check if interpreter is currently online
  Future<bool> _checkIsOnline(String userId) async {
    try {
      final response =
          await Supabase.instance.client
              .from('interpreter_details')
              .select('is_online')
              .eq('user_id', userId)
              .maybeSingle();

      return response?['is_online'] == true;
    } catch (e) {
      log('IncomingCallService: Error checking online status: $e');
      return false;
    }
  }

  Future<void> _checkExistingPendingRequests({
    DateTime? createdAfter,
    int limit = 10,
  }) async {
    if (_interpreterLanguageIds == null || _interpreterLanguageIds!.isEmpty) {
      return;
    }

    try {
      // Get declined jobs for this interpreter
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      Set<String> declinedJobIds = {};
      try {
        final declinedRows = await Supabase.instance.client
            .from('interpreter_declined_jobs')
            .select('request_id')
            .eq('interpreter_id', userId);
        declinedJobIds =
            declinedRows
                .map((row) => row['request_id']?.toString())
                .whereType<String>()
                .toSet();
        _declinedRequestIds = declinedJobIds;
      } catch (e) {
        log('IncomingCallService: Could not fetch declined jobs: $e');
      }

      // Fetch pending requests matching interpreter's languages AND type
      // Paid interpreters can handle both general and specialist requests.
      // Volunteers only handle general requests.
      var query = Supabase.instance.client
          .from('interpreter_requests')
          .select('*')
          .eq('status', 'pending')
          .inFilter('from_language', _interpreterLanguageIds!)
          .inFilter('to_language', _interpreterLanguageIds!);

      if (_employmentType != 'paid') {
        query = query.eq('interpreter_type', 'general');
      }

      if (createdAfter != null) {
        query = query.gte('created_at', createdAfter.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      for (final row in response) {
        await _handleNewRequest(row);

        // Show only one incoming screen at a time.
        if (_isShowingIncomingCall) {
          break;
        }
      }
    } catch (e) {
      log('IncomingCallService: Error checking pending requests: $e');
    }
  }

  Future<void> _handleNewRequest(Map<String, dynamic> record) async {
    try {
      final request = InterpreterRequest.fromJson(record);

      // Skip if not pending
      if (request.status != 'pending') {
        log(
          'IncomingCallService: Request status is ${request.status}, skipping',
        );
        return;
      }

      // Skip if already shown
      if (_shownRequestIds.contains(request.id)) {
        log('IncomingCallService: Already shown request ${request.id}');
        return;
      }

      // Skip if already declined
      if (_declinedRequestIds.contains(request.id)) {
        log('IncomingCallService: Already declined request ${request.id}');
        return;
      }

      // Note: We don't re-check online status here.
      // If startListening() was called, the interpreter was verified online.
      // Re-querying the DB can return stale data and block valid calls.

      // Check if this request matches interpreter's languages (BOTH directions)
      if (_interpreterLanguageIds == null ||
          !_interpreterLanguageIds!.contains(request.fromLanguage) ||
          !_interpreterLanguageIds!.contains(request.toLanguage)) {
        log(
          'IncomingCallService: Request languages '
          '(from=${request.fromLanguage}, to=${request.toLanguage}) '
          'do not match interpreter languages $_interpreterLanguageIds',
        );
        return;
      }

      // Check if request type matches interpreter's employment type:
      // volunteer → general only
      // paid      → general AND specialist
      final requestType = (record['interpreter_type'] as String?) ?? 'general';
      if (_employmentType != 'paid' && requestType != 'general') {
        log(
          'IncomingCallService: Request type "$requestType" '
          'not allowed for volunteer interpreter',
        );
        return;
      }

      log(
        'IncomingCallService: Showing incoming call for request: ${request.id}',
      );
      await _showIncomingCallScreen(request);
    } catch (e) {
      log('IncomingCallService: Error handling new request: $e');
    }
  }

  Future<void> _showIncomingCallScreen(InterpreterRequest request) async {
    final navigator = MyApp.navigatorKey.currentState;
    if (navigator == null || !_isListening) {
      log('IncomingCallService: No navigator or not listening, skipping');
      return;
    }

    // Prevent showing multiple incoming call screens
    if (_isShowingIncomingCall) {
      log('IncomingCallService: Already showing an incoming call');
      return;
    }

    _shownRequestIds.add(request.id);
    _isShowingIncomingCall = true;

    // Get language names
    String fromLanguageName = 'Unknown';
    String toLanguageName = 'Unknown';

    try {
      final jobService = InterpreterJobService();
      final fromName = await jobService.findLanguageById(request.fromLanguage);
      final toName = await jobService.findLanguageById(request.toLanguage);

      if (fromName != null) fromLanguageName = fromName;
      if (toName != null) toLanguageName = toName;
    } catch (e) {
      log('IncomingCallService: Error fetching language names: $e');
    }

    try {
      // Navigate to incoming call screen (web or mobile)
      final Widget incomingScreen =
          kIsWeb
              ? IncomingCallWebScreen(
                request: request,
                fromLanguageName: fromLanguageName,
                toLanguageName: toLanguageName,
              )
              : IncomingCallScreen(
                request: request,
                fromLanguageName: fromLanguageName,
                toLanguageName: toLanguageName,
              );

      await navigator.push(
        PageRouteBuilder(
          opaque: !kIsWeb, // Transparent overlay on web
          pageBuilder: (_, __, ___) => incomingScreen,
          transitionsBuilder: (_, animation, __, child) {
            if (kIsWeb) {
              // Fade in on web
              return FadeTransition(opacity: animation, child: child);
            }
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      log('IncomingCallService: Error showing incoming call screen: $e');
    } finally {
      _isShowingIncomingCall = false;
    }
  }

  /// Mark a request as declined (so it won't show again)
  void markDeclined(String requestId) {
    _declinedRequestIds.add(requestId);
  }

  /// Feed manually refreshed jobs into the same incoming call pipeline so
  /// refresh cannot surface cards without triggering incoming call behavior.
  Future<void> syncFromAvailableJobs(List<InterpreterRequest> jobs) async {
    if (!_isListening || _isShowingIncomingCall || jobs.isEmpty) {
      return;
    }

    for (final request in jobs) {
      if (request.status != 'pending') {
        continue;
      }
      if (_shownRequestIds.contains(request.id) ||
          _declinedRequestIds.contains(request.id)) {
        continue;
      }

      log(
        'IncomingCallService: Syncing refreshed request into incoming flow: ${request.id}',
      );
      await _showIncomingCallScreen(request);
      break;
    }
  }

  bool get isListening => _isListening;
}
