import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/config.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/core/web_media.dart';
import 'package:interbridge/presentation/services/call_state_manager.dart';

/// ===== Events =====
abstract class CallEvent {}

class StartCall extends CallEvent {
  final String channelId; // e.g., your requestId
  final int localUid; // stable int
  final bool isVideoCall; // true for video call, false for voice call
  StartCall({
    required this.channelId,
    required this.localUid,
    this.isVideoCall = false,
  });
}

class EndCall extends CallEvent {
  final bool isRemote;
  // Default to false, meaning it's a local hangup unless specified otherwise
  EndCall({this.isRemote = false});
}

class ToggleMute extends CallEvent {}

class ToggleSpeaker extends CallEvent {}

class ToggleVideo extends CallEvent {}

class SwitchCamera extends CallEvent {}

// internal events
class _RemoteUserJoined extends CallEvent {
  final int uid;
  _RemoteUserJoined(this.uid);
}

class _RemoteUserLeft extends CallEvent {
  final int uid;
  _RemoteUserLeft(this.uid);
}

class _RemoteVideoReady extends CallEvent {
  final int uid;
  _RemoteVideoReady(this.uid);
}

class _RemoteVideoStarting extends CallEvent {
  final int uid;
  final String reason;
  _RemoteVideoStarting(this.uid, this.reason);
}

class _RemoteVideoUnavailable extends CallEvent {
  final int uid;
  final String reason;
  final RemoteVideoStateReason? stateReason;
  final bool isTransient;
  final bool shouldRearmReadyFallback;
  _RemoteVideoUnavailable(
    this.uid,
    this.reason, {
    this.stateReason,
    this.isTransient = false,
    this.shouldRearmReadyFallback = false,
  });
}

class _Tick extends CallEvent {
  final Duration elapsed;
  _Tick(this.elapsed);
}

class _FallbackToOngoing extends CallEvent {
  final String channelId;
  final int localUid;
  _FallbackToOngoing({required this.channelId, required this.localUid});
}

class _JoinChannelSuccess extends CallEvent {
  final String channelId;
  final int localUid;
  _JoinChannelSuccess({required this.channelId, required this.localUid});
}

class _AgoraError extends CallEvent {
  final String message;
  _AgoraError(this.message);
}

class _ConnectionFailed extends CallEvent {}

/// ===== States =====
abstract class CallState {}

class CallIdle extends CallState {}

class CallConnecting extends CallState {
  final String channelId;
  CallConnecting(this.channelId);
}

class CallError extends CallState {
  final AppError error;
  CallError(this.error);
}

class CallOngoing extends CallState {
  final String channelId;
  final int localUid;
  final Set<int> remoteUids;
  final Set<int> remoteVideoReadyUids;
  final bool muted;
  final bool speakerOn;
  final Duration elapsed;
  final DateTime? startTime; // Added start time
  final bool isVideoCall; // true for video, false for voice
  final bool videoEnabled; // Whether local video is enabled

  CallOngoing({
    required this.channelId,
    required this.localUid,
    required this.remoteUids,
    required this.remoteVideoReadyUids,
    required this.muted,
    required this.speakerOn,
    required this.elapsed,
    this.startTime,
    this.isVideoCall = false,
    this.videoEnabled = false,
  });

  CallOngoing copyWith({
    Set<int>? remoteUids,
    Set<int>? remoteVideoReadyUids,
    bool? muted,
    bool? speakerOn,
    Duration? elapsed,
    DateTime? startTime,
    bool? videoEnabled,
  }) {
    return CallOngoing(
      channelId: channelId,
      localUid: localUid,
      remoteUids: remoteUids ?? this.remoteUids,
      remoteVideoReadyUids: remoteVideoReadyUids ?? this.remoteVideoReadyUids,
      muted: muted ?? this.muted,
      speakerOn: speakerOn ?? this.speakerOn,
      elapsed: elapsed ?? this.elapsed,
      startTime: startTime ?? this.startTime,
      isVideoCall: isVideoCall,
      videoEnabled: videoEnabled ?? this.videoEnabled,
    );
  }
}

class CallEnded extends CallState {
  final bool isRemote;
  CallEnded({this.isRemote = false});
}

/// ===== BLoC =====
class CallBloc extends Bloc<CallEvent, CallState> {
  final CallService service;
  RtcEngine? _engine;
  Timer? _timer;
  DateTime? _startedAt;
  bool _muted = false;
  bool _speakerOn = true;
  bool _videoEnabled = true;
  bool _isVideoCall = false;
  final Set<int> _remoteUids = {};
  final Set<int> _remoteVideoReadyUids = {};
  final Set<int> _remoteVideoStartingUids = {};
  final Map<int, Timer> _remoteVideoUnavailableTimers = {};
  final Map<int, Timer> _remoteVideoReadyFallbackTimers = {};
  final Map<int, int> _remoteReadyFallbackAttempts = {};

  static const Duration _kRemoteUnavailableGrace = Duration(milliseconds: 1200);
  static const Duration _kRemoteReadyFallback = Duration(seconds: 3);
  static const int _kMaxRemoteReadyFallbackAttempts = 4;
  static const String _kRuntimeMarker = 'CALL_BLOC_MARKER_20260329_A';

  /// Expose engine for video rendering in UI
  RtcEngine? get engine => _engine;

