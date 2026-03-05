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

/// Professional Google Meet-style web call screen.
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

// ─── Google Meet palette ────────────────────────────────────────
const _kBgColor = Color(0xFF202124);
const _kSurfaceColor = Color(0xFF303134);
const _kSurfaceLight = Color(0xFF3C4043);
const _kAccentBlue = Color(0xFF8AB4F8);
const _kEndRed = Color(0xFFD93025);
const _kEndRedHover = Color(0xFFB7271D);
const _kTextPrimary = Color(0xFFE8EAED);
const _kTextSecondary = Color(0xFF9AA0A6);
const _kGreen = Color(0xFF34A853);

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
  // ─── Twilio third-party call ──────────────────────────────────
  final TwilioCallService _twilioService = TwilioCallService();
  String? _patientCallSid;
  String _patientCallStatus = '';
  bool _isPatientCallLoading = false;

  // ─── Cached Agora video controllers ───────────────────────────
  VideoViewController? _localController;
  VideoViewController? _remoteController;
  int? _cachedRemoteUid;
  RtcEngine? _cachedEngine;

  // ─── Controls visibility (auto-hide after 4s) ────────────────
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // ─── Pulse animation for connecting state ─────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // ─── Controller helpers ──────────────────────────────────────
  VideoViewController _getLocalController(RtcEngine engine) {
    if (_localController == null || _cachedEngine != engine) {
      _cachedEngine = engine;
      _localController = VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
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

  // ─── Lifecycle ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _resetHideTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hideTimer?.cancel();
    _localController?.dispose();
    _remoteController?.dispose();
    if (_patientCallSid != null) {
      _twilioService.endCall(_patientCallSid!);
    }
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  // ─── Navigation helpers ──────────────────────────────────────
  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
  }

  Future<void> _showFeedbackAndNavigateHome() async {
    if (!mounted) return;
    await SessionService.endSession(requestId: widget.channelId);
    log('Session marked completed and cleared after call ended');
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _kEndRed : _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
      ),
    );
  }

  // ─── Third-party Twilio calls ────────────────────────────────
  void _showCallPatientDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: _kSurfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Add Third Party',
              style: TextStyle(color: _kTextPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: _kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: const TextStyle(color: _kTextSecondary),
                    hintText: '+1 (555) 123-4567',
                    hintStyle: TextStyle(color: _kTextSecondary.withAlpha(100)),
                    prefixIcon: const Icon(Icons.phone, color: _kAccentBlue),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kSurfaceLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kAccentBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the phone number to add them to the call.',
                  style: TextStyle(color: _kTextSecondary, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _kTextSecondary),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _initiatePatientCall(phoneController.text.trim());
                },
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
      log('Patient call initiated: ${result.callSid}');
    } else {
      setState(() {
        _isPatientCallLoading = false;
        _patientCallStatus = '';
      });
      _showSnackBar(
        result.errorMessage ?? 'Failed to call patient',
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
      _showSnackBar('Patient call ended');
    } else {
      _showSnackBar('Failed to end patient call', isError: true);
    }
  }

  // ─── Duration formatter ──────────────────────────────────────
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, state) {
        log('CallScreen: state changed to ${state.runtimeType}');
        if (state is CallEnded) {
          _showFeedbackAndNavigateHome();
        } else if (state is CallError) {
          log('CallScreen: error — ${state.error.message}');
          // Don't auto-navigate; let the error screen handle retry/dismiss.
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: _kBgColor,
          body: MouseRegion(
            onHover: (_) => _resetHideTimer(),
            child: GestureDetector(
              onTap: _resetHideTimer,
              child: _buildBody(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CallState state) {
    log('CallScreen: building with state ${state.runtimeType}');
    if (state is CallConnecting) {
      return _buildConnectingScreen();
    }
    if (state is CallOngoing) {
      return _buildOngoingCallScreen(context, state);
    }
    if (state is CallError) {
      return _buildErrorScreen(context, state);
    }
    if (state is CallEnded) {
      return _buildEndedScreen();
    }
    // CallIdle — waiting for bloc to process StartCall
    return _buildConnectingScreen();
  }

  // ═══════════════════════════════════════════════════════════════
  //  ERROR SCREEN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildErrorScreen(BuildContext context, CallError state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kEndRed.withAlpha(30),
            ),
            child: const Icon(
              Icons.error_outline,
              color: _kEndRed,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Call Failed',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              state.error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _navigateToHome,
                icon: const Icon(Icons.home, size: 18),
                label: const Text('Go Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTextPrimary,
                  side: const BorderSide(color: _kSurfaceLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ENDED SCREEN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEndedScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.call_end, color: _kTextSecondary, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Call Ended',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: _kAccentBlue),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONNECTING SCREEN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildConnectingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _pulseAnim,
            builder:
                (_, __) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kAccentBlue.withAlpha(
                        (_pulseAnim.value * 255).toInt(),
                      ),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kSurfaceColor,
                      ),
                      child: Icon(
                        widget.isVideoCall ? Icons.videocam : Icons.call,
                        color: _kAccentBlue,
                        size: 36,
                      ),
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Connecting...',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up your ${widget.isVideoCall ? 'video' : 'audio'} call',
            style: const TextStyle(color: _kTextSecondary, fontSize: 14),
          ),
          const SizedBox(height: 48),
          // End call button during connecting
          _EndCallButton(
            onPressed: () => context.read<CallBloc>().add(EndCall()),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ONGOING CALL — MAIN LAYOUT
  // ═══════════════════════════════════════════════════════════════
  Widget _buildOngoingCallScreen(BuildContext context, CallOngoing state) {
    final engine = context.read<CallBloc>().engine;
    final hasRemote = state.remoteUids.isNotEmpty;
    final isVideo = state.isVideoCall;

    return Stack(
      children: [
        // ── Main video / avatar area ───────────────────────────
        Positioned.fill(child: _buildMainArea(engine, state, hasRemote)),

        // ── Top info bar ───────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          top: _controlsVisible ? 0 : -80,
          left: 0,
          right: 0,
          child: _buildTopBar(state),
        ),

        // ── Third-party call chip ─────────────────────────────
        if (_patientCallSid != null || _patientCallStatus.isNotEmpty)
          Positioned(top: 72, left: 0, right: 0, child: _buildThirdPartyChip()),

        // ── Local PiP (only in video calls with remote) ──────
        if (isVideo && hasRemote && engine != null)
          Positioned(right: 16, top: 80, child: _buildLocalPiP(engine)),

        // ── Floating control bar (bottom center) ─────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          bottom: _controlsVisible ? 24 : -100,
          left: 0,
          right: 0,
          child: _buildFloatingControlBar(context, state),
        ),
      ],
    );
  }

  // ─── Main video / avatar area ───────────────────────────────
  Widget _buildMainArea(RtcEngine? engine, CallOngoing state, bool hasRemote) {
    final isVideo = state.isVideoCall;

    // Voice call → centered avatar
    if (!isVideo) {
      return Center(child: _buildVoiceAvatar(hasRemote));
    }

    // Video call, no remote user yet
    if (!hasRemote || engine == null) {
      return Stack(
        children: [
          // Show local preview full-screen while waiting
          if (state.videoEnabled && engine != null)
            Positioned.fill(
              child: ClipRRect(
                child: _safeAgoraView(
                  () => _getLocalController(engine),
                  fallback: _buildVoiceAvatar(false),
                ),
              ),
            )
          else
            Center(child: _buildVoiceAvatar(false)),
          // "Waiting for others" overlay
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kSurfaceColor.withAlpha(200),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Waiting for others to join...',
                  style: TextStyle(color: _kTextSecondary, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Video call, has remote user → show remote full screen
    final remoteUid = state.remoteUids.first;
    try {
      return AgoraVideoView(
        controller: _getRemoteController(engine, remoteUid, state.channelId),
      );
    } catch (e) {
      log('CallScreen: AgoraVideoView (remote) error: $e');
      return Center(child: _buildVoiceAvatar(true));
    }
  }

  // ─── Voice-only avatar ──────────────────────────────────────
  Widget _buildVoiceAvatar(bool connected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? _kAccentBlue.withAlpha(40) : _kSurfaceColor,
            border: Border.all(
              color: connected ? _kAccentBlue : _kSurfaceLight,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.person,
            size: 56,
            color: connected ? _kAccentBlue : _kTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          connected ? 'Connected' : 'Waiting for others...',
          style: TextStyle(
            color: connected ? _kTextPrimary : _kTextSecondary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ─── Top bar (duration + info) ──────────────────────────────
  Widget _buildTopBar(CallOngoing state) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgColor.withAlpha(230), _kBgColor.withAlpha(0)],
        ),
      ),
      child: Row(
        children: [
          // Call type icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kGreen.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              state.isVideoCall ? Icons.videocam : Icons.call,
              color: _kGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Duration
          Text(
            _fmt(state.elapsed),
            style: const TextStyle(
              color: _kTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // Encrypted badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kSurfaceColor.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: _kTextSecondary, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Encrypted',
                  style: TextStyle(color: _kTextSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Participants count
          if (state.remoteUids.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kSurfaceColor.withAlpha(180),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, color: _kTextSecondary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${state.remoteUids.length + 1}',
                    style: TextStyle(color: _kTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Third-party call chip ──────────────────────────────────
  Widget _buildThirdPartyChip() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _kSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kSurfaceLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isPatientCallLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kAccentBlue,
                ),
              )
            else
              Icon(Icons.phone_in_talk, color: _kGreen, size: 16),
            const SizedBox(width: 8),
            Text(
              _patientCallStatus,
              style: const TextStyle(color: _kTextPrimary, fontSize: 13),
            ),
            if (_patientCallSid != null && !_isPatientCallLoading) ...[
              const SizedBox(width: 12),
              InkWell(
                onTap: _endPatientCall,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _kEndRed.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.call_end, color: _kEndRed, size: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Safe AgoraVideoView wrapper ──────────────────────────
  Widget _safeAgoraView(
    VideoViewController Function() controllerFn, {
    required Widget fallback,
  }) {
    try {
      final controller = controllerFn();
      return AgoraVideoView(controller: controller);
    } catch (e) {
      log('CallScreen: AgoraVideoView error: $e');
      return Center(child: fallback);
    }
  }

  // ─── Local PiP video ────────────────────────────────────────
  Widget _buildLocalPiP(RtcEngine engine) {
    return Container(
      width: 180,
      height: 135,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kSurfaceLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Positioned.fill(
              child: _safeAgoraView(
                () => _getLocalController(engine),
                fallback: const Icon(Icons.person, color: _kTextSecondary, size: 40),
              ),
            ),
            // "You" label
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBgColor.withAlpha(180),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: _kTextPrimary,
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

  // ─── Floating control bar ───────────────────────────────────
  Widget _buildFloatingControlBar(BuildContext context, CallOngoing state) {
    final bloc = context.read<CallBloc>();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurfaceColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Microphone
            _ControlPill(
              icon: state.muted ? Icons.mic_off : Icons.mic,
              label: state.muted ? 'Unmute' : 'Mute',
              active: !state.muted,
              activeColor: _kTextPrimary,
              inactiveColor: _kEndRed,
              onTap: () => bloc.add(ToggleMute()),
            ),
            const SizedBox(width: 8),

            // Video (only for video calls)
            if (state.isVideoCall) ...[
              _ControlPill(
                icon: state.videoEnabled ? Icons.videocam : Icons.videocam_off,
                label: state.videoEnabled ? 'Stop Video' : 'Start Video',
                active: state.videoEnabled,
                activeColor: _kTextPrimary,
                inactiveColor: _kEndRed,
                onTap: () => bloc.add(ToggleVideo()),
              ),
              const SizedBox(width: 8),
            ],

            // Speaker / audio output
            if (!state.isVideoCall) ...[
              _ControlPill(
                icon: state.speakerOn ? Icons.volume_up : Icons.volume_off,
                label: state.speakerOn ? 'Speaker' : 'Earpiece',
                active: state.speakerOn,
                activeColor: _kAccentBlue,
                inactiveColor: _kTextSecondary,
                onTap: () => bloc.add(ToggleSpeaker()),
              ),
              const SizedBox(width: 8),
            ],

            // Switch camera (video only)
            if (state.isVideoCall) ...[
              _ControlPill(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                active: true,
                activeColor: _kTextPrimary,
                inactiveColor: _kTextSecondary,
                onTap: () => bloc.add(SwitchCamera()),
              ),
              const SizedBox(width: 8),
            ],

            // Add third party
            _ControlPill(
              icon: Icons.person_add_alt_1,
              label: 'Add',
              active: true,
              activeColor: _kTextPrimary,
              inactiveColor: _kTextSecondary,
              onTap: _showCallPatientDialog,
            ),

            const SizedBox(width: 16),

            // End call
            _EndCallButton(onPressed: () => bloc.add(EndCall())),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Extracted widgets
// ═══════════════════════════════════════════════════════════════════

/// A pill-shaped control button (mic, camera, etc.)
class _ControlPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _ControlPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_ControlPill> createState() => _ControlPillState();
}

class _ControlPillState extends State<_ControlPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.activeColor : widget.inactiveColor;
    final bgColor =
        _hovered
            ? _kSurfaceLight
            : (widget.active
                ? Colors.transparent
                : _kSurfaceLight.withAlpha(120));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                if (_hovered) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get icon => widget.icon;
}

/// Red "End Call" button.
class _EndCallButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _EndCallButton({required this.onPressed});

  @override
  State<_EndCallButton> createState() => _EndCallButtonState();
}

class _EndCallButtonState extends State<_EndCallButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? _kEndRedHover : _kEndRed,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_end, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Leave',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
