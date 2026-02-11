import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/data/services/interpreter_request_service.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'dart:developer';

class RequestWaitingView extends StatefulWidget {
  final String fromLanguageId;
  final String toLanguageId;
  final String? specialization;
  final String urgency;
  final String? description;
  final String callType;
  final String interpreterType; // 'general' or 'specialist'
  final String? medicalSection; // e.g., 'neurology', 'cardiology'

  const RequestWaitingView({
    super.key,
    required this.fromLanguageId,
    required this.toLanguageId,
    required this.specialization,
    required this.urgency,
    this.description,
    this.callType = 'voice',
    this.interpreterType = 'general',
    this.medicalSection,
  });

  @override
  State<RequestWaitingView> createState() => _RequestWaitingViewState();
}

class _RequestWaitingViewState extends State<RequestWaitingView>
    with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  InterpreterRequest? _request;
  bool _isCreating = true;
  Timer? _tierEscalationTimer; // Timer for tier escalation (30s intervals)
  int _currentTier = 1;

  /// Build a stable int UID from the authenticated user UUID
  static int _uidFromUuid(String uuid) {
    if (uuid.isNotEmpty) {
      final hex = uuid.replaceAll('-', '');
      final first8 =
          hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
      return int.tryParse(first8, radix: 16) ?? 1;
    }
    return 1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFlow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRequestStatus();
    }
  }

  Future<void> _startFlow() async {
    try {
      // 1) Create the request with interpreter type and medical section
      final request = await InterpreterRequestService().createRequest(
        fromLanguage: widget.fromLanguageId,
        toLanguage: widget.toLanguageId,
        specialization: widget.specialization,
        urgency: widget.urgency,
        description: widget.description,
        callType: widget.callType,
        interpreterType: widget.interpreterType, // 'general' or 'specialist'
        medicalSection:
            widget.medicalSection, // e.g., 'neurology', 'cardiology'
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _isCreating = false;
      });

      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Save session as 'waiting' - will be cleared when request is accepted
      await SessionService.saveSession(
        requestId: request.id,
        requesterId: currentUserId,
        interpreterId: '', // Empty until accepted
        currentScreen: 'waiting_request',
      );
      log('Session saved for request waiting: ${request.id}');

      // 2) Subscribe to updates for this request (Supabase v2 API)
      _channel =
          _client.channel('rq_${request.id}')
            ..onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'interpreter_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: request.id,
              ),
              callback: (payload) async {
                final newRow = payload.newRecord;
                final status = newRow['status']?.toString();
                if (status == 'accepted') {
                  final interpreterId = newRow['accepted_by'].toString();
                  final requesterId = newRow['requester_id'].toString();

                  // Update session to call BEFORE navigating
                  await SessionService.saveSession(
                    requestId: request.id,
                    requesterId: requesterId,
                    interpreterId: interpreterId,
                    currentScreen: 'call',
                  );
                  log('Session updated to call for request: ${request.id}');

                  if (mounted) {
                    // Navigate to call screen and start the call
                    final isVideoCall = widget.callType == 'video';
                    final myUid = _uidFromUuid(requesterId);

                    // Start the call via CallBloc
                    context.read<CallBloc>().add(
                      StartCall(
                        channelId: request.id,
                        localUid: myUid,
                        isVideoCall: isVideoCall,
                      ),
                    );

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => EnhancedCallScreen(
                              channelId: request.id,
                              isVideoCall: isVideoCall,
                            ),
                      ),
                      (route) => false,
                    );
                  }
                }
              },
            )
            ..subscribe();

      // Start tier escalation timer for specialist requests
      // Every 30 seconds, check if we need to escalate to the next tier
      if (widget.interpreterType == 'specialist') {
        _startTierEscalationTimer(request.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create request: $e')));
      Navigator.of(context).pop();
    }
  }

  /// Start a timer to check tier escalation every 30 seconds
  void _startTierEscalationTimer(String requestId) {
    _tierEscalationTimer?.cancel();
    _tierEscalationTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (!mounted || _request == null) {
        timer.cancel();
        return;
      }

      log(
        'Checking tier escalation for request: $requestId (current tier: $_currentTier)',
      );

      // Only escalate up to tier 2 (badge holders -> quiz passers)
      if (_currentTier >= 2) {
        log('Already at tier 2 (final tier), no more escalation');
        timer.cancel();
        return;
      }

      try {
        final escalated = await InterpreterRequestService()
            .checkAndEscalateTier(requestId);
        if (escalated && mounted) {
          setState(() {
            _currentTier++;
          });
          log('Escalated to tier $_currentTier');
        }
      } catch (e) {
        log('Error during tier escalation: $e');
      }
    });
  }

  @override
  void dispose() {
    _tierEscalationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel?.unsubscribe();
    }
    super.dispose();
  }

  Future<void> _checkRequestStatus() async {
    final currentRequest = _request;
    if (currentRequest == null) return;
    try {
      final response =
          await _client
              .from('interpreter_requests')
              .select('status, accepted_by, requester_id')
              .eq('id', currentRequest.id)
              .maybeSingle();

      if (response == null) return;

      final status = response['status']?.toString();
      if (status != 'accepted') return;

      final interpreterId = response['accepted_by']?.toString();
      final requesterId = response['requester_id']?.toString();
      if (interpreterId == null || requesterId == null) return;

      await SessionService.saveSession(
        requestId: currentRequest.id,
        requesterId: requesterId,
        interpreterId: interpreterId,
        currentScreen: 'call',
      );

      if (!mounted) return;

      // Navigate to call screen and start the call
      final isVideoCall = widget.callType == 'video';
      final myUid = _uidFromUuid(requesterId);

      // Start the call via CallBloc
      context.read<CallBloc>().add(
        StartCall(
          channelId: currentRequest.id,
          localUid: myUid,
          isVideoCall: isVideoCall,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder:
              (_) => EnhancedCallScreen(
                channelId: currentRequest.id,
                isVideoCall: isVideoCall,
              ),
        ),
        (route) => false,
      );
    } catch (e) {
      log('Error checking request status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Lottie.asset(
                    JsonAssets.loading,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppSize.s16),
                Text(
                  _isCreating
                      ? 'Creating your request...'
                      : 'Waiting for an interpreter to accept...'
                          '\nWe\'ll notify you as soon as someone accepts.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: AppSize.s24),
                if (_request != null)
                  Text(
                    'Request ID: ${_request!.id.substring(0, 8)}...'
                    '\nUrgency: ${_request!.urgency}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ColorManager.grey),
                  ),
                const SizedBox(height: AppSize.s24),
                TextButton(
                  onPressed: () async {
                    // Delete the request from database
                    if (_request != null) {
                      try {
                        await InterpreterRequestService().deleteRequest(
                          _request!.id,
                        );
                        log('Request deleted: ${_request!.id}');
                      } catch (e) {
                        log('Error deleting request: $e');
                      }
                    }
                    // Clear session when user cancels
                    await SessionService.clearSession();
                    log('Session cleared - user cancelled request');
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
