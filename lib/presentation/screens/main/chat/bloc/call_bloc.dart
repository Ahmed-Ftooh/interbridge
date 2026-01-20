import 'dart:async';
import 'dart:developer';
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
  }

  Future<void> _onStartCall(StartCall e, Emitter<CallState> emit) async {
    try {
      // Notify global call state immediately so chat banner updates
      CallStateManager().startCall(e.channelId);

      // Store video call flag
      _isVideoCall = e.isVideoCall;
      _videoEnabled = e.isVideoCall; // Start with video on for video calls

      // 1) Request microphone permission
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
          log('Camera permission not granted. Please enable in app settings.');
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

      emit(CallConnecting(e.channelId));

      // 2) Init engine (ensure fresh instance)
      log('Initializing Agora RTC Engine...');
      if (_engine != null) {
        log('Releasing existing engine instance...');
        try {
          await _engine!.release();
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
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            log('Successfully joined channel: ${e.channelId}');
            // Don't start timer here - wait for remote user
            _timer?.cancel();

            log('Emitting CallOngoing state for channel: ${e.channelId}');
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
          },
          onError: (errorCode, errorMsg) {
            log('Agora RTC Engine error: $errorCode - $errorMsg');
            // Handle any error that might prevent the call from working
            emit(
              CallError(
                AppError(
                  message: 'Voice call error: $errorMsg',
                  type: ErrorType.network,
                  userAction:
                      'Please check your internet connection and try again.',
                  isRetryable: true,
                ),
              ),
            );
          },
          onConnectionStateChanged: (connection, state, reason) {
            log('Connection state changed: $state, reason: $reason');
            if (state == ConnectionStateType.connectionStateFailed) {
              emit(
                CallError(
                  AppError(
                    message: 'Voice call connection failed',
                    type: ErrorType.network,
                    userAction:
                        'Please check your internet connection and try again.',
                    isRetryable: true,
                  ),
                ),
              );
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
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
      );
      await _engine!.setAudioScenario(AudioScenarioType.audioScenarioMeeting);
      await _engine!.setDefaultAudioRouteToSpeakerphone(
        e.isVideoCall, // Use speaker for video calls
      );

      await _engine!.enableAudio();
      await _engine!.enableLocalAudio(true); // Explicitly enable local audio

      // 4b) Enable video for video calls
      if (e.isVideoCall) {
        log('Enabling video for video call...');
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
        _speakerOn = true; // Video calls default to speaker
      } else {
        _speakerOn = false; // Voice calls start on earpiece
      }

      await _engine!.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      ); // Explicitly set role
      await _engine!.muteLocalAudioStream(_muted);
      try {
        await _engine!.setEnableSpeakerphone(_speakerOn);
      } catch (e) {
        log(
          'Warning: Could not set speakerphone, continuing with default audio route: $e',
        );
      }

      // 5) Token from Supabase with timeout
      log('Fetching Agora token for channel: ${e.channelId}');
      final token = await service
          .fetchAgoraToken(channelName: e.channelId, uid: e.localUid)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              log('Token fetch timeout after 10 seconds');
              throw Exception(
                'Failed to get voice call token. Please try again.',
              );
            },
          );
      log('Successfully obtained Agora token');

      // 6) Join channel with timeout
      log('Joining Agora channel: ${e.channelId}');
      await _engine!
          .joinChannel(
            token: token,
            channelId: e.channelId,
            uid: e.localUid,
            options: const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
            ),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              log('Join channel timeout after 10 seconds');
              throw Exception(
                'Voice call connection timeout. Please try again.',
              );
            },
          );
      log('Successfully joined Agora channel');

      // Fallback: If onJoinChannelSuccess doesn't fire within 5 seconds,
      // assume the call is ongoing and emit the state manually
      Timer(const Duration(seconds: 5), () {
        if (state is CallConnecting) {
          log('Fallback: Manually transitioning to CallOngoing state');
          _startedAt = DateTime.now();
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (_startedAt != null) {
              final elapsed = DateTime.now().difference(_startedAt!);
              add(_Tick(elapsed));
            }
          });

          // Use add() to trigger a new event instead of emit()
          add(_FallbackToOngoing(channelId: e.channelId, localUid: e.localUid));
        }
      });
    } catch (e) {
      log('Error starting call: $e');
      emit(CallError(ErrorHandler.handleError(e, context: 'StartCall')));
    }
  }

  // ############ THIS IS THE FIX ############
  // The logic inside _onEndCall has been reordered.
  // The __CALL_ENDED__ message is now sent *before*
  // leaving the channel and emitting the CallEnded state.
  // In: lib/presentation/screens/main/chat/bloc/call_bloc.dart
  // REPLACE the _onEndCall method with this new version:

  Future<void> _onEndCall(EndCall e, Emitter<CallState> emit) async {
    log('Ending call... (isRemote: ${e.isRemote})');
    _timer?.cancel();
    _timer = null;

    // Record call duration before clearing
    Duration? callDuration;
    if (_startedAt != null) {
      callDuration = DateTime.now().difference(_startedAt!);
      await _recordCallDuration(callDuration);
    }

    _startedAt = null;
    _remoteUids.clear();

    // Stop video preview if it was a video call
    if (_isVideoCall) {
      try {
        await _engine?.stopPreview();
        await _engine?.disableVideo();
      } catch (err) {
        log('Error stopping video: $err');
      }
    }

    // Reset video state
    _isVideoCall = false;
    _videoEnabled = false;

    // --- THIS IS THE CHANGE ---
    // We NO LONGER try to send a ChatBloc message from here.
    // The UI (enhanced_call_view) will handle that.
    // We just leave the channel and emit the final state.
    // This logic now runs for BOTH local and remote hangups.

    try {
      log('Leaving Agora channel...');
      await _engine?.leaveChannel();
      log('Successfully left Agora channel');
    } catch (e) {
      log('Error leaving channel: $e');
    } finally {
      // Ensure global call banner clears for everyone
      CallStateManager().endCall();
      // We pass the `isRemote` flag to the UI.
      log('Emitting CallEnded state');
      emit(CallEnded(isRemote: e.isRemote)); // <-- MODIFIED
    }
  }
  // ############ END OF FIX ############

  Future<void> _onToggleMute(ToggleMute e, Emitter<CallState> emit) async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(muted: _muted));
    }
  }

  Future<void> _onToggleSpeaker(
    ToggleSpeaker e,
    Emitter<CallState> emit,
  ) async {
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
      if (_videoEnabled) {
        await _engine?.startPreview();
      } else {
        await _engine?.stopPreview();
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

  void _onFallbackToOngoing(_FallbackToOngoing e, Emitter<CallState> emit) {
    log('Fallback handler: Transitioning to CallOngoing state');
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

  Future<void> _recordCallDuration(Duration duration) async {
    try {
      // Log the call duration
      log(
        'Call duration: ${duration.inMinutes} minutes and ${duration.inSeconds.remainder(60)} seconds',
      );

      // Record to database if we have an ongoing call state
      if (state is CallOngoing) {
        final ongoingState = state as CallOngoing;
        final userId = service.requireUserId();

        await service.recordCallDuration(
          channelId: ongoingState.channelId,
          duration: duration,
          userId: userId,
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
      await _engine?.leaveChannel();
    } catch (_) {}
    await _engine?.release();
    _engine = null;
    return super.close();
  }
}
