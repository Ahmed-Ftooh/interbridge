import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/presentation/screens/interpreter/incoming_call_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to listen for incoming call requests and show ringing screen
class IncomingCallService {
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  RealtimeChannel? _subscription;
  bool _isListening = false;
  Set<String> _shownRequestIds = {};
  Set<String> _declinedRequestIds = {};
  bool _isShowingIncomingCall = false;
  List<String>? _interpreterLanguageIds;

  /// Start listening for incoming calls for the interpreter
  Future<void> startListening() async {
    if (_isListening) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      log('IncomingCallService: User not authenticated');
      return;
    }

    // Load interpreter's languages
    await _loadInterpreterLanguages(userId);

    if (_interpreterLanguageIds == null || _interpreterLanguageIds!.isEmpty) {
      log('IncomingCallService: No languages found for interpreter');
      return;
    }

    _isListening = true;
    _shownRequestIds.clear();

    // Subscribe to new interpreter requests
    _subscription = Supabase.instance.client
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

    // Also check for any existing pending requests
    await _checkExistingPendingRequests();
  }

  /// Stop listening for incoming calls
  void stopListening() {
    _subscription?.unsubscribe();
    _subscription = null;
    _isListening = false;
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
          'IncomingCallService: Loaded ${_interpreterLanguageIds!.length} languages');
    } catch (e) {
      log('IncomingCallService: Error loading languages: $e');
      _interpreterLanguageIds = [];
    }
  }

  Future<void> _checkExistingPendingRequests() async {
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
        declinedJobIds = declinedRows
            .map((row) => row['request_id']?.toString())
            .whereType<String>()
            .toSet();
        _declinedRequestIds = declinedJobIds;
      } catch (e) {
        log('IncomingCallService: Could not fetch declined jobs: $e');
      }

      // Fetch pending requests matching interpreter's languages
      final response = await Supabase.instance.client
          .from('interpreter_requests')
          .select('*')
          .eq('status', 'pending')
          .inFilter('to_language', _interpreterLanguageIds!)
          .order('created_at', ascending: false)
          .limit(1); // Only get most recent pending request

      if (response.isNotEmpty) {
        final request = InterpreterRequest.fromJson(response.first);

        // Skip if already shown or declined
        if (!_shownRequestIds.contains(request.id) &&
            !_declinedRequestIds.contains(request.id)) {
          log('IncomingCallService: Found existing pending request: ${request.id}');
          await _showIncomingCallScreen(request);
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
        log('IncomingCallService: Request status is ${request.status}, skipping');
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

      // Check if this request matches interpreter's languages
      if (_interpreterLanguageIds == null ||
          !_interpreterLanguageIds!.contains(request.toLanguage)) {
        log('IncomingCallService: Request language ${request.toLanguage} does not match interpreter languages');
        return;
      }

      log('IncomingCallService: Showing incoming call for request: ${request.id}');
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
      // Navigate to incoming call screen
      await navigator.push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => IncomingCallScreen(
            request: request,
            fromLanguageName: fromLanguageName,
            toLanguageName: toLanguageName,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
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

  bool get isListening => _isListening;
}