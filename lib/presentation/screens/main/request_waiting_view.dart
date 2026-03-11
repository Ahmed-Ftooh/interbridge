import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view_web.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/data/services/interpreter_request_service.dart';
import 'package:interbridge/data/services/auto_routing_service.dart';
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
  final String interpreterType;
  final String? medicalSection;

  // Auto-routing fields
  final bool useAutoRouting;
  final String? doctorName;
  final String? patientId;
  final String? department;

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
    this.useAutoRouting = false,
    this.doctorName,
    this.patientId,
    this.department,
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
  Timer? _tierEscalationTimer;
  int _currentTier = 1;

  // Auto-routing state
  String _routingPhase =
      'matching'; // matching, matched, overflow, queued, error
  String? _matchedInterpreterName;
  int _queuePosition = 0;
  int _estimatedWaitSeconds = 0;
  Timer? _queuePollTimer;
  Timer? _waitCountdownTimer;

  // Guard: only the first accepted-status path (realtime OR poll) fires
  // StartCall. Prevents double-dispatch that would tear down the Agora engine
  // mid-join if both code paths race to dispatch StartCall simultaneously.
  bool _callStarted = false;

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
    if (widget.useAutoRouting) {
      _startAutoRouteFlow();
    } else {
      _startFlow();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRequestStatus();
    }
  }

  /// Auto-routing flow: create request + call auto-route edge function
  Future<void> _startAutoRouteFlow() async {
    try {
      final result = await AutoRoutingService().createAndRoute(
        fromLanguage: widget.fromLanguageId,
        toLanguage: widget.toLanguageId,
        specialization: widget.specialization,
        callType: widget.callType,
        doctorName: widget.doctorName,
        patientId: widget.patientId,
        department: widget.department,
        interpreterType: widget.interpreterType,
        medicalSection: widget.medicalSection,
      );

      if (!mounted) return;

      // Create a minimal InterpreterRequest for session tracking
      _request = InterpreterRequest(
        id: result.requestId,
        requesterId: _client.auth.currentUser?.id ?? '',
        fromLanguage: widget.fromLanguageId,
        toLanguage: widget.toLanguageId,
        specialization: widget.specialization,
        urgency: widget.urgency,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      setState(() => _isCreating = false);

      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Save session
      await SessionService.saveSession(
        requestId: result.requestId,
        requesterId: currentUserId,
        interpreterId: '',
        currentScreen: 'waiting_request',
      );

      // Subscribe to realtime updates (catches auto-accept from edge function)
      _subscribeToRequest(result.requestId);

      // Handle routing result
      switch (result.status) {
        case AutoRouteStatus.matched:
        case AutoRouteStatus.overflow:
          setState(() {
            _routingPhase = result.isOverflow ? 'overflow' : 'matched';
            _matchedInterpreterName = result.interpreterName;
          });
          log('Auto-routed: ${result.status} → ${result.interpreterName}');
          // The edge function already auto-accepted. The realtime notification
          // may have fired BEFORE _subscribeToRequest was established (race
          // condition), so poll immediately to catch missed updates.
          await _checkRequestStatus();
          break;

        case AutoRouteStatus.queued:
          setState(() {
            _routingPhase = 'queued';
            _queuePosition = result.queuePosition;
            _estimatedWaitSeconds = result.estimatedWaitSeconds;
          });
          log(
            'Queued: position ${result.queuePosition}, ~${result.estimatedWaitSeconds}s',
          );
          _startQueuePolling(result.requestId);
          _startWaitCountdown();
          break;

        case AutoRouteStatus.error:
          setState(() => _routingPhase = 'error');
          log('Auto-route error: ${result.errorMessage}');
          // Fall back to broadcast mode
          _fallbackToBroadcast();
          break;
      }
    } catch (e) {
      log('Auto-route flow error: $e');
      if (!mounted) return;
      // Fall back to legacy broadcast
      _startFlow();
    }
  }

  /// Subscribe to realtime updates for a request
  void _subscribeToRequest(String requestId) {
    _channel =
        _client.channel('rq_$requestId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'interpreter_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: requestId,
            ),
            callback: (payload) async {
              final newRow = payload.newRecord;
              final status = newRow['status']?.toString();
              if (status == 'accepted') {
                // Guard: if _checkRequestStatus already handled this
                // transition (e.g. on app resume), skip duplicate dispatch.
                if (_callStarted) return;
                _callStarted = true;

                final interpreterId = newRow['accepted_by'].toString();
                final requesterId = newRow['requester_id'].toString();

                await SessionService.saveSession(
                  requestId: requestId,
                  requesterId: requesterId,
                  interpreterId: interpreterId,
                  currentScreen: 'call',
                );

                if (mounted) {
                  final isVideoCall = widget.callType == 'video';
                  final myUid = _uidFromUuid(requesterId);
                  context.read<CallBloc>().add(
                    StartCall(
                      channelId: requestId,
                      localUid: myUid,
                      isVideoCall: isVideoCall,
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              kIsWeb
                                  ? EnhancedCallScreenWeb(
                                    channelId: requestId,
                                    isVideoCall: isVideoCall,
                                  )
                                  : EnhancedCallScreen(
                                    channelId: requestId,
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
  }

  /// Poll queue status every 10 seconds
  void _startQueuePolling(String requestId) {
    _queuePollTimer?.cancel();
    _queuePollTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final queueData = await AutoRoutingService().getQueueStatus(requestId);
        if (queueData != null && mounted) {
          setState(() {
            _queuePosition =
                queueData['queue_position'] as int? ?? _queuePosition;
            _estimatedWaitSeconds =
                queueData['estimated_wait_seconds'] as int? ??
                _estimatedWaitSeconds;
          });
        }
      } catch (e) {
        log('Error polling queue: $e');
      }
    });
  }

  /// Countdown for estimated wait time
  void _startWaitCountdown() {
    _waitCountdownTimer?.cancel();
    _waitCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_estimatedWaitSeconds > 0) {
        setState(() => _estimatedWaitSeconds--);
      }
    });
  }

  /// Fall back to broadcast mode if auto-routing fails
  Future<void> _fallbackToBroadcast() async {
    log('Falling back to broadcast mode');
    if (_request != null) {
      // Ring matching interpreters via the legacy broadcast system
      try {
        await InterpreterRequestService().ringForExistingRequest(
          _request!.id,
          interpreterType: widget.interpreterType,
          medicalSection: widget.medicalSection,
        );
      } catch (e) {
        log('Broadcast fallback failed: $e');
      }
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
        interpreterType: widget.interpreterType,
        medicalSection: widget.medicalSection,
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

      // Save session as 'waiting'
      await SessionService.saveSession(
        requestId: request.id,
        requesterId: currentUserId,
        interpreterId: '',
        currentScreen: 'waiting_request',
      );
      log('Session saved for request waiting: ${request.id}');

      // 2) Subscribe to updates for this request
      _subscribeToRequest(request.id);

      // Start tier escalation timer for specialist requests
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
    _queuePollTimer?.cancel();
    _waitCountdownTimer?.cancel();
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

      // Guard: realtime callback may have already started the call.
      if (_callStarted) return;
      _callStarted = true;

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
              (_) =>
                  kIsWeb
                      ? EnhancedCallScreenWeb(
                        channelId: currentRequest.id,
                        isVideoCall: isVideoCall,
                      )
                      : EnhancedCallScreen(
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
            child:
                widget.useAutoRouting
                    ? _buildAutoRouteUI()
                    : _buildLegacyWaitingUI(),
          ),
        ),
      ),
    );
  }

  /// Auto-routing UI with phase indicators
  Widget _buildAutoRouteUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Phase indicator
        _buildPhaseIndicator(),
        const SizedBox(height: 32),

        // Main animation
        SizedBox(
          height: 180,
          child: Lottie.asset(
            JsonAssets.loading,
            repeat: true,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),

        // Status text
        _buildStatusText(),
        const SizedBox(height: 16),

        // Queue info (if queued)
        if (_routingPhase == 'queued') _buildQueueCard(),

        // Matched interpreter info
        if (_routingPhase == 'matched' || _routingPhase == 'overflow')
          _buildMatchedCard(),

        const SizedBox(height: 24),

        // Request details
        if (_request != null)
          Text(
            '${widget.fromLanguageId} → ${widget.toLanguageId}'
            '${widget.department != null ? '  •  ${widget.department}' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ColorManager.grey),
          ),
        const SizedBox(height: 24),

        // Cancel button
        TextButton.icon(
          onPressed: _handleCancel,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancel Request'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator() {
    final phases = [
      {'key': 'matching', 'label': 'Finding'},
      {'key': 'matched', 'label': 'Matched'},
      {'key': 'connecting', 'label': 'Connecting'},
    ];

    int activeIndex = 0;
    if (_routingPhase == 'matched' || _routingPhase == 'overflow') {
      activeIndex = 1;
    } else if (_routingPhase == 'queued') {
      activeIndex = 0; // Still in finding phase but queued
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(phases.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIndex = i ~/ 2;
          return Container(
            width: 40,
            height: 2,
            color:
                stepIndex < activeIndex
                    ? const Color(0xFF0955FA)
                    : const Color(0xFFE2E8F0),
          );
        }
        final stepIndex = i ~/ 2;
        final isActive = stepIndex <= activeIndex;
        final isCurrent = stepIndex == activeIndex;
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isActive
                        ? const Color(0xFF0955FA)
                        : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border:
                    isCurrent
                        ? Border.all(
                          color: const Color(0xFF0955FA).withValues(alpha: 0.3),
                          width: 3,
                        )
                        : null,
              ),
              child: Center(
                child:
                    isActive && !isCurrent
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isActive
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              phases[stepIndex]['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                color:
                    isActive
                        ? const Color(0xFF0955FA)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatusText() {
    String title;
    String subtitle;

    switch (_routingPhase) {
      case 'matching':
        title = 'Finding the best interpreter...';
        subtitle = 'Matching language, specialty & availability';
        break;
      case 'matched':
        title = 'Interpreter found!';
        subtitle = 'Connecting you now...';
        break;
      case 'overflow':
        title = 'Connecting via marketplace...';
        subtitle = 'Your staff interpreters are busy — routing to marketplace';
        break;
      case 'queued':
        title = 'All interpreters are busy';
        subtitle = 'You\'re in the queue — we\'ll connect you automatically';
        break;
      case 'error':
        title = 'Switching to broadcast mode...';
        subtitle = 'Looking for available interpreters';
        break;
      default:
        title =
            _isCreating
                ? 'Creating your request...'
                : 'Waiting for interpreter...';
        subtitle = 'We\'ll notify you as soon as someone accepts';
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildQueueCard() {
    final minutes = (_estimatedWaitSeconds / 60).ceil();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Queue position badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$_queuePosition',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'in line',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated wait',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
              ),
              const SizedBox(height: 4),
              Text(
                minutes > 0 ? '~$minutes min' : 'Any moment now',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _matchedInterpreterName ?? 'Interpreter',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF166534),
                ),
              ),
              Text(
                _routingPhase == 'overflow'
                    ? 'Marketplace interpreter'
                    : 'Connecting...',
                style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Legacy broadcast waiting UI (unchanged)
  Widget _buildLegacyWaitingUI() {
    return Column(
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
        TextButton(onPressed: _handleCancel, child: const Text('Cancel')),
      ],
    );
  }

  Future<void> _handleCancel() async {
    if (_request != null) {
      try {
        if (widget.useAutoRouting && _routingPhase == 'queued') {
          await AutoRoutingService().cancelQueuedRequest(_request!.id);
        }
        await InterpreterRequestService().deleteRequest(_request!.id);
        log('Request deleted: ${_request!.id}');
      } catch (e) {
        log('Error deleting request: $e');
      }
    }
    await SessionService.clearSession();
    log('Session cleared - user cancelled request');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
