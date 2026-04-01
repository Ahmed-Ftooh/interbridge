import 'dart:async';
import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  static const String _kRuntimeMarker = 'WEB_CALL_VIEW_MARKER_20260329_A';

  // ─── Twilio third-party call ──────────────────────────────────
  final TwilioCallService _twilioService = TwilioCallService();
  String? _patientCallSid;
  String _patientCallStatus = '';
  bool _isPatientCallLoading = false;

  // ─── Cached Agora video controllers ───────────────────────────
  VideoViewController? _localController;
  VideoViewController? _remoteController;
  int? _cachedRemoteUid;
  RtcEngine? _cachedEngine; // used for remote controller
  RtcEngine? _localCachedEngine; // separate cache to avoid sharing state

  // ─── Web: delay AgoraVideoView mount until camera track exists ─
  // After CallOngoing is first emitted for a video call the Iris Web
  // SDK needs ~2 s to finish creating the local camera track.  If
  // AgoraVideoView(uid:0) mounts before that, setupLocalVideo binds
  // to an empty track → black.  We keep the view hidden for a short
  // window, then mount it fresh so it finds the live track.
  bool _webVideoReady = false;
  Timer? _webVideoReadyTimer;
  bool? _lastVideoEnabled;

  // ─── Web: force remote AgoraVideoView to rebind after remote joins ──
  // The Iris Web SDK may not immediately bind the remote video track.
  // We schedule controller resets after short delays to force rebinding.
  Timer? _webRemoteVideoRetryTimer;
  int _remoteViewEpoch = 0;
  final Set<int> _remoteRetryScheduledUids = {};
  final Set<int> _remoteDecodeHandledUids = {};
  final Map<int, DateTime> _remoteFirstSeenAt = {};
  final Set<int> _forcedRenderableRemoteUids = {};
  Timer? _remoteRenderableWatchdogTimer;

  static const Duration _kForceRenderableDelay = Duration(seconds: 5);

  void _runRemoteRebindAttempt(int attempt, String reason) {
    if (!mounted) return;

    final currentState = context.read<CallBloc>().state;
    if (currentState is! CallOngoing || currentState.remoteUids.isEmpty) {
      return;
    }

    final engine = context.read<CallBloc>().engine;
    if (engine != null) {
      for (final uid in currentState.remoteUids) {
        engine.muteRemoteVideoStream(uid: uid, mute: false).catchError((err) {
          log(
            'Web: remote rebind attempt $attempt video unmute failed '
            '(reason=$reason, uid=$uid): $err',
          );
        });
        engine.muteRemoteAudioStream(uid: uid, mute: false).catchError((err) {
          log(
            'Web: remote rebind attempt $attempt audio unmute failed '
            '(reason=$reason, uid=$uid): $err',
          );
        });
      }
    }

    // Let the Agora engine handle track resizing natively.
    // Do NOT destroy the video controller/HTML element, as it breaks the Z-index!
    log(
      'Web: remote rebind attempt $attempt (reason=$reason). Keeping controller stable.',
    );
  }

  void _scheduleRemoteRebindSequence(String reason) {
    _webRemoteVideoRetryTimer?.cancel();

    // Short-first retries recover common web track-bind races quickly
    // while keeping bounded retries for slower remote publishes.
    final delays = <int>[250, 900, 2200];
    var index = 0;

    void scheduleNext(int delayMs) {
      _webRemoteVideoRetryTimer = Timer(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        _runRemoteRebindAttempt(index + 1, reason);

        if (index < delays.length - 1) {
          final current = delays[index];
          index += 1;
          final next = delays[index];
          scheduleNext(next - current);
        }
      });
    }

    scheduleNext(delays.first);
  }

  bool _hasRenderableRemote(CallOngoing state) {
    return state.remoteUids
            .intersection(state.remoteVideoReadyUids)
            .isNotEmpty ||
        state.remoteUids.any(_forcedRenderableRemoteUids.contains);
  }

  void _cancelRemoteRenderableWatchdog() {
    _remoteRenderableWatchdogTimer?.cancel();
    _remoteRenderableWatchdogTimer = null;
  }

  void _refreshRemoteRenderableWatchdog(CallOngoing state) {
    _remoteFirstSeenAt.removeWhere((uid, _) => !state.remoteUids.contains(uid));
    _forcedRenderableRemoteUids.removeWhere(
      (uid) => !state.remoteUids.contains(uid),
    );

    if (state.remoteUids.isEmpty || _hasRenderableRemote(state)) {
      _cancelRemoteRenderableWatchdog();
      return;
    }

    final now = DateTime.now();
    for (final uid in state.remoteUids) {
      _remoteFirstSeenAt.putIfAbsent(uid, () => now);
    }

    _remoteRenderableWatchdogTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final currentState = context.read<CallBloc>().state;
        if (currentState is! CallOngoing || !currentState.isVideoCall) {
          _cancelRemoteRenderableWatchdog();
          return;
        }

        _remoteFirstSeenAt.removeWhere(
          (uid, _) => !currentState.remoteUids.contains(uid),
        );
        _forcedRenderableRemoteUids.removeWhere(
          (uid) => !currentState.remoteUids.contains(uid),
        );

        if (currentState.remoteUids.isEmpty ||
            _hasRenderableRemote(currentState)) {
          _cancelRemoteRenderableWatchdog();
          return;
        }

        final tickNow = DateTime.now();
        final forcedNow = <int>[];
        for (final uid in currentState.remoteUids) {
          final seenAt = _remoteFirstSeenAt.putIfAbsent(uid, () => tickNow);
          final waitingLong =
              tickNow.difference(seenAt) >= _kForceRenderableDelay;
          if (waitingLong && !_forcedRenderableRemoteUids.contains(uid)) {
            _forcedRenderableRemoteUids.add(uid);
            forcedNow.add(uid);
          }
        }

        if (forcedNow.isNotEmpty) {
          log(
            'Web watchdog: forcing remote render for uids=${forcedNow.join(',')} after ${_kForceRenderableDelay.inMilliseconds}ms',
          );
          _runRemoteRebindAttempt(
            99,
            'watchdog_force_render_${forcedNow.join('_')}',
          );
          setState(() {});
        }
      },
    );
  }

  // ─── Controls visibility (auto-hide after 4s) ────────────────
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // ─── Pulse animation for connecting state ─────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // ─── Controller helpers ──────────────────────────────────────
  VideoViewController _getLocalController(RtcEngine engine) {
    if (_localController == null || _localCachedEngine != engine) {
      _localController?.dispose();
      _localCachedEngine = engine;
      _localController = VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeFit,
        ),
        useFlutterTexture: false,
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
          renderMode: RenderModeType.renderModeFit,
        ),
        connection: RtcConnection(channelId: channelId),
        useFlutterTexture: false,
      );
    }
    return _remoteController!;
  }

  // ─── Lifecycle ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    log(
      '$_kRuntimeMarker: init channel=${widget.channelId}, video=${widget.isVideoCall}',
    );
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
    _webVideoReadyTimer?.cancel();
    _webRemoteVideoRetryTimer?.cancel();
    _cancelRemoteRenderableWatchdog();
    _remoteRetryScheduledUids.clear();
    _remoteDecodeHandledUids.clear();
    _remoteFirstSeenAt.clear();
    _forcedRenderableRemoteUids.clear();
    _localController?.dispose();
    _remoteController?.dispose();
    if (_patientCallSid != null) {
      _twilioService.endCall(_patientCallSid!);
    }
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();

    // Keep controls pinned on web. HTML video views can capture pointer
    // events and prevent hover/tap from restoring hidden controls.
    if (kIsWeb) {
      if (!_controlsVisible) {
        setState(() => _controlsVisible = true);
      }
      return;
    }

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
                const Text(
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
      // Only fire the listener when the relevant fields change:
      // - any non-CallOngoing state transition (CallEnded, CallError, etc.)
      // - videoEnabled toggled within CallOngoing
      // Timer ticks (elapsed) are filtered out so they don't reset state.
      listenWhen: (prev, curr) {
        if (prev is CallOngoing && curr is CallOngoing) {
          return prev.videoEnabled != curr.videoEnabled ||
              prev.remoteUids.length != curr.remoteUids.length ||
              prev.remoteVideoReadyUids.length !=
                  curr.remoteVideoReadyUids.length;
        }
        return true;
      },
      listener: (context, state) {
        if (state is CallEnded) {
          _webVideoReadyTimer?.cancel();
          _webVideoReadyTimer = null;
          _webRemoteVideoRetryTimer?.cancel();
          _webRemoteVideoRetryTimer = null;
          _localController?.dispose();
          _localController = null;
          _localCachedEngine = null;
          _webVideoReady = false;
          _lastVideoEnabled = null;
          _remoteRetryScheduledUids.clear();
          _remoteDecodeHandledUids.clear();
          _remoteFirstSeenAt.clear();
          _forcedRenderableRemoteUids.clear();
          _cancelRemoteRenderableWatchdog();
          _remoteViewEpoch = 0;
          _showFeedbackAndNavigateHome();
        } else if (state is CallConnecting) {
          _webVideoReadyTimer?.cancel();
          _webVideoReadyTimer = null;
          _webRemoteVideoRetryTimer?.cancel();
          _webRemoteVideoRetryTimer = null;
          _localController?.dispose();
          _localController = null;
          _localCachedEngine = null;
          _webVideoReady = false;
          _lastVideoEnabled = null;
          _remoteRetryScheduledUids.clear();
          _remoteDecodeHandledUids.clear();
          _remoteFirstSeenAt.clear();
          _forcedRenderableRemoteUids.clear();
          _cancelRemoteRenderableWatchdog();
          _remoteViewEpoch = 0;
        } else if (state is CallError) {
          log('CallScreen: error — ${state.error.message}');
        } else if (state is CallOngoing && state.isVideoCall) {
          final wasVideoEnabled = _lastVideoEnabled;
          final videoJustEnabled =
              (wasVideoEnabled != null && !wasVideoEnabled && state.videoEnabled);
          _lastVideoEnabled = state.videoEnabled;

          _remoteRetryScheduledUids.removeWhere(
            (uid) => !state.remoteUids.contains(uid),
          );
          _remoteDecodeHandledUids.removeWhere(
            (uid) => !state.remoteUids.contains(uid),
          );
          _remoteFirstSeenAt.removeWhere(
            (uid, _) => !state.remoteUids.contains(uid),
          );
          _forcedRenderableRemoteUids.removeWhere(
            (uid) => !state.remoteUids.contains(uid),
          );

          final unreadyUids = state.remoteUids
              .difference(state.remoteVideoReadyUids)
              .difference(_remoteRetryScheduledUids)
              .difference(_remoteDecodeHandledUids);
          if (unreadyUids.isNotEmpty) {
            _remoteRetryScheduledUids.addAll(unreadyUids);
            _scheduleRemoteRebindSequence(
              'remote_unready_${unreadyUids.join('_')}',
            );
          }

          final newlyReadyUids = state.remoteVideoReadyUids.difference(
            _remoteDecodeHandledUids,
          );
          if (newlyReadyUids.isNotEmpty) {
            _remoteDecodeHandledUids.addAll(newlyReadyUids);
            _remoteRetryScheduledUids.removeAll(newlyReadyUids);
            _forcedRenderableRemoteUids.removeAll(newlyReadyUids);
            for (final uid in newlyReadyUids) {
              _remoteFirstSeenAt.remove(uid);
            }
            _webRemoteVideoRetryTimer?.cancel();
            _webRemoteVideoRetryTimer = null;
            _runRemoteRebindAttempt(
              0,
              'remote_decode_ready_${newlyReadyUids.join('_')}',
            );
          }

          if (state.remoteUids.isEmpty) {
            _webRemoteVideoRetryTimer?.cancel();
            _webRemoteVideoRetryTimer = null;
            _remoteRetryScheduledUids.clear();
            _remoteDecodeHandledUids.clear();
            _remoteFirstSeenAt.clear();
            _forcedRenderableRemoteUids.clear();
            _cancelRemoteRenderableWatchdog();
          } else {
            _refreshRemoteRenderableWatchdog(state);
          }

          if (!_webVideoReady) {
            // Initial join: wait for the Iris Web SDK to finish
            // creating the camera track, then mount AgoraVideoView
            // fresh so setupLocalVideo finds a live track.
            _webVideoReadyTimer ??= Timer(
              const Duration(milliseconds: 600),
              () {
                if (!mounted) return;
                log(
                  'Web: camera track should be ready — mounting AgoraVideoView',
                );
                setState(() {
                  _localController?.dispose(); // discard stale controller
                  _localController = null;
                  _webVideoReady = true;
                });
                // After AgoraVideoView is in the DOM, force the Iris SDK
                // to re-enable the track AND rebind it to the HTML element.
                // muteLocalVideoStream alone only controls publishing;
                // enableLocalVideo recreates the track binding.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 120), () {
                    if (!mounted) return;
                    final engine = context.read<CallBloc>().engine;
                    if (engine != null) {
                      engine.enableLocalVideo(true).catchError((_) {});
                      engine.muteLocalVideoStream(false).catchError((_) {});
                      engine.startPreview().catchError((_) {});
                    }
                  });
                });
              },
            );
          } else if (videoJustEnabled) {
            // Video was just re-enabled after being turned off.
            // The old AgoraVideoView was removed from the tree when
            // videoEnabled=false, so its HTML <video> element is gone.
            // Reset the cached controller so a new VideoViewController
            // (fresh HTML element) is created on remount, and tell the
            // Iris SDK to rebind the camera track to that new element.
            _webVideoReadyTimer?.cancel();
            _webVideoReadyTimer = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() {
                _localController?.dispose();
                _localController = null;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final engine = context.read<CallBloc>().engine;
                if (engine != null) {
                  engine.enableLocalVideo(true).catchError((_) {});
                  engine.muteLocalVideoStream(false).catchError((_) {});
                  engine.startPreview().catchError((_) {});
                }
              });
            });
          }
        }
      },
      // Skip rebuilds when only elapsed changes — the timer widget
      // uses its own BlocSelector so the video views stay stable.
      buildWhen: (prev, curr) {
        if (prev is CallOngoing && curr is CallOngoing) {
          return prev.remoteUids.length != curr.remoteUids.length ||
              prev.remoteVideoReadyUids.length !=
                  curr.remoteVideoReadyUids.length ||
              prev.muted != curr.muted ||
              prev.speakerOn != curr.speakerOn ||
              prev.videoEnabled != curr.videoEnabled ||
              prev.isVideoCall != curr.isVideoCall ||
              prev.startTime != curr.startTime;
        }
        return true; // Always rebuild on state type change
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
            child: const Icon(Icons.error_outline, color: _kEndRed, size: 48),
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call_end, color: _kTextSecondary, size: 48),
          SizedBox(height: 16),
          Text(
            'Call Ended',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(color: _kAccentBlue),
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
                      decoration: const BoxDecoration(
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
    final hasRenderableRemote = _hasRenderableRemote(state);
    final isVideo = state.isVideoCall;

    return Stack(
      children: [
        // ── Background: remote video / avatar ──────────────────
        // Pass hasRemote (not hasRenderableRemote) so background reserves
        // space for remote even before decode-ready, and local video can
        // be sized as PiP.
        Positioned.fill(
          child: _buildBackground(
            engine,
            state,
            hasRemote,
            hasRenderableRemote,
          ),
        ),

        // ── "Waiting for others" overlay (no remote yet) ───────
        if (isVideo && !hasRenderableRemote)
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
                  'Waiting for remote video...',
                  style: TextStyle(color: _kTextSecondary, fontSize: 14),
                ),
              ),
            ),
          ),

        // ── Loading spinner while camera track initialises ─────
        if (isVideo &&
            state.videoEnabled &&
            engine != null &&
            !_webVideoReady &&
            !hasRenderableRemote)
          const Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _kAccentBlue),
                  SizedBox(height: 16),
                  Text(
                    'Starting camera...',
                    style: TextStyle(color: _kTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // ── LOCAL VIDEO — single Positioned, geometry changes ───
        // The AgoraVideoView stays at the SAME child index in the
        // Stack so Flutter updates the Positioned in place rather
        // than unmounting / remounting (which destroys the HTML
        // <video> element on web and loses the camera track).
        // Use hasRemote to determine sizing: if any remote joined, show
        // local as PiP; otherwise full-screen.
        if (isVideo && state.videoEnabled && engine != null && _webVideoReady)
          Positioned(
            left: hasRemote ? null : 0,
            top: hasRemote ? 80 : 0,
            right: hasRemote ? 16 : 0,
            bottom: hasRemote ? null : 0,
            width: hasRemote ? 180 : null,
            height: hasRemote ? 135 : null,
            child: Container(
              decoration:
                  hasRemote
                      ? BoxDecoration(
                        border: Border.all(color: _kSurfaceLight, width: 2),
                      )
                      : null,
              child: _buildLocalVideoView(engine),
            ),
          ),

        // ── PiP decoration overlay (border + "You" label) ──────
        // Show PiP decoration when remote is joined (hasRemote=true)
        if (isVideo && state.videoEnabled && hasRemote && _webVideoReady)
          Positioned(
            right: 16,
            top: 80,
            child: IgnorePointer(
              child: Container(
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
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
            ),
          ),

        // ── Top info bar ───────────────────────────────────────
        Positioned(
          top: _controlsVisible ? 0 : -80,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _controlsVisible ? 1.0 : 0.0,
            child: _buildTopBar(state),
          ),
        ),

        // ── Third-party call chip ─────────────────────────────
        if (_patientCallSid != null || _patientCallStatus.isNotEmpty)
          Positioned(top: 72, left: 0, right: 0, child: _buildThirdPartyChip()),

        // ── Floating control bar (bottom center) ─────────────
        Positioned(
          bottom: _controlsVisible ? 24 : -100,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _controlsVisible ? 1.0 : 0.0,
            child: _buildFloatingControlBar(context, state),
          ),
        ),
      ],
    );
  }

  // ─── Background area (remote video or avatar) ───────────────
  Widget _buildBackground(
    RtcEngine? engine,
    CallOngoing state,
    bool hasRemote,
    bool hasRenderableRemote,
  ) {
    if (!state.isVideoCall) {
      return Center(child: _buildVoiceAvatar(hasRemote));
    }

    // Keep the remote view mounted whenever a remote user is present.
    // This avoids losing the underlying HTML target element on web and
    // prevents Agora from falling back to document.body.
    if (hasRemote && engine != null) {
      final remoteUid = state.remoteUids.firstWhere(
        (uid) =>
            state.remoteVideoReadyUids.contains(uid) ||
            _forcedRenderableRemoteUids.contains(uid),
        orElse: () => state.remoteUids.first,
      );
      try {
        final controller = _getRemoteController(
          engine,
          remoteUid,
          state.channelId,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            AgoraVideoView(
              key: ValueKey('remote-$remoteUid-$_remoteViewEpoch'),
              controller: controller,
            ),
            if (!hasRenderableRemote) _buildRemoteWaitingSurface(),
          ],
        );
      } catch (e) {
        log('CallScreen: AgoraVideoView (remote) error: $e');
        return Center(child: _buildVoiceAvatar(true));
      }
    }

    // No remote, video off → avatar
    if (!state.videoEnabled) {
      return Center(child: _buildVoiceAvatar(false));
    }
    // No remote, video on → transparent bg (local video rendered above)
    return const SizedBox.expand();
  }

  Widget _buildRemoteWaitingSurface() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgColor, _kSurfaceColor],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _kSurfaceColor.withAlpha(210),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kSurfaceLight),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kAccentBlue,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Connecting remote video...',
                style: TextStyle(color: _kTextSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Local AgoraVideoView (no GlobalKey, no wrapping) ──────
  Widget _buildLocalVideoView(RtcEngine engine) {
    try {
      return AgoraVideoView(controller: _getLocalController(engine));
    } catch (e) {
      log('CallScreen: local AgoraVideoView error: $e');
      return const Center(
        child: Icon(Icons.person, color: _kTextSecondary, size: 40),
      );
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
          // Duration — uses its own selector so timer ticks don't
          // rebuild the entire call screen (video views stay stable).
          BlocSelector<CallBloc, CallState, Duration>(
            selector:
                (state) => state is CallOngoing ? state.elapsed : Duration.zero,
            builder: (context, elapsed) {
              return Text(
                _fmt(elapsed),
                style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Encrypted badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kSurfaceColor.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: _kTextSecondary, size: 12),
                SizedBox(width: 4),
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
                  const Icon(
                    Icons.people_outline,
                    color: _kTextSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${state.remoteUids.length + 1}',
                    style: const TextStyle(
                      color: _kTextSecondary,
                      fontSize: 12,
                    ),
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
              const Icon(Icons.phone_in_talk, color: _kGreen, size: 16),
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
                  child: const Icon(Icons.call_end, color: _kEndRed, size: 14),
                ),
              ),
            ],
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call_end, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
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
