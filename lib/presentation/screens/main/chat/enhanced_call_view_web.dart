import 'dart:async';
import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/data/services/twilio_call_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/call_feedback_dialog.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';

/// Professional web-optimized call screen — Zoom / Google Meet style
class EnhancedCallScreenWeb extends StatelessWidget {
  final String channelId;
  final bool isVideoCall;

  const EnhancedCallScreenWeb({
    super.key,
    required this.channelId,
    this.isVideoCall = false,
  });

  @override
  Widget build(BuildContext context) {
    return _EnhancedCallScreenWebBody(
      channelId: channelId,
      isVideoCall: isVideoCall,
    );
  }
}

class _EnhancedCallScreenWebBody extends StatefulWidget {
  final String channelId;
  final bool isVideoCall;

  const _EnhancedCallScreenWebBody({
    required this.channelId,
    required this.isVideoCall,
  });

  @override
  State<_EnhancedCallScreenWebBody> createState() =>
      _EnhancedCallScreenWebBodyState();
}

class _EnhancedCallScreenWebBodyState extends State<_EnhancedCallScreenWebBody>
    with SingleTickerProviderStateMixin {
  final TwilioCallService _twilioService = TwilioCallService();
  String? _patientCallSid;
  String _patientCallStatus = '';
  bool _isPatientCallLoading = false;

  // Controls visibility — auto-hide after inactivity
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  // Pulse animation for connecting/waiting states
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Cached video controllers — prevents recreation on every BlocConsumer
  // rebuild (timer ticks every 1s). On web, recreating controllers
  // destroys/recreates the <video> element which kills the camera stream.
  VideoViewController? _localController;
  VideoViewController? _remoteController;
  int? _cachedRemoteUid;
  RtcEngine? _cachedEngine;

  VideoViewController _getLocalController(RtcEngine engine) {
    if (_localController == null || _cachedEngine != engine) {
      _cachedEngine = engine;
      _localController = VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
        ),
      );
    }
    return _localController!;
  }

  VideoViewController _getRemoteController(
    RtcEngine engine,
    int remoteUid,
    String channelId,
  ) {
    if (_remoteController == null ||
        _cachedRemoteUid != remoteUid ||
        _cachedEngine != engine) {
      _cachedEngine = engine;
      _cachedRemoteUid = remoteUid;
      _remoteController = VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(
          uid: remoteUid,
          renderMode: RenderModeType.renderModeHidden,
        ),
        connection: RtcConnection(channelId: channelId),
      );
    }
    return _remoteController!;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _resetHideTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hideControlsTimer?.cancel();
    _localController?.dispose();
    _remoteController?.dispose();
    if (_patientCallSid != null) {
      _twilioService.endCall(_patientCallSid!);
    }
    super.dispose();
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  // ─── Twilio third-party call ───────────────────────────────────────

  void _showCallPatientDialog() {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF2D2E30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.person_add_rounded,
                  color: Color(0xFF8AB4F8),
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Add Participant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '+1 (555) 123-4567',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8AB4F8),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the patient\'s phone number to bridge them in.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _initiatePatientCall(phoneController.text.trim());
                },
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _initiatePatientCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showSnackBar('Please enter a phone number', isError: true);
      return;
    }

    setState(() {
      _isPatientCallLoading = true;
      _patientCallStatus = 'Initiating call...';
    });

    final result = await _twilioService.initiateCall(
      toPhoneNumber: phoneNumber,
      requestId: widget.channelId,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _patientCallSid = result.callSid;
        _patientCallStatus = 'Calling ${result.toPhone}...';
        _isPatientCallLoading = false;
      });
    } else {
      setState(() {
        _isPatientCallLoading = false;
        _patientCallStatus = '';
      });
      _showSnackBar(
        result.errorMessage ?? 'Failed to call participant',
        isError: true,
      );
    }
  }

  Future<void> _endPatientCall() async {
    if (_patientCallSid == null) return;

    setState(() => _isPatientCallLoading = true);

    final success = await _twilioService.endCall(_patientCallSid!);

    if (!mounted) return;

    setState(() {
      _isPatientCallLoading = false;
      if (success) {
        _patientCallSid = null;
        _patientCallStatus = '';
      }
    });

    if (success) {
      _showSnackBar('Participant call ended');
    } else {
      _showSnackBar('Failed to end participant call', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor:
            isError ? const Color(0xFFD93025) : const Color(0xFF1E8E3E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
  }

  Future<void> _showFeedbackAndNavigateHome() async {
    if (!mounted) return;

    await SessionService.endSession(requestId: widget.channelId);
    log('Web: Session marked completed and cleared after call ended');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => CallFeedbackDialog(
            requestId: widget.channelId,
            onComplete: () => _navigateToHome(),
          ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, callState) {
        if (callState is CallEnded) {
          log('Web: Call ended (isRemote: ${callState.isRemote})');
          _showFeedbackAndNavigateHome();
        } else if (callState is CallError) {
          _showErrorDialog(callState);
        }
      },
      builder: (context, callState) {
        return Scaffold(
          backgroundColor: const Color(0xFF202124),
          body: _buildBody(callState),
        );
      },
    );
  }

  void _showErrorDialog(CallError callState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF2D2E30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD93025),
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Call Error',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callState.error.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                if (callState.error.userAction != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    callState.error.userAction!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _navigateToHome();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF8AB4F8)),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildBody(CallState callState) {
    log('Web: Building interface for state: ${callState.runtimeType}');

    if (callState is CallConnecting) return _buildConnectingScreen();
    if (callState is CallOngoing) return _buildOngoingScreen(callState);
    if (callState is CallIdle) {
      return _buildWaitingScreen(
        'Initializing...',
        'Setting up secure connection',
      );
    }
    if (callState is CallEnded) return _buildEndedScreen();
    if (callState is CallError) return _buildErrorScreen(callState);
    return _buildWaitingScreen(
      'Initializing...',
      'Setting up secure connection',
    );
  }

  // ─── Waiting / Connecting ──────────────────────────────────────────

  Widget _buildWaitingScreen(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder:
                (context, child) => Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFF8AB4F8,
                    ).withValues(alpha: _pulseAnimation.value * 0.12),
                    border: Border.all(
                      color: const Color(
                        0xFF8AB4F8,
                      ).withValues(alpha: _pulseAnimation.value * 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Color(0xFF8AB4F8),
                    size: 40,
                  ),
                ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingScreen() {
    return _buildWaitingScreen('Connecting...', 'Joining the session');
  }

  Widget _buildEndedScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD93025).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Color(0xFFD93025),
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Call Ended',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              await SessionService.clearSession();
              _navigateToHome();
            },
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Return to Dashboard'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(CallError callState) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD93025).withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFD93025),
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              callState.error.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                await SessionService.clearSession();
                _navigateToHome();
              },
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Return to Dashboard'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ongoing Call (main layout) ────────────────────────────────────

  Widget _buildOngoingScreen(CallOngoing state) {
    final engine = context.read<CallBloc>().engine;

    return MouseRegion(
      onHover: (_) => _resetHideTimer(),
      child: GestureDetector(
        onTap: _resetHideTimer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main content area
            _buildMainArea(state, engine),

            // Top info bar — fades in/out
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              top: _controlsVisible ? 0 : -80,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _controlsVisible ? 1.0 : 0.0,
                child: _buildTopInfoBar(state),
              ),
            ),

            // Local video PiP (video calls only)
            if (state.isVideoCall && state.videoEnabled && engine != null)
              _buildLocalPiP(state, engine),

            // Third-party call chip
            if (_patientCallStatus.isNotEmpty)
              Positioned(
                top: 72,
                left: 0,
                right: 0,
                child: _buildThirdPartyChip(),
              ),

            // Floating control bar — Google Meet style
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              bottom: _controlsVisible ? 24 : -100,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _controlsVisible ? 1.0 : 0.0,
                child: _buildFloatingControlBar(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main content area ─────────────────────────────────────────────

  Widget _buildMainArea(CallOngoing state, RtcEngine? engine) {
    // Video call with remote user — remote fills screen
    if (state.isVideoCall &&
        state.videoEnabled &&
        engine != null &&
        state.remoteUids.isNotEmpty) {
      final remoteCtrl = _getRemoteController(
        engine,
        state.remoteUids.first,
        widget.channelId,
      );
      return Container(
        color: const Color(0xFF202124),
        child: AgoraVideoView(controller: remoteCtrl),
      );
    }

    // Video call — local preview while waiting for remote
    if (state.isVideoCall && state.videoEnabled && engine != null) {
      final localCtrl = _getLocalController(engine);
      return Container(
        color: const Color(0xFF202124),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AgoraVideoView(controller: localCtrl),
            // Waiting pill overlay
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder:
                      (context, _) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withValues(
                                  alpha: _pulseAnimation.value,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Waiting for participant...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Voice call or camera off — centered avatar
    return Container(
      color: const Color(0xFF202124),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with pulse ring
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder:
                  (context, child) => Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border:
                          state.remoteUids.isEmpty
                              ? Border.all(
                                color: const Color(0xFF8AB4F8).withValues(
                                  alpha: _pulseAnimation.value * 0.5,
                                ),
                                width: 3,
                              )
                              : null,
                    ),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              state.remoteUids.isNotEmpty
                                  ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF1A73E8),
                                      Color(0xFF8AB4F8),
                                    ],
                                  )
                                  : const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3C4043),
                                      Color(0xFF5F6368),
                                    ],
                                  ),
                        ),
                        child: Icon(
                          state.isVideoCall
                              ? Icons.videocam_off_rounded
                              : Icons.person_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 28),
            Text(
              state.isVideoCall ? 'Camera Off' : 'Voice Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.remoteUids.isEmpty
                  ? 'Waiting for participant...'
                  : 'Connected',
              style: TextStyle(
                color:
                    state.remoteUids.isEmpty
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF1E8E3E),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _formatDuration(state.elapsed),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 40,
                fontWeight: FontWeight.w300,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Local PiP ────────────────────────────────────────────────────

  Widget _buildLocalPiP(CallOngoing state, RtcEngine engine) {
    // Only show PiP when remote user has joined
    if (state.remoteUids.isEmpty) return const SizedBox.shrink();

    final localCtrl = _getLocalController(engine);
    return Positioned(
      top: 80,
      right: 20,
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AgoraVideoView(controller: localCtrl),
            // "You" label
            Positioned(
              bottom: 6,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top info bar ──────────────────────────────────────────────────

  Widget _buildTopInfoBar(CallOngoing state) {
    final isVideo = state.isVideoCall && state.videoEnabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient:
            isVideo
                ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                )
                : null,
        color: isVideo ? null : const Color(0xFF202124),
        border:
            isVideo
                ? null
                : Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back
            _buildSmallIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            const SizedBox(width: 12),

            // Encrypted badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Encrypted',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatDuration(state.elapsed),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Participants count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${state.remoteUids.length + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Third-party call chip ─────────────────────────────────────────

  Widget _buildThirdPartyChip() {
    final isActive = _patientCallSid != null;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (isActive ? const Color(0xFF1E8E3E) : const Color(0xFFE37400))
              .withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isActive
                    ? const Color(0xFF1E8E3E)
                    : const Color(0xFFE37400))
                .withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isPatientCallLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      isActive
                          ? const Color(0xFF1E8E3E)
                          : const Color(0xFFE37400),
                ),
              )
            else
              Icon(
                isActive ? Icons.phone_in_talk_rounded : Icons.phone_rounded,
                size: 15,
                color:
                    isActive
                        ? const Color(0xFF1E8E3E)
                        : const Color(0xFFE37400),
              ),
            const SizedBox(width: 8),
            Text(
              _patientCallStatus,
              style: TextStyle(
                color:
                    isActive
                        ? const Color(0xFF1E8E3E)
                        : const Color(0xFFE37400),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Floating control bar ──────────────────────────────────────────

  Widget _buildFloatingControlBar(CallOngoing state) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF303134),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic
            _ControlPill(
              icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: state.muted ? 'Unmute' : 'Mute',
              isActive: !state.muted,
              isToggled: state.muted,
              onTap: () => context.read<CallBloc>().add(ToggleMute()),
            ),
            const SizedBox(width: 4),

            // Camera (video calls only)
            if (state.isVideoCall) ...[
              _ControlPill(
                icon:
                    state.videoEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                label:
                    state.videoEnabled ? 'Turn off camera' : 'Turn on camera',
                isActive: state.videoEnabled,
                isToggled: !state.videoEnabled,
                onTap: () => context.read<CallBloc>().add(ToggleVideo()),
              ),
              const SizedBox(width: 4),
            ],

            // Flip camera (video only, when camera is on)
            if (state.isVideoCall && state.videoEnabled) ...[
              _ControlPill(
                icon: Icons.cameraswitch_rounded,
                label: 'Switch camera',
                isActive: true,
                onTap: () => context.read<CallBloc>().add(SwitchCamera()),
              ),
              const SizedBox(width: 4),
            ],

            // Add / End third party
            _ControlPill(
              icon:
                  _patientCallSid != null
                      ? Icons.phone_disabled_rounded
                      : Icons.person_add_alt_1_rounded,
              label:
                  _patientCallSid != null
                      ? 'End participant call'
                      : 'Add participant',
              isActive: true,
              isToggled: _patientCallSid != null,
              toggledColor: const Color(0xFFE37400),
              onTap:
                  _isPatientCallLoading
                      ? () {}
                      : (_patientCallSid != null
                          ? _endPatientCall
                          : _showCallPatientDialog),
            ),

            // Separator before end call
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white.withValues(alpha: 0.1),
            ),

            // End Call — prominent red
            _EndCallButton(
              onTap: () => context.read<CallBloc>().add(EndCall()),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Widget _buildSmallIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Extracted widgets
// ═══════════════════════════════════════════════════════════════════════

/// Individual control button in the floating bar (Google Meet pill style)
class _ControlPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isToggled;
  final Color? toggledColor;
  final VoidCallback onTap;

  const _ControlPill({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isToggled = false,
    this.toggledColor,
    required this.onTap,
  });

  @override
  State<_ControlPill> createState() => _ControlPillState();
}

class _ControlPillState extends State<_ControlPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final toggledCol = widget.toggledColor ?? const Color(0xFFD93025);
    final bgColor =
        widget.isToggled
            ? toggledCol.withValues(alpha: 0.15)
            : (_hovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05));
    final iconColor =
        widget.isToggled
            ? toggledCol
            : Colors.white.withValues(alpha: _hovered ? 0.95 : 0.75);

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  widget.isToggled
                      ? Border.all(color: toggledCol.withValues(alpha: 0.3))
                      : null,
            ),
            child: Icon(widget.icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Prominent end-call button
class _EndCallButton extends StatefulWidget {
  final VoidCallback onTap;
  const _EndCallButton({required this.onTap});

  @override
  State<_EndCallButton> createState() => _EndCallButtonState();
}

class _EndCallButtonState extends State<_EndCallButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Leave call',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 48,
            decoration: BoxDecoration(
              color:
                  _hovered ? const Color(0xFFB3261E) : const Color(0xFFD93025),
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  _hovered
                      ? [
                        BoxShadow(
                          color: const Color(0xFFD93025).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : null,
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
