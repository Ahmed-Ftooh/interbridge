import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/data/services/twilio_call_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/call_feedback_dialog.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';

/// Professional web-optimized call screen with modern dashboard-style layout
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

class _EnhancedCallScreenWebBodyState
    extends State<_EnhancedCallScreenWebBody> {
  final TwilioCallService _twilioService = TwilioCallService();
  String? _patientCallSid;
  String _patientCallStatus = '';
  bool _isPatientCallLoading = false;

  @override
  void dispose() {
    if (_patientCallSid != null) {
      _twilioService.endCall(_patientCallSid!);
    }
    super.dispose();
  }

  void _showCallPatientDialog() {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Add Third Party',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    hintText: '+1 (555) 123-4567',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the patient\'s phone number to add them to the call.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _initiatePatientCall(phoneController.text.trim());
                },
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    await SessionService.clearSession();
    log('Web: Session cleared after call ended');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => CallFeedbackDialog(
            requestId: widget.channelId,
            onComplete: () {
              _navigateToHome();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, callState) {
        if (callState is CallEnded) {
          log('Web: Call ended (isRemote: ${callState.isRemote})');
          _showFeedbackAndNavigateHome();
        } else if (callState is CallError) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'Call Error',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        callState.error.message,
                        style: const TextStyle(color: Colors.white70),
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
                        style: TextStyle(color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ],
                ),
          );
        }
      },
      builder: (context, callState) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: _buildCallInterface(callState),
        );
      },
    );
  }

  Widget _buildCallInterface(CallState callState) {
    log('Web: Building interface for state: ${callState.runtimeType}');

    if (callState is CallConnecting) {
      return _buildConnectingScreen();
    }

    if (callState is CallOngoing) {
      return _buildOngoingCallScreen(callState);
    }

    if (callState is CallIdle) {
      return _buildInitializingScreen();
    }

    if (callState is CallEnded) {
      return _buildEndedScreen();
    }

    if (callState is CallError) {
      return _buildErrorScreen(callState);
    }

    return _buildInitializingScreen();
  }

  Widget _buildInitializingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFF3B82F6),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Initializing Call...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Setting up secure connection',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Connecting...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while we connect your call',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_end_rounded,
              size: 64,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Call Ended',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await SessionService.clearSession();
              _navigateToHome();
            },
            icon: const Icon(Icons.home_rounded),
            label: const Text('Return to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(CallError callState) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Call Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              callState.error.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await SessionService.clearSession();
                _navigateToHome();
              },
              icon: const Icon(Icons.home_rounded),
              label: const Text('Return to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOngoingCallScreen(CallOngoing state) {
    final engine = context.read<CallBloc>().engine;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Column(
      children: [
        // Top bar
        _buildTopBar(state),

        // Main content
        Expanded(
          child:
              isWide
                  ? Row(
                    children: [
                      // Video / Avatar area
                      Expanded(
                        flex: 3,
                        child: _buildMainVideoArea(state, engine),
                      ),
                      // Side panel
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          border: Border(
                            left: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        child: _buildSidePanel(state),
                      ),
                    ],
                  )
                  : Column(
                    children: [
                      Expanded(child: _buildMainVideoArea(state, engine)),
                    ],
                  ),
        ),

        // Bottom controls
        _buildBottomControls(state, isWide),
      ],
    );
  }

  Widget _buildTopBar(CallOngoing state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Minimize',
          ),
          const SizedBox(width: 12),

          // Call type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (state.isVideoCall
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF22C55E))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.isVideoCall ? 'Video Call' : 'Voice Call',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(state.elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Channel ID
          Text(
            'Session: ${widget.channelId.substring(0, 8)}...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVideoArea(CallOngoing state, RtcEngine? engine) {
    // Video call with remote video
    if (state.isVideoCall &&
        state.videoEnabled &&
        engine != null &&
        state.remoteUids.isNotEmpty) {
      return Stack(
        children: [
          // Remote video
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: state.remoteUids.first),
                connection: RtcConnection(channelId: widget.channelId),
              ),
            ),
          ),
          // Local video PiP
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Voice call or video off
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1A1040).withValues(alpha: 0.5),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                state.isVideoCall ? Icons.videocam_off_rounded : Icons.person,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              state.isVideoCall ? 'Video Call' : 'Voice Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.remoteUids.isEmpty
                  ? 'Waiting for participant...'
                  : 'Connected',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            // Large duration
            Text(
              _formatDuration(state.elapsed),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(CallOngoing state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Call Info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Status
          _buildInfoRow(
            Icons.circle,
            'Status',
            state.remoteUids.isEmpty ? 'Waiting...' : 'Connected',
            state.remoteUids.isEmpty
                ? const Color(0xFFF59E0B)
                : const Color(0xFF22C55E),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.people_outline,
            'Participants',
            '${state.remoteUids.length + 1}',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            state.muted ? Icons.mic_off : Icons.mic,
            'Microphone',
            state.muted ? 'Muted' : 'Active',
            state.muted ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
          ),

          // Patient call status
          if (_patientCallStatus.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 16),
            const Text(
              'Third Party Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_patientCallSid != null
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF59E0B))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_patientCallSid != null
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _patientCallSid != null ? Icons.phone_in_talk : Icons.phone,
                    color:
                        _patientCallSid != null
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _patientCallStatus,
                      style: TextStyle(
                        color:
                            _patientCallSid != null
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFF59E0B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Session ID
          Text(
            'Session: ${widget.channelId}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(CallOngoing state, bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mute
          _buildControlButton(
            icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: state.muted ? 'Unmute' : 'Mute',
            isActive: state.muted,
            activeColor: const Color(0xFFEF4444),
            onTap: () => context.read<CallBloc>().add(ToggleMute()),
          ),
          const SizedBox(width: 20),

          // Video toggle
          if (state.isVideoCall) ...[
            _buildControlButton(
              icon:
                  state.videoEnabled
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
              label: state.videoEnabled ? 'Camera' : 'Camera Off',
              isActive: !state.videoEnabled,
              activeColor: const Color(0xFFEF4444),
              onTap: () => context.read<CallBloc>().add(ToggleVideo()),
            ),
            const SizedBox(width: 20),
          ],

          // End Call
          _buildControlButton(
            icon: Icons.call_end_rounded,
            label: 'End Call',
            isActive: true,
            activeColor: const Color(0xFFEF4444),
            isEndCall: true,
            onTap: () => context.read<CallBloc>().add(EndCall()),
          ),
          const SizedBox(width: 20),

          // Add Party
          _buildControlButton(
            icon:
                _patientCallSid != null
                    ? Icons.phone_disabled_rounded
                    : Icons.add_call,
            label: _patientCallSid != null ? 'End Party' : 'Add Party',
            isActive: _patientCallSid != null,
            activeColor: const Color(0xFFF59E0B),
            onTap:
                _isPatientCallLoading
                    ? () {}
                    : (_patientCallSid != null
                        ? _endPatientCall
                        : _showCallPatientDialog),
          ),

          // Camera switch for video
          if (state.isVideoCall) ...[
            const SizedBox(width: 20),
            _buildControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              isActive: false,
              activeColor: Colors.white,
              onTap:
                  state.videoEnabled
                      ? () => context.read<CallBloc>().add(SwitchCamera())
                      : () {},
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    bool isEndCall = false,
  }) {
    final buttonColor =
        isEndCall
            ? activeColor
            : (isActive ? activeColor : Colors.white.withValues(alpha: 0.8));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isEndCall ? 64 : 52,
              height: isEndCall ? 64 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isEndCall
                        ? activeColor
                        : (isActive
                            ? activeColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.08)),
                border:
                    isEndCall
                        ? null
                        : Border.all(
                          color: buttonColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                boxShadow:
                    isEndCall
                        ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                        : null,
              ),
              child: Icon(
                icon,
                color: isEndCall ? Colors.white : buttonColor,
                size: isEndCall ? 28 : 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