  CallBloc({required this.service}) : super(CallIdle()) {
    // This is where the error appeared
    on<StartCall>(_onStartCall);
    on<EndCall>(_onEndCall);
    on<ToggleMute>(_onToggleMute);
    on<ToggleSpeaker>(_onToggleSpeaker);
    on<ToggleVideo>(_onToggleVideo);
    on<SwitchCamera>(_onSwitchCamera);
    on<_RemoteUserJoined>(_onRemoteUserJoined);
    on<_RemoteUserLeft>(_onRemoteUserLeft);
    on<_RemoteVideoStarting>(_onRemoteVideoStarting);
    on<_RemoteVideoReady>(_onRemoteVideoReady);
    on<_RemoteVideoUnavailable>(_onRemoteVideoUnavailable);
    on<_Tick>(_onTick);
    on<_FallbackToOngoing>(_onFallbackToOngoing);
    on<_JoinChannelSuccess>(_onJoinChannelSuccess);
    on<_AgoraError>(_onAgoraError);
    on<_ConnectionFailed>(_onConnectionFailed);
  }

  Future<void> _onStartCall(StartCall e, Emitter<CallState> emit) async {
    try {
      if (e.channelId.trim().isEmpty) {
        emit(
          CallError(
            AppError(
              message: 'Invalid call channel',
              type: ErrorType.validation,
              userAction: 'Please start the request again.',
              isRetryable: false,
            ),
          ),
        );
        return;
      }

      final resolvedLocalUid = normalizeAgoraUid(e.localUid);
      if (resolvedLocalUid != e.localUid) {
        log(
          'Normalized localUid from ${e.localUid} to $resolvedLocalUid for channel ${e.channelId}',
        );
      }

      log(
        '$_kRuntimeMarker: StartCall channel=${e.channelId}, video=${e.isVideoCall}, localUid=$resolvedLocalUid',
      );

      // Notify global call state immediately so chat banner updates
      CallStateManager().startCall(e.channelId);

      // Store video call flag
      _isVideoCall = e.isVideoCall;
      _videoEnabled = e.isVideoCall; // Start with video on for video calls
      _remoteVideoReadyUids.clear();
      _remoteVideoStartingUids.clear();
      _cancelAllPendingRemoteUnavailable();
      _cancelAllPendingRemoteReadyFallback();
      _remoteReadyFallbackAttempts.clear();

      // 1) Request microphone/camera permission
      if (!kIsWeb) {
        log('Requesting microphone permission...');
        var mic = await Permission.microphone.status;
        if (!mic.isGranted) {
          mic = await Permission.microphone.request();
        }
        if (!mic.isGranted) {
          log(
            'Microphone permission not granted. Please enable in app settings.',
          );
          emit(
            CallError(
              AppError(
                message: 'Microphone permission required',
                type: ErrorType.permission,
                userAction:
                    'Please enable microphone permission in app settings to make voice calls.',
                isRetryable: false,
              ),
            ),
          );
          return;
        }
        log('Microphone permission granted');

        // 1b) Request camera permission for video calls
        if (e.isVideoCall) {
          log('Requesting camera permission...');
          var camera = await Permission.camera.status;
          if (!camera.isGranted) {
            camera = await Permission.camera.request();
          }
          if (!camera.isGranted) {
            log(
              'Camera permission not granted. Please enable in app settings.',
            );
            emit(
              CallError(
                AppError(
                  message: 'Camera permission required',
                  type: ErrorType.permission,
                  userAction:
                      'Please enable camera permission in app settings to make video calls.',
                  isRetryable: false,
                ),
              ),
            );
            return;
          }
          log('Camera permission granted');
        }
      } else {
        // On web, explicitly trigger getUserMedia so the browser prompts for
        // BOTH mic and camera (if video call). This avoids cases where only
        // the mic prompt appears and the camera track never initializes.
        try {
          await requestWebMediaPermissions(video: e.isVideoCall);
          log('Web: media permissions granted');
          stopWebMediaTracks();
        } catch (err) {
          log('Web: media permission request failed: $err');
          emit(
            CallError(
              AppError(
                message: 'Camera/microphone permission required',
                type: ErrorType.permission,
                userAction:
                    'Please allow camera and microphone access in the browser.',
                isRetryable: false,
              ),
            ),
          );
          return;
        }
      }

      emit(CallConnecting(e.channelId));

      // 2) Init engine (ensure fresh instance)
      log('Initializing Agora RTC Engine...');
      if (_engine != null) {
        log('Releasing existing engine instance...');
        try {
          if (kIsWeb) {
            await _engine!.release().timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                log(
                  'Web: engine.release timed out — continuing with new engine',
                );
              },
            );
          } else {
            await _engine!.release();
          }
        } catch (e) {
          log('Error releasing engine: $e');
        }
        _engine = null;
      }

      try {
        _engine = createAgoraRtcEngine();
        log('createAgoraRtcEngine() succeeded');
      } catch (createErr) {
        log('FATAL: createAgoraRtcEngine() failed: $createErr');
        emit(
          CallError(
            AppError(
              message: 'Failed to create call engine: $createErr',
              type: ErrorType.unknown,
              userAction: 'Please refresh the page and try again.',
              isRetryable: true,
            ),
          ),
        );
        return;
      }

      // Check if Agora App ID is properly configured
      final appId = agoraAppId;
      if (appId.isEmpty || appId == 'PLACEHOLDER_AGORA_APP_ID') {
        log('Agora App ID not configured: $appId');
        emit(
          CallError(
            AppError(
              message: 'Voice calling not configured',
              type: ErrorType.server,
              userAction:
                  'Please check your environment configuration and try again.',
              isRetryable: false,
            ),
          ),
        );
        return;
      }
      log('Agora App ID: ${appId.substring(0, 8)}...');

