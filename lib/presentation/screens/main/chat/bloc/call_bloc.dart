import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/config.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:interbridge/core/error_handler.dart';
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
    required this.muted,
    required this.speakerOn,
    required this.elapsed,
    this.startTime,
    this.isVideoCall = false,
    this.videoEnabled = false,
  });

  CallOngoing copyWith({
    Set<int>? remoteUids,
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
    on<_Tick>(_onTick);
    on<_FallbackToOngoing>(_onFallbackToOngoing);
    on<_JoinChannelSuccess>(_onJoinChannelSuccess);
    on<_AgoraError>(_onAgoraError);
    on<_ConnectionFailed>(_onConnectionFailed);
  }

  Future<void> _onStartCall(StartCall e, Emitter<CallState> emit) async {
    try {
      // Notify global call state immediately so chat banner updates
      CallStateManager().startCall(e.channelId);

      // Store video call flag
      _isVideoCall = e.isVideoCall;
      _videoEnabled = e.isVideoCall; // Start with video on for video calls

      // 1) Request microphone permission (skip on web — browser handles via getUserMedia)
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
        log(
          'Web platform: browser will handle media permissions via getUserMedia',
        );
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
      _engine = createAgoraRtcEngine();

      // Check if Agora App ID is properly configured
      String appId;
      try {
        appId = agoraAppId;
      } catch (err) {
        log('Agora App ID not configured: $err');
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

      await _engine!.initialize(RtcEngineContext(appId: appId));
      log('Agora RTC Engine initialized successfully');

      // 3) Handlers
      // 3) Handlers — ALL callbacks use add() so they work even after
      //    _onStartCall returns (critical on web where joinChannel is
      //    fire-and-forget).
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            log('Successfully joined channel: ${e.channelId}');
            add(
              _JoinChannelSuccess(channelId: e.channelId, localUid: e.localUid),
            );
          },
          onError: (errorCode, errorMsg) {
            log('Agora RTC Engine error: $errorCode - $errorMsg');
            add(_AgoraError('Voice call error: $errorMsg'));
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
        ),
      );

      // 4) Audio profile, scenario & route
      //    Skip all audio config on web — these APIs throw -4 (unsupported)
      //    and cause the debugger to break. joinChannel handles audio on web.
      if (!kIsWeb) {
        try {
          await _engine!.setAudioProfile(
            profile: AudioProfileType.audioProfileSpeechStandard,
          );
        } catch (audioProfileErr) {
          log('Warning: setAudioProfile failed: $audioProfileErr');
        }
        await _engine!.setAudioScenario(AudioScenarioType.audioScenarioMeeting);
        await _engine!.setDefaultAudioRouteToSpeakerphone(e.isVideoCall);
      }

      // On web, skip most SDK setup calls — they either throw (-4
      // unsupported) or conflict with joinChannel's getUserMedia.
      // joinChannel with publishMicrophoneTrack/publishCameraTrack
      // handles everything on web.
      if (!kIsWeb) {
        try {
          await _engine!.enableAudio();
          await _engine!.enableLocalAudio(true);
        } catch (audioErr) {
          log('Warning: enableAudio failed: $audioErr');
        }
      }

      // 4b) Enable video for video calls
      if (e.isVideoCall) {
        log('Enabling video for video call...');

        if (kIsWeb) {
          // On web, skip ALL SDK setup calls before joinChannel.
          // joinChannel with publishCameraTrack/publishMicrophoneTrack
          // handles camera and mic acquisition via getUserMedia.
          // Calling enableVideo/enableLocalVideo/startPreview before
          // joinChannel throws exceptions that break the debugger.
          // startPreview will be called in _onJoinChannelSuccess.
          log('Web: skipping all video setup — joinChannel handles it');
        } else {
          // Mobile: full setup
          try {
            await _engine!.enableVideo();
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
            await _engine!.startPreview();
          } catch (previewErr) {
            log('Warning: startPreview failed: $previewErr');
          }
        }
        _speakerOn = true; // Video calls default to speaker
      } else {
        _speakerOn = false; // Voice calls start on earpiece
      }

      // setClientRole and muteLocalAudioStream — skip on web
      if (!kIsWeb) {
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
        try {
          await _engine!.setEnableSpeakerphone(_speakerOn);
        } catch (e) {
          log('Warning: Could not set speakerphone: $e');
        }
      }

      // 5) Token from Supabase with timeout
      log('Fetching Agora token for channel: ${e.channelId}');
      final token = await service
          .fetchAgoraToken(channelName: e.channelId, uid: e.localUid)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              log('Token fetch timeout after 15 seconds');
              throw Exception(
                'Failed to get voice call token. Please try again.',
              );
            },
          );
      log('Successfully obtained Agora token');

      // 6) Join channel
      //    On web the Agora Iris bridge triggers getUserMedia (browser
      //    permission prompt) during joinChannel, which can take an
      //    unpredictable amount of time.  Applying a short timeout
      //    causes false failures.  We rely on the registered
      //    onJoinChannelSuccess / onError callbacks and the fallback
      //    timer below to drive state transitions instead.
      log('Joining Agora channel: ${e.channelId}');
      if (kIsWeb) {
        // Fire-and-forget on web — callbacks drive the state machine.
        _engine!
            .joinChannel(
              token: token,
              channelId: e.channelId,
              uid: e.localUid,
              options: ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishCameraTrack: e.isVideoCall,
                publishMicrophoneTrack: true,
                autoSubscribeVideo: e.isVideoCall,
                autoSubscribeAudio: true,
              ),
            )
            .catchError((err) {
              log('Web: joinChannel error (handled via callbacks): $err');
            });
        log('joinChannel called on web (fire-and-forget, callbacks pending)');
      } else {
        await _engine!
            .joinChannel(
              token: token,
              channelId: e.channelId,
              uid: e.localUid,
              options: ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishCameraTrack: e.isVideoCall,
                publishMicrophoneTrack: true,
                autoSubscribeVideo: e.isVideoCall,
                autoSubscribeAudio: true,
              ),
            )
            .timeout(
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
          add(_FallbackToOngoing(channelId: e.channelId, localUid: e.localUid));
        }
      });
    } catch (e) {
      log('Error starting call: $e');
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

    // Stop video preview if it was a video call
    if (_isVideoCall) {
      try {
        if (!kIsWeb) {
          await _engine?.stopPreview();
          await _engine?.disableVideo();
        } else {
          // On web these APIs can hang; fire-and-forget
          _engine?.stopPreview().catchError((err) {
            log('Web: stopPreview error (ignored): $err');
          });
          _engine?.disableVideo().catchError((err) {
            log('Web: disableVideo error (ignored): $err');
          });
        }
      } catch (err) {
        log('Error stopping video: $err');
      }
    }

    // Reset video state
    _isVideoCall = false;
    _videoEnabled = false;

    // Leave the channel and emit the final state.
    try {
      log('Leaving Agora channel...');
      if (kIsWeb) {
        // On web, leaveChannel can hang indefinitely.
        // Use a timeout so the UI is never stuck.
        await _engine?.leaveChannel().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            log('Web: leaveChannel timed out after 3s — continuing');
          },
        );
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
      await _engine?.muteLocalVideoStream(!_videoEnabled);
      // On web, skip startPreview/stopPreview — the browser manages
      // the camera track through the WebRTC connection. Calling these
      // on web can conflict with the active track and kill the camera.
      if (!kIsWeb) {
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
          startTime: _startedAt, // Ensure start time is propagated
        ),
      );
    }
  }

  void _onRemoteUserLeft(_RemoteUserLeft e, Emitter<CallState> emit) {
    _remoteUids.remove(e.uid);

    // If no more remote users, the other side has ended the call - end for us too
    if (_remoteUids.isEmpty && state is CallOngoing) {
      log('Remote user left and no more participants - ending call');
      add(EndCall(isRemote: true));
      return;
    }

    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(remoteUids: {..._remoteUids}));
    }
  }

  void _onTick(_Tick e, Emitter<CallState> emit) {
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(elapsed: e.elapsed));
    }
  }

  void _onFallbackToOngoing(
    _FallbackToOngoing e,
    Emitter<CallState> emit,
  ) async {
    log('Fallback handler: Transitioning to CallOngoing state');

    // On web, ensure startPreview is called so AgoraVideoView can render
    if (kIsWeb && _isVideoCall) {
      log('Web fallback: calling startPreview');
      try {
        await _engine?.enableLocalVideo(true);
      } catch (_) {}
      try {
        await _engine?.startPreview();
      } catch (_) {}
    }

    emit(
      CallOngoing(
        channelId: e.channelId,
        localUid: e.localUid,
        remoteUids: {..._remoteUids},
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

  void _onJoinChannelSuccess(
    _JoinChannelSuccess e,
    Emitter<CallState> emit,
  ) async {
    log('Handler: onJoinChannelSuccess for channel: ${e.channelId}');
    _timer?.cancel();

    // On web, start preview AFTER join so the camera track (acquired by
    // joinChannel) is available for AgoraVideoView to render.
    if (kIsWeb && _isVideoCall) {
      log('Web: calling startPreview after successful join');
      try {
        await _engine?.enableLocalVideo(true);
      } catch (err) {
        log('Web: enableLocalVideo after join error (ignored): $err');
      }
      try {
        await _engine?.startPreview();
      } catch (err) {
        log('Web: startPreview after join error (ignored): $err');
      }
    }

    emit(
      CallOngoing(
        channelId: e.channelId,
        localUid: e.localUid,
        remoteUids: {..._remoteUids},
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

      // 2) Write call_logs row (master record) — only if we are the interpreter
      //    to avoid double-writing (both sides end the call independently)
      if (interpreterId != null &&
          userId == interpreterId &&
          requesterId != null) {
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

  @override
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    try {
      if (kIsWeb) {
        // On web, leaveChannel / release can hang — use timeout.
        await _engine?.leaveChannel().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            log('Web: leaveChannel timed out in close()');
          },
        );
      } else {
        await _engine?.leaveChannel();
      }
    } catch (_) {}
    try {
      if (kIsWeb) {
        await _engine?.release().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            log('Web: engine.release timed out in close()');
          },
        );
      } else {
        await _engine?.release();
      }
    } catch (_) {}
    _engine = null;
    return super.close();
  }
}
