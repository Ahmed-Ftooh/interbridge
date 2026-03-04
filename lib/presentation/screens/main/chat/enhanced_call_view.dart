import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/data/services/twilio_call_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/call_feedback_dialog.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';

// 1. SIMPLIFIED WIDGET: It no longer creates a BLoC
class EnhancedCallScreen extends StatelessWidget {
  final String channelId;
  final bool isVideoCall;

  const EnhancedCallScreen({
    super.key,
    required this.channelId,
    this.isVideoCall = false,
  });

  @override
  Widget build(BuildContext context) {
    // We removed the BlocProvider wrapper from here
    return _EnhancedCallScreenBody(
      channelId: channelId,
      isVideoCall: isVideoCall,
    );
  }
}

class _EnhancedCallScreenBody extends StatefulWidget {
  final String channelId;
  final bool isVideoCall;

  const _EnhancedCallScreenBody({
    required this.channelId,
    required this.isVideoCall,
  });

  @override
  State<_EnhancedCallScreenBody> createState() =>
      _EnhancedCallScreenBodyState();
}

class _EnhancedCallScreenBodyState extends State<_EnhancedCallScreenBody> {
  // Twilio patient call state
  final TwilioCallService _twilioService = TwilioCallService();
  String? _patientCallSid;
  String _patientCallStatus = '';
  bool _isPatientCallLoading = false;