      try {
        await _engine!.initialize(RtcEngineContext(appId: appId));
        log('Agora RTC Engine initialized successfully');
      } catch (initErr) {
        log('FATAL: engine.initialize() failed: $initErr');
        _engine = null;
        emit(
          CallError(
            AppError(
              message: 'Failed to initialize call engine: $initErr',
              type: ErrorType.unknown,
              userAction: 'Please refresh the page and try again.',
              isRetryable: true,
            ),
          ),
        );
        return;
      }

      // 3) Handlers
      // 3) Handlers — ALL callbacks use add() so they work even after
      //    _onStartCall returns (critical on web where joinChannel is
      //    fire-and-forget).
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            log('Successfully joined channel: ${e.channelId}');
            add(
              _JoinChannelSuccess(
                channelId: e.channelId,
                localUid: resolvedLocalUid,
              ),
            );
          },
          onError: (errorCode, errorMsg) {
            log('Agora RTC Engine error: $errorCode - $errorMsg');
            // On web the Iris bridge fires many non-fatal errors (device
            // warnings, network quality, internal retries).  Only fatal
            // errors should crash the call.
            final fatal = {
              ErrorCodeType.errFailed,
              ErrorCodeType.errInvalidAppId,
              ErrorCodeType.errInvalidToken,
              ErrorCodeType.errTokenExpired,
              ErrorCodeType.errInvalidChannelName,
              ErrorCodeType.errJoinChannelRejected,
              ErrorCodeType.errNotInitialized,
            };
            if (fatal.contains(errorCode)) {
              add(_AgoraError('Call error: $errorMsg'));
            } else {
              log('Agora non-fatal error (ignored): $errorCode');
            }
          },
          onConnectionStateChanged: (connection, state, reason) {
            log('Connection state changed: $state, reason: $reason');
            if (state == ConnectionStateType.connectionStateFailed) {
              add(_ConnectionFailed());
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            log('Remote user joined: $remoteUid');
            add(_RemoteUserJoined(remoteUid));
          },
          onUserOffline: (connection, remoteUid, reason) {
            log('Remote user left: $remoteUid, reason: $reason');
            add(_RemoteUserLeft(remoteUid));
          },
          onRemoteVideoStateChanged: (
            connection,
            remoteUid,
            state,
            reason,
            elapsed,
          ) {
            log(
              'Remote video state changed: uid=$remoteUid, state=$state, reason=$reason',
            );
            if (kIsWeb && _isVideoCall) {
              if (state == RemoteVideoState.remoteVideoStateStarting) {
                add(_RemoteVideoStarting(remoteUid, '$reason'));
              } else if (state == RemoteVideoState.remoteVideoStateDecoding) {
                add(_RemoteVideoReady(remoteUid));
              } else if (state == RemoteVideoState.remoteVideoStateFailed ||
                  state == RemoteVideoState.remoteVideoStateStopped ||
                  state == RemoteVideoState.remoteVideoStateFrozen) {
                final intentionalStop = _isIntentionalRemoteVideoStop(reason);
                final recoverableReason = _isRecoverableRemoteVideoReason(
                  reason,
                );

                final transientState =
                    !intentionalStop &&
                    (state == RemoteVideoState.remoteVideoStateStopped ||
                        state == RemoteVideoState.remoteVideoStateFrozen ||
                        recoverableReason);

                add(
                  _RemoteVideoUnavailable(
                    remoteUid,
                    '$state/$reason',
                    stateReason: reason,
                    isTransient: transientState,
                    shouldRearmReadyFallback: recoverableReason,
                  ),
                );
              }
            }
          },
          onFirstRemoteVideoDecoded: (
            connection,
            remoteUid,
            width,
            height,
            elapsed,
          ) {
            if (kIsWeb && _isVideoCall) {
              log(
                'First remote video decoded: uid=$remoteUid, ${width}x$height, elapsed=${elapsed}ms',
              );
              add(_RemoteVideoReady(remoteUid));
            }
          },
          onFirstRemoteVideoFrame: (
            connection,
            remoteUid,
            width,
            height,
            elapsed,
          ) {
            if (kIsWeb && _isVideoCall) {
              log(
                'First remote video frame: uid=$remoteUid, ${width}x$height, elapsed=${elapsed}ms',
              );
              add(_RemoteVideoReady(remoteUid));
            }
          },
        ),
      );

      // 4) Audio/Video configuration
      //    We configure tracks identically on mobile and web *before*
      //    calling joinChannel. The web media tracks have already
      //    been permitted in the explicit request above.
      try {
        await _engine!.enableAudio();
        log('enableAudio() succeeded');
      } catch (audioErr) {
        log('Warning: enableAudio failed: $audioErr');
      }

      try {
        await _engine!.enableLocalAudio(true);
      } catch (audioErr) {
        log('Warning: enableLocalAudio failed: $audioErr');
      }

      try {
        await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileSpeechStandard,
        );
      } catch (audioProfileErr) {
        log('Warning: setAudioProfile failed: $audioProfileErr');
      }

      if (!kIsWeb) {
        try {
          await _engine!.setAudioScenario(
            AudioScenarioType.audioScenarioMeeting,
          );
        } catch (audioScenarioErr) {
          log('Warning: setAudioScenario failed: $audioScenarioErr');
        }
      }

      // Only mobile supports these specific audio routing controls
      if (!kIsWeb) {
        try {
          await _engine!.setDefaultAudioRouteToSpeakerphone(e.isVideoCall);
        } catch (err) {
          log('Warning: setDefaultAudioRouteToSpeakerphone failed: $err');
        }
      }

      if (e.isVideoCall) {
        log('Enabling video for video call...');
        try {
          await _engine!.enableVideo();
          log('enableVideo() succeeded');
        } catch (enableVideoErr) {
          log('Warning: enableVideo failed: $enableVideoErr');
        }

        try {
          await _engine!.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 1920, height: 1080),
              frameRate: 30,
              bitrate: 4000,
              minBitrate: 1000,
              orientationMode: OrientationMode.orientationModeAdaptive,
              degradationPreference: DegradationPreference.maintainQuality,
              mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
            ),
          );
        } catch (videoConfigErr) {
          log('Warning: Could not set video encoder config: $videoConfigErr');
        }

        try {
          await _engine!.enableLocalVideo(true);
        } catch (localVideoErr) {
          log('Warning: enableLocalVideo failed: $localVideoErr');
        }

        try {
          await _engine!.muteLocalVideoStream(false);
        } catch (unmuteVideoErr) {
          log('Warning: muteLocalVideoStream(false) failed: $unmuteVideoErr');
        }

        try {
          await _engine!.startPreview();
        } catch (previewErr) {
          log('Warning: startPreview failed: $previewErr');
        }

        _speakerOn = true;
      } else {
        _speakerOn = false;
      }

      try {
        await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        );
      } catch (roleErr) {
        log('Warning: setClientRole failed: $roleErr');
      }

      try {
        await _engine!.muteLocalAudioStream(_muted);
      } catch (muteErr) {
        log('Warning: muteLocalAudioStream failed: $muteErr');
      }

      if (!kIsWeb) {
        try {
          await _engine!.setEnableSpeakerphone(_speakerOn);
        } catch (e) {
          log('Warning: Could not set speakerphone: $e');
        }
      }

      // 5) Token from Supabase with timeout
      log(
        'Fetching Agora token for channel: ${e.channelId}, uid: $resolvedLocalUid',
      );
      String token;
      try {
        token = await service
            .fetchAgoraToken(channelName: e.channelId, uid: resolvedLocalUid)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                log('Token fetch timeout after 15 seconds');
                throw Exception(
                  'Failed to get voice call token. Please try again.',
                );
              },
            );
        log('Successfully obtained Agora token (length: ${token.length})');
      } catch (tokenErr) {
        log('Error fetching Agora token: $tokenErr');
        emit(
          CallError(ErrorHandler.handleError(tokenErr, context: 'FetchToken')),
        );
        return;
      }

      // 6) Join channel
      //    On web the Agora Iris bridge triggers getUserMedia (browser
      //    permission prompt) during joinChannel, which can take an
      //    unpredictable amount of time.  Applying a short timeout
      //    causes false failures.  We rely on the registered
      //    onJoinChannelSuccess / onError callbacks and the fallback
      //    timer below to drive state transitions instead.
      log('Joining Agora channel: ${e.channelId}');
      try {
        final future = _engine!.joinChannel(
          token: token,
          channelId: e.channelId,
          uid: resolvedLocalUid,
          options: ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: e.isVideoCall,
            publishMicrophoneTrack: true,
            autoSubscribeVideo: e.isVideoCall,
            autoSubscribeAudio: true,
          ),
        );

        if (kIsWeb) {
          // Fire and forget on web because it can hang waiting for permissions
          future.catchError((err) {
            log('Web: joinChannel error: $err');
            add(_AgoraError('Failed to join call: $err'));
          });
        } else {
          await future.timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              log('Join channel timeout after 15 seconds');
              throw Exception(
                'Voice call connection timeout. Please try again.',
              );
            },
          );
          log('Successfully joined Agora channel');
        }
      } catch (err) {
        log('Join channel error: $err');
        add(_AgoraError('Failed to join call: $err'));
      }

      // Fallback: If onJoinChannelSuccess doesn't fire within a
      // reasonable window, transition to CallOngoing so the user sees
      // the call screen instead of being stuck on "Connecting...".
      // On web we give extra time because the browser permission
      // dialog and WebRTC ICE negotiation can be slow.
      final fallbackSeconds = kIsWeb ? 12 : 5;
      Timer(Duration(seconds: fallbackSeconds), () {
        if (state is CallConnecting) {
          log(
            'Fallback: Manually transitioning to CallOngoing state (timer waits for remote user)',
          );
          // Use add() to trigger a new event instead of emit()
          add(
            _FallbackToOngoing(
              channelId: e.channelId,
              localUid: resolvedLocalUid,
            ),
          );
        }
      });
    } catch (e) {
      log('Error starting call: $e');

      if (kIsWeb && e.toString().contains('AgoraRtcException(-4')) {
        emit(
          CallError(
            AppError(
              message: 'Browser call setup not supported for this operation',
              type: ErrorType.unknown,
              userAction:
                  'Please retry the call. If it keeps failing, refresh the page and try again.',
              technicalDetails: e.toString(),
              isRetryable: true,
            ),
          ),
        );
        return;
      }

      emit(CallError(ErrorHandler.handleError(e, context: 'StartCall')));
    }
  }

  Future<void> _onEndCall(EndCall e, Emitter<CallState> emit) async {
    log('Ending call... (isRemote: ${e.isRemote})');
    _timer?.cancel();
    _timer = null;

    // Record call duration before clearing
    Duration? callDuration;
    String? channelId;
    if (_startedAt != null && state is CallOngoing) {
      callDuration = DateTime.now().difference(_startedAt!);
      channelId = (state as CallOngoing).channelId;
      await _recordCallDuration(
        callDuration,
        channelId: channelId,
        isRemoteHangup: e.isRemote,
      );
    }

    _startedAt = null;
    _remoteUids.clear();
    _remoteVideoReadyUids.clear();
    _remoteVideoStartingUids.clear();
    _cancelAllPendingRemoteUnavailable();
    _cancelAllPendingRemoteReadyFallback();
    _remoteReadyFallbackAttempts.clear();

    // Stop local camera capture/preview deterministically on all platforms,
    // specifically web where browser camera indicator can otherwise remain on.
    if (_isVideoCall) {
      await _stopLocalVideoCapture();
    }

    // Stop the explicit web media tracks (if on web)
    if (kIsWeb) {
      stopWebMediaTracks();
    }

    // Reset video state
    _isVideoCall = false;
    _videoEnabled = false;

    // Leave the channel and emit the final state.
    try {
      log('Leaving Agora channel...');
      if (kIsWeb) {
        // On web, use .catchError() + .timeout() to avoid debugger
        // breaks. The error stays in the Future chain.
        await _engine
            ?.leaveChannel()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                log('Web: leaveChannel timed out after 3s — continuing');
              },
            )
            .catchError((err) {
              log('Web: leaveChannel error (ignored): $err');
            });
      } else {
        await _engine?.leaveChannel();
      }
      log('Successfully left Agora channel');
    } catch (e) {
      log('Error leaving channel: $e');
    } finally {
      // Ensure global call banner clears for everyone
      CallStateManager().endCall();
      log('Emitting CallEnded state');
      emit(CallEnded(isRemote: e.isRemote));
    }
  }

  Future<void> _onToggleMute(ToggleMute e, Emitter<CallState> emit) async {
    _muted = !_muted;
    try {
      await _engine?.muteLocalAudioStream(_muted);
    } catch (err) {
      log('Warning: muteLocalAudioStream failed: $err');
      _muted = !_muted; // revert
    }
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(muted: _muted));
    }
  }

  Future<void> _onToggleSpeaker(
    ToggleSpeaker e,
    Emitter<CallState> emit,
  ) async {
    if (kIsWeb) {
      // setEnableSpeakerphone is not supported on web
      return;
    }
    _speakerOn = !_speakerOn;
    try {
      await _engine?.setEnableSpeakerphone(_speakerOn);
      // Adjust playback gain when speakerphone is on to mitigate room feedback
      if (_speakerOn) {
        await _engine?.adjustPlaybackSignalVolume(70);
      } else {
        await _engine?.adjustPlaybackSignalVolume(100);
      }
    } catch (e) {
      log('Warning: Could not toggle speakerphone: $e');
      // Revert the state if the operation failed
      _speakerOn = !_speakerOn;
    }
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(speakerOn: _speakerOn));
    }
  }

  Future<void> _onToggleVideo(ToggleVideo e, Emitter<CallState> emit) async {
    if (!_isVideoCall) return; // Only for video calls

    _videoEnabled = !_videoEnabled;
    try {
      // On web, when re-enabling video, explicitly recreate the camera
      // track via enableLocalVideo(true) BEFORE emitting the new state.
      // muteLocalVideoStream only controls publishing to remote peers;
      // enableLocalVideo is what makes the camera track bindable for
      // local preview (setupLocalVideo / AgoraVideoView on the UI side).
      if (kIsWeb && _videoEnabled) {
        await _engine?.enableLocalVideo(true).catchError((err) {
          log('Web: enableLocalVideo on re-enable (ignored): $err');
        });
      }
      await _engine?.muteLocalVideoStream(!_videoEnabled);
      // startPreview / stopPreview: renders the camera track into the
      // local HTML element (web) or SurfaceView (mobile).
      try {
        if (_videoEnabled) {
          await _engine?.startPreview();
        } else {
          await _engine?.stopPreview();
        }
      } catch (previewErr) {
        log(
          'Warning: preview toggle not supported on this platform: $previewErr',
        );
      }
    } catch (err) {
      log('Warning: Could not toggle video: $err');
      _videoEnabled = !_videoEnabled;
    }
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(videoEnabled: _videoEnabled));
    }
  }

  Future<void> _onSwitchCamera(SwitchCamera e, Emitter<CallState> emit) async {
    if (!_isVideoCall) return; // Only for video calls

    try {
      await _engine?.switchCamera();
    } catch (err) {
      log('Warning: Could not switch camera: $err');
    }
  }

  void _onRemoteUserJoined(_RemoteUserJoined e, Emitter<CallState> emit) {
    _remoteUids.add(e.uid);
    _remoteVideoReadyUids.remove(e.uid);
    _remoteVideoStartingUids.remove(e.uid);
    _remoteReadyFallbackAttempts.remove(e.uid);
    _cancelPendingRemoteUnavailable(e.uid);
    _scheduleRemoteReadyFallback(e.uid, requirePublishSignal: true);

    // On web, explicitly unmute / subscribe to the remote video stream.
    // autoSubscribeVideo in ChannelMediaOptions may not be sufficient on
    // the Iris Web SDK to actually bind remote tracks to views.
    if (kIsWeb && _isVideoCall && _engine != null) {
      log('Web: explicitly subscribing to remote video for uid=${e.uid}');
      // Unmute remote streams immediately
      _engine!.muteRemoteVideoStream(uid: e.uid, mute: false).catchError((err) {
        log('Web: muteRemoteVideoStream error (ignored): $err');
      });
      _engine!.muteRemoteAudioStream(uid: e.uid, mute: false).catchError((err) {
        log('Web: muteRemoteAudioStream error (ignored): $err');
      });
    }

    // Start timer if this is the first remote user and timer hasn't started
    if (_startedAt == null) {
      log('First remote user joined. Starting call timer.');
      _startedAt = DateTime.now();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_startedAt != null) {
          final elapsed = DateTime.now().difference(_startedAt!);
          add(_Tick(elapsed));
        }
      });
    }

    if (state is CallOngoing) {
      emit(
        (state as CallOngoing).copyWith(
          remoteUids: {..._remoteUids},
          remoteVideoReadyUids: {..._remoteVideoReadyUids},
          startTime: _startedAt, // Ensure start time is propagated
        ),
      );
    }
  }

  void _onRemoteUserLeft(_RemoteUserLeft e, Emitter<CallState> emit) {
    // Only auto-end the call if the departing user was actually tracked
    // (i.e. had previously joined). Spurious onUserOffline events for UIDs
    // that never joined (e.g. fired before onUserJoined after the 5-second
    // fallback) must not terminate the call.
    final wasTracked = _remoteUids.contains(e.uid);
    _remoteUids.remove(e.uid);
    _remoteVideoReadyUids.remove(e.uid);
    _remoteVideoStartingUids.remove(e.uid);
    _remoteReadyFallbackAttempts.remove(e.uid);
    _cancelPendingRemoteUnavailable(e.uid);
    _cancelPendingRemoteReadyFallback(e.uid);

    if (wasTracked && _remoteUids.isEmpty && state is CallOngoing) {
      log('Remote user left and no more participants - ending call');
      add(EndCall(isRemote: true));
      return;
    }

    if (state is CallOngoing) {
      emit(
        (state as CallOngoing).copyWith(
          remoteUids: {..._remoteUids},
          remoteVideoReadyUids: {..._remoteVideoReadyUids},
        ),
      );
    }
  }

  void _onRemoteVideoStarting(_RemoteVideoStarting e, Emitter<CallState> emit) {
    if (!_remoteUids.contains(e.uid)) return;

    final firstSignal = _remoteVideoStartingUids.add(e.uid);
    if (firstSignal) {
      log(
        'Remote video publish-start detected: uid=${e.uid}, reason=${e.reason}',
      );
    }

    if (!_remoteVideoReadyUids.contains(e.uid)) {
      _scheduleRemoteReadyFallback(e.uid, requirePublishSignal: false);
    }
  }

  void _onRemoteVideoReady(_RemoteVideoReady e, Emitter<CallState> emit) {
    _cancelPendingRemoteUnavailable(e.uid);
    _cancelPendingRemoteReadyFallback(e.uid);
    _remoteVideoStartingUids.add(e.uid);
    _remoteReadyFallbackAttempts.remove(e.uid);

    if (!_remoteUids.contains(e.uid)) return;
    if (_remoteVideoReadyUids.contains(e.uid)) return;

    _remoteVideoReadyUids.add(e.uid);
    log('Remote video ready for rendering: uid=${e.uid}');

    if (state is CallOngoing) {
      emit(
        (state as CallOngoing).copyWith(
          remoteVideoReadyUids: {..._remoteVideoReadyUids},
        ),
      );
    }
  }

  void _onRemoteVideoUnavailable(
    _RemoteVideoUnavailable e,
    Emitter<CallState> emit,
  ) {
    if (!_remoteUids.contains(e.uid)) return;

    final alreadyReady = _remoteVideoReadyUids.contains(e.uid);

    if (e.stateReason ==
            RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted ||
        e.stateReason ==
            RemoteVideoStateReason.remoteVideoStateReasonRemoteOffline) {
      _remoteVideoStartingUids.remove(e.uid);
      _remoteReadyFallbackAttempts.remove(e.uid);
    }

    if (alreadyReady) {
      if (e.shouldRearmReadyFallback) {
        _scheduleRemoteReadyFallback(e.uid, requirePublishSignal: false);
      } else {
        _cancelPendingRemoteReadyFallback(e.uid);
      }
    } else {
      // During first-bind phase, keep fallback alive unless remote is
      // explicitly offline. Some web SDK paths report muted/stopped before
      // decode-ready and would otherwise deadlock on "Connecting remote video".
      final definitelyOffline =
          e.stateReason ==
          RemoteVideoStateReason.remoteVideoStateReasonRemoteOffline;
      if (definitelyOffline) {
        _cancelPendingRemoteReadyFallback(e.uid);
      } else {
        _scheduleRemoteReadyFallback(e.uid, requirePublishSignal: true);
      }
    }

    if (e.isTransient) {
      if (_remoteVideoUnavailableTimers.containsKey(e.uid)) {
        return;
      }

      log(
        'Remote video transient unavailable: uid=${e.uid}, reason=${e.reason}. Waiting ${_kRemoteUnavailableGrace.inMilliseconds}ms before downgrade.',
      );
      _remoteVideoUnavailableTimers[e.uid] = Timer(
        _kRemoteUnavailableGrace,
        () {
          _remoteVideoUnavailableTimers.remove(e.uid);
          add(
            _RemoteVideoUnavailable(
              e.uid,
              '${e.reason}|grace_elapsed',
              stateReason: e.stateReason,
              isTransient: false,
              shouldRearmReadyFallback: e.shouldRearmReadyFallback,
            ),
          );
        },
      );
      return;
    }

    if (!alreadyReady) return;

    _remoteVideoReadyUids.remove(e.uid);
    log('Remote video unavailable: uid=${e.uid}, reason=${e.reason}');

    if (state is CallOngoing) {
      emit(
        (state as CallOngoing).copyWith(
          remoteVideoReadyUids: {..._remoteVideoReadyUids},
        ),
      );
    }
  }

  void _onTick(_Tick e, Emitter<CallState> emit) {
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(elapsed: e.elapsed));
    }
  }

  Future<void> _onFallbackToOngoing(
    _FallbackToOngoing e,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallConnecting) {
      log('Fallback ignored: state is ${state.runtimeType}');
      return;
    }

    log('Fallback handler: Transitioning to CallOngoing state');

    emit(
      CallOngoing(
        channelId: e.channelId,
        localUid: e.localUid,
        remoteUids: {..._remoteUids},
        remoteVideoReadyUids: {..._remoteVideoReadyUids},
        muted: _muted,
        speakerOn: _speakerOn,
        elapsed:
            _startedAt != null
                ? DateTime.now().difference(_startedAt!)
                : Duration.zero,
        startTime: _startedAt,
        isVideoCall: _isVideoCall,
        videoEnabled: _videoEnabled,
      ),
    );
  }

  Future<void> _onJoinChannelSuccess(
    _JoinChannelSuccess e,
    Emitter<CallState> emit,
  ) async {
    if (state is CallOngoing) {
      log('JoinChannelSuccess ignored: already in CallOngoing');
      return;
    }
    if (state is! CallConnecting) {
      log('JoinChannelSuccess ignored: state is ${state.runtimeType}');
      return;
    }

    log('Handler: onJoinChannelSuccess for channel: ${e.channelId}');
    _timer?.cancel();

    emit(
      CallOngoing(
        channelId: e.channelId,
        localUid: e.localUid,
        remoteUids: {..._remoteUids},
        remoteVideoReadyUids: {..._remoteVideoReadyUids},
        muted: _muted,
        speakerOn: _speakerOn,
        elapsed: Duration.zero,
        startTime: null, // Wait for remote user to start timer
        isVideoCall: _isVideoCall,
        videoEnabled: _videoEnabled,
      ),
    );
    log('CallOngoing state emitted successfully');
  }

  void _onAgoraError(_AgoraError e, Emitter<CallState> emit) {
    log('Handler: Agora error — ${e.message}');
    emit(
      CallError(
        AppError(
          message: e.message,
          type: ErrorType.network,
          userAction: 'Please check your internet connection and try again.',
          isRetryable: true,
        ),
      ),
    );
  }

  void _onConnectionFailed(_ConnectionFailed e, Emitter<CallState> emit) {
    log('Handler: Connection failed');
    emit(
      CallError(
        AppError(
          message: 'Voice call connection failed',
          type: ErrorType.network,
          userAction: 'Please check your internet connection and try again.',
          isRetryable: true,
        ),
      ),
    );
  }

  Future<void> _recordCallDuration(
    Duration duration, {
    required String channelId,
    bool isRemoteHangup = false,
  }) async {
    try {
      log(
        'Call duration: ${duration.inMinutes} minutes and ${duration.inSeconds.remainder(60)} seconds',
      );

      final userId = service.requireUserId();

      // Look up participants from interpreter_requests
      final participants = await service.lookupCallParticipants(channelId);
      final requesterId = participants?['requester_id'] as String?;
      final interpreterId = participants?['accepted_by'] as String?;
      final interpreterType = participants?['interpreter_type'] as String?;
      final fromLanguage = participants?['from_language'] as String?;
      final toLanguage = participants?['to_language'] as String?;
      final organizationId = participants?['organization_id'] as String?;

      // Determine remote user UUID
      String? remoteUserId;
      if (requesterId != null && interpreterId != null) {
        remoteUserId = (userId == interpreterId) ? requesterId : interpreterId;
      }

      // 1) Write call_sessions row (per-user)
      await service.recordCallDuration(
        channelId: channelId,
        duration: duration,
        userId: userId,
        remoteUserId: remoteUserId,
        callType: _isVideoCall ? 'video' : 'voice',
        endReason: isRemoteHangup ? 'remote_hangup' : 'user_hangup',
      );

      // 2) Write call_logs row (master record)
      //    BOTH sides attempt the insert. The DB has a unique constraint
      //    on request_id, so only the first succeeds; the second is a
      //    no-op (upsert).  This prevents lost logs when one side
      //    disconnects before the other.
      if (interpreterId != null && requesterId != null) {
        final now = DateTime.now();
        final startTime = now.subtract(duration);

        // Map interpreter_type to call_type enum: 'medical' → 'medical', else → 'humanitarian'
        final callLogType =
            (interpreterType == 'medical') ? 'medical' : 'humanitarian';

        await service.recordCallLog(
          requestId: channelId,
          interpreterId: interpreterId,
          requesterId: requesterId,
          durationSeconds: duration.inSeconds,
          startedAt: startTime,
          endedAt: now,
          callType: callLogType,
          fromLanguage: fromLanguage,
          toLanguage: toLanguage,
          organizationId: organizationId,
        );
      } else {
        log(
          'Warning: Could not write call_log — interpreterId=$interpreterId, requesterId=$requesterId',
        );
      }

      log('Call duration recorded: ${_formatDuration(duration)}');
    } catch (e) {
      log('Error recording call duration: $e');
    }
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

  Future<void> _stopLocalVideoCapture() async {
    final engine = _engine;
    if (engine == null) return;

    try {
      await engine.muteLocalVideoStream(true).catchError((err) {
        log('StopVideo: muteLocalVideoStream(true) error (ignored): $err');
      });

      await engine.enableLocalVideo(false).catchError((err) {
        log('StopVideo: enableLocalVideo(false) error (ignored): $err');
      });

      await engine.stopPreview().catchError((err) {
        log('StopVideo: stopPreview error (ignored): $err');
      });

      await engine.disableVideo().catchError((err) {
        log('StopVideo: disableVideo error (ignored): $err');
      });
    } catch (err) {
      log('StopVideo: unexpected error while stopping local video: $err');
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    _remoteVideoStartingUids.clear();
    _cancelAllPendingRemoteUnavailable();
    _cancelAllPendingRemoteReadyFallback();
    _remoteReadyFallbackAttempts.clear();

    // Best-effort camera shutdown before leave/release to avoid lingering
    // browser camera indicator if the bloc is disposed mid-call.
    await _stopLocalVideoCapture();

    try {
      if (kIsWeb) {
        // On web, leaveChannel / release can hang — use timeout + catchError
        // to prevent debugger breaks on caught exceptions.
        await _engine
            ?.leaveChannel()
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                log('Web: leaveChannel timed out in close()');
              },
            )
            .catchError((err) {
              log('Web: leaveChannel error in close() (ignored): $err');
            });
      } else {
        await _engine?.leaveChannel();
      }
    } catch (_) {}
    try {
      if (kIsWeb) {
        await _engine
            ?.release()
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                log('Web: engine.release timed out in close()');
              },
            )
            .catchError((err) {
              log('Web: engine.release error in close() (ignored): $err');
            });
      } else {
        await _engine?.release();
      }
    } catch (_) {}
    _engine = null;
    return super.close();
  }

  void _cancelPendingRemoteUnavailable(int uid) {
    _remoteVideoUnavailableTimers.remove(uid)?.cancel();
  }

  void _cancelAllPendingRemoteUnavailable() {
    for (final timer in _remoteVideoUnavailableTimers.values) {
      timer.cancel();
    }
    _remoteVideoUnavailableTimers.clear();
  }

  bool _isIntentionalRemoteVideoStop(RemoteVideoStateReason reason) {
    return reason == RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted ||
        reason == RemoteVideoStateReason.remoteVideoStateReasonRemoteOffline;
  }

  bool _isRecoverableRemoteVideoReason(RemoteVideoStateReason reason) {
    if (_isIntentionalRemoteVideoStop(reason)) {
      return false;
    }

    switch (reason) {
      case RemoteVideoStateReason.remoteVideoStateReasonInternal:
      case RemoteVideoStateReason.remoteVideoStateReasonNetworkCongestion:
      case RemoteVideoStateReason.remoteVideoStateReasonNetworkRecovery:
      case RemoteVideoStateReason.remoteVideoStateReasonLocalMuted:
      case RemoteVideoStateReason.remoteVideoStateReasonLocalUnmuted:
      case RemoteVideoStateReason.remoteVideoStateReasonRemoteUnmuted:
      case RemoteVideoStateReason.remoteVideoStateReasonAudioFallback:
      case RemoteVideoStateReason.remoteVideoStateReasonAudioFallbackRecovery:
        return true;
      case RemoteVideoStateReason.remoteVideoStateReasonCodecNotSupport:
        return false;
      default:
        return true;
    }
  }

  void _scheduleRemoteReadyFallback(
    int uid, {
    bool requirePublishSignal = true,
  }) {
    if (!(kIsWeb && _isVideoCall)) return;

    _cancelPendingRemoteReadyFallback(uid);
    _remoteVideoReadyFallbackTimers[uid] = Timer(_kRemoteReadyFallback, () {
      _remoteVideoReadyFallbackTimers.remove(uid);

      if (!_remoteUids.contains(uid) || _remoteVideoReadyUids.contains(uid)) {
        return;
      }

      final attempts = (_remoteReadyFallbackAttempts[uid] ?? 0) + 1;
      _remoteReadyFallbackAttempts[uid] = attempts;

      final sawPublishSignal = _remoteVideoStartingUids.contains(uid);
      if (requirePublishSignal && !sawPublishSignal) {
        if (attempts >= _kMaxRemoteReadyFallbackAttempts) {
          log(
            'Remote ready fallback aborted for uid=$uid after $attempts attempts without publish-start signal.',
          );
          return;
        }
        log(
          'Remote ready fallback waiting for publish-start signal: uid=$uid, attempt=$attempts/$_kMaxRemoteReadyFallbackAttempts.',
        );
        _scheduleRemoteReadyFallback(uid, requirePublishSignal: true);
        return;
      }

      log(
        'Remote video decode callback missing for uid=$uid; applying optimistic ready fallback after ${_kRemoteReadyFallback.inMilliseconds}ms (attempt=$attempts).',
      );
      add(_RemoteVideoReady(uid));
    });
  }

  void _cancelPendingRemoteReadyFallback(int uid) {
    _remoteVideoReadyFallbackTimers.remove(uid)?.cancel();
  }

  void _cancelAllPendingRemoteReadyFallback() {
    for (final timer in _remoteVideoReadyFallbackTimers.values) {
      timer.cancel();
    }
    _remoteVideoReadyFallbackTimers.clear();
  }
}