  // Cached video controllers — prevents recreation on every rebuild
  // (timer ticks every 1s). Recreating controllers can destroy the
  // native video surface and cause black frames or flickering.
  VideoViewController? _localController;
  VideoViewController? _remoteController;
  int? _cachedRemoteUid;
  RtcEngine? _cachedEngine;

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _localController?.dispose();
    _remoteController?.dispose();
    // End any active patient call when leaving the screen
    if (_patientCallSid != null) {
      _twilioService.endCall(_patientCallSid!);
    }
    super.dispose();
  }

  // ===== Patient Phone Call Methods =====

  void _showCallPatientDialog() {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Add Third Party'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+1 (555) 123-4567',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the patient\'s phone number to add them to the call.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _initiatePatientCall(phoneController.text.trim());
                },
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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

    // Mark request as completed AND clear local session
    await SessionService.endSession(requestId: widget.channelId);
    log('Session marked completed and cleared after call ended');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => CallFeedbackDialog(
            requestId: widget.channelId,
            onComplete: () {
              // Dialog already pops itself, just navigate to home
              _navigateToHome();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Simplified - no ChatBloc listener needed for call end
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, callState) {
        // Listen for call state changes
        if (callState is CallEnded) {
          // Call ended (either by us or remote) - show feedback dialog then navigate home
          log(
            'Call ended (isRemote: ${callState.isRemote}). Showing feedback dialog.',
          );
          _showFeedbackAndNavigateHome();
        } else if (callState is CallError) {
          // Show error dialog and then navigate to home
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => AlertDialog(
                  title: const Text('Call Error'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(callState.error.message),
                      if (callState.error.userAction != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          callState.error.userAction!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(); // Close dialog
                        _navigateToHome(); // Navigate to home
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      },
      builder: (context, callState) {
        return Scaffold(
          backgroundColor: ColorManager.primary2Dark,
          body: Stack(
            children: [
              // Main call interface
              _buildCallInterface(callState),

              // Top controls
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: ColorManager.white),
                        onPressed: () {
                          // 6. CHANGED: This just pops the screen.
                          // The call continues in the background.
                          Navigator.of(context).maybePop();
                        },
                      ),

                      // End Session button
                      // PopupMenuButton<String>(
                      //   icon: Icon(Icons.more_vert, color: ColorManager.white),
                      //   onSelected: (value) {
                      //     if (value == 'end_session') {
                      //       _showEndSessionDialog(context);
                      //     }
                      //   },
                      //   itemBuilder:
                      //       (context) => [
                      //         const PopupMenuItem(
                      //           value: 'end_session',
                      //           child: Row(
                      //             children: [
                      //               Icon(Icons.exit_to_app, color: Colors.red),
                      //               SizedBox(width: 8),
                      //               Text('End Session'),
                      //             ],
                      //           ),
                      //         ),
                      //       ],
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallInterface(CallState callState) {
    log(
      '_buildCallInterface - Building interface for state: ${callState.runtimeType}',
    );

    if (callState is CallConnecting) {
      log('_buildCallInterface - Showing connecting screen');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ColorManager.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: ColorManager.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connecting...',
              style: TextStyle(
                color: ColorManager.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we connect your call',
              style: TextStyle(
                color: ColorManager.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (callState is CallOngoing) {
      log(
        '_buildCallInterface - Showing call interface (isVideoCall: ${callState.isVideoCall})',
      );

      // Get the engine from CallBloc for video rendering
      final engine = context.read<CallBloc>().engine;

      return Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Background / Remote Video
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: ColorManager.secondaryGradient,
                  ),
                  child:
                      callState.isVideoCall &&
                              callState.videoEnabled &&
                              engine != null &&
                              callState.remoteUids.isNotEmpty
                          ? AgoraVideoView(
                            controller: _getRemoteController(
                              engine,
                              callState.remoteUids.first,
                              widget.channelId,
                            ),
                          )
                          : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: ColorManager.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ColorManager.primary.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    callState.isVideoCall
                                        ? Icons.videocam_off
                                        : Icons.person,
                                    size: 100,
                                    color: ColorManager.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  callState.isVideoCall
                                      ? 'Video Call'
                                      : 'Voice Call',
                                  style: TextStyle(
                                    color: ColorManager.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Channel: ${widget.channelId}',
                                  style: TextStyle(
                                    color: ColorManager.white.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Call duration display
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorManager.primary2.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: ColorManager.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _formatDuration(callState.elapsed),
                                    style: TextStyle(
                                      color: ColorManager.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),

                // Local Video Preview (Picture-in-Picture)
                if (callState.isVideoCall &&
                    callState.videoEnabled &&
                    engine != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AgoraVideoView(
                        controller: _getLocalController(engine),
                      ),
                    ),
                  ),

                // Call duration overlay for video calls
                if (callState.isVideoCall && callState.videoEnabled)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(callState.elapsed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildCallControls(callState),
        ],
      );
    }

    // Handle CallIdle state (initial state before connecting)
    if (callState is CallIdle) {
      log('_buildCallInterface - Showing idle/initializing screen');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ColorManager.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: ColorManager.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing...',
              style: TextStyle(
                color: ColorManager.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up your call',
              style: TextStyle(
                color: ColorManager.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Handle CallEnded state explicitly
    if (callState is CallEnded) {
      log('_buildCallInterface - Showing call ended screen');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_end, size: 80, color: ColorManager.error),
            const SizedBox(height: 16),
            Text(
              'Call ended',
              style: TextStyle(
                color: ColorManager.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await SessionService.clearSession();
                _navigateToHome();
              },
              icon: const Icon(Icons.home),
              label: const Text('Return to Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Handle CallError state
    if (callState is CallError) {
      log(
        '_buildCallInterface - Showing error screen: ${callState.error.message}',
      );
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: ColorManager.error),
            const SizedBox(height: 16),
            Text(
              'Call Error',
              style: TextStyle(
                color: ColorManager.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                callState.error.message,
                style: TextStyle(
                  color: ColorManager.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await SessionService.clearSession();
                _navigateToHome();
              },
              icon: const Icon(Icons.home),
              label: const Text('Return to Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Fallback for any unknown state - show initializing to be safe
    log(
      '_buildCallInterface - Unknown state: ${callState.runtimeType}, showing initializing',
    );
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ColorManager.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: ColorManager.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Please wait...',
            style: TextStyle(
              color: ColorManager.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls(CallOngoing state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColorManager.primary2Dark.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Patient call status indicator
          if (_patientCallStatus.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    _patientCallSid != null
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _patientCallSid != null ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _patientCallSid != null ? Icons.phone_in_talk : Icons.phone,
                    color:
                        _patientCallSid != null ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _patientCallStatus,
                    style: TextStyle(
                      color:
                          _patientCallSid != null
                              ? Colors.green
                              : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 16,
            children: [
              _roundIconButton(
                icon: state.muted ? Icons.mic_off : Icons.mic,
                label: state.muted ? 'Unmute' : 'Mute',
                color: state.muted ? ColorManager.error : ColorManager.white,
                onTap: () => context.read<CallBloc>().add(ToggleMute()),
              ),
              // Video toggle (only for video calls)
              if (state.isVideoCall)
                _roundIconButton(
                  icon:
                      state.videoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: state.videoEnabled ? 'Camera' : 'Camera Off',
                  color:
                      state.videoEnabled
                          ? ColorManager.primary
                          : ColorManager.white,
                  onTap: () => context.read<CallBloc>().add(ToggleVideo()),
                ),
              _roundIconButton(
                icon: Icons.call_end,
                label: 'End Call',
                color: ColorManager.error,
                onTap: () {
                  // End the call and let the listener handle navigation
                  context.read<CallBloc>().add(EndCall());
                },
              ),
              // Call Patient button
              _roundIconButton(
                icon:
                    _patientCallSid != null
                        ? Icons.phone_disabled
                        : Icons.add_call,
                label: _patientCallSid != null ? 'End Party' : 'Add Party',
                color: _patientCallSid != null ? Colors.orange : Colors.green,
                onTap:
                    _isPatientCallLoading
                        ? () {}
                        : (_patientCallSid != null
                            ? _endPatientCall
                            : _showCallPatientDialog),
              ),
              // Camera switch (only for video calls with video enabled)
              if (state.isVideoCall)
                _roundIconButton(
                  icon: Icons.cameraswitch,
                  label: 'Flip',
                  color:
                      state.videoEnabled
                          ? ColorManager.white
                          : ColorManager.white.withValues(alpha: 0.3),
                  onTap:
                      state.videoEnabled
                          ? () => context.read<CallBloc>().add(SwitchCamera())
                          : () {},
                ),
              // Speaker button (only for voice calls or when video is off)
              if (!state.isVideoCall)
                _roundIconButton(
                  icon: state.speakerOn ? Icons.volume_up : Icons.hearing,
                  label: state.speakerOn ? 'Speaker' : 'Earpiece',
                  color:
                      state.speakerOn
                          ? ColorManager.primary
                          : ColorManager.white,
                  onTap: () => context.read<CallBloc>().add(ToggleSpeaker()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: color, size: 26)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ColorManager.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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

  // void _saveSessionState() {
  //   SessionService.saveSession(
  //     requestId: widget.channelId,
  //     requesterId: '', // These will be handled by the session
  //     interpreterId: '',
  //     currentScreen: 'call',
  //   );
  // }

  // void _showEndSessionDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder:
  //         (context) => AlertDialog(
  //           title: const Text('End Session'),
  //           content: const Text(
  //             'Are you sure you want to end this session? You will be returned to the home screen.',
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(),
  //               child: const Text('Cancel'),
  //             ),
  //             ElevatedButton(
  //               onPressed: () async {
  //                 try {
  //                   // Close the dialog first
  //                   Navigator.of(context).pop();

  //                   // End the call first if it's ongoing
  //                   if (mounted) {
  //                     context.read<CallBloc>().add(EndCall());
  //                   }

  //                   // Wait a moment for call to end
  //                   await Future.delayed(const Duration(milliseconds: 1000));

  //                   // End the session
  //                   await SessionService.endSession();

  //                   // Ensure we're still mounted before navigating
  //                   if (mounted) {
  //                     // Navigate to home screen without clearing the entire stack
  //                     Navigator.of(
  //                       context,
  //                     ).pushNamedAndRemoveUntil('/main', (route) => false);
  //                   }
  //                 } catch (e) {
  //                   log('Error ending session: $e');
  //                   // If there's an error, still try to navigate back
  //                   if (mounted) {
  //                     Navigator.of(
  //                       context,
  //                     ).pushNamedAndRemoveUntil('/main', (route) => false);
  //                   }
  //                 }
  //               },
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: Colors.red,
  //                 foregroundColor: Colors.white,
  //               ),
  //               child: const Text('End Session'),
  //             ),
  //           ],
  //         ),
  //   );
  // }
}
