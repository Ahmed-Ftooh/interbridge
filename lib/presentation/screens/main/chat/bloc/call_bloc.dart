import 'dart:async';
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/config.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';

/// ===== Events =====
abstract class CallEvent {}

class StartCall extends CallEvent {
  final String channelId; // e.g., your requestId
  final int localUid; // stable int
  StartCall({required this.channelId, required this.localUid});
}

class EndCall extends CallEvent {}

class ToggleMute extends CallEvent {}

class ToggleSpeaker extends CallEvent {}

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

  CallOngoing({
    required this.channelId,
    required this.localUid,
    required this.remoteUids,
    required this.muted,
    required this.speakerOn,
    required this.elapsed,
  });

  CallOngoing copyWith({
    Set<int>? remoteUids,
    bool? muted,
    bool? speakerOn,
    Duration? elapsed,
  }) {
    return CallOngoing(
      channelId: channelId,
      localUid: localUid,
      remoteUids: remoteUids ?? this.remoteUids,
      muted: muted ?? this.muted,
      speakerOn: speakerOn ?? this.speakerOn,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

class CallEnded extends CallState {}

/// ===== BLoC =====
class CallBloc extends Bloc<CallEvent, CallState> {
  final CallService service;
  final ChatBloc? _chatBloc; // Reference to chat bloc for sending notifications

  RtcEngine? _engine;
  Timer? _timer;
  DateTime? _startedAt;
  bool _muted = false;
  bool _speakerOn = true;
  final Set<int> _remoteUids = {};

  CallBloc({required this.service, ChatBloc? chatBloc})
    : _chatBloc = chatBloc,
      super(CallIdle()) {
    on<StartCall>(_onStartCall);
    on<EndCall>(_onEndCall);
    on<ToggleMute>(_onToggleMute);
    on<ToggleSpeaker>(_onToggleSpeaker);
    on<_RemoteUserJoined>(_onRemoteUserJoined);
    on<_RemoteUserLeft>(_onRemoteUserLeft);
    on<_Tick>(_onTick);
    on<_FallbackToOngoing>(_onFallbackToOngoing);
  }

  Future<void> _onStartCall(StartCall e, Emitter<CallState> emit) async {
    try {
      // 1) Check mic permission (should already be granted at login)
      log('Checking microphone permission...');
      final mic = await Permission.microphone.status;
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

      emit(CallConnecting(e.channelId));

      // 2) Init engine (once)
      log('Initializing Agora RTC Engine...');
      _engine ??= createAgoraRtcEngine();

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
            _startedAt = DateTime.now();
            _timer?.cancel();
            _timer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (_startedAt != null) {
                final elapsed = DateTime.now().difference(_startedAt!);
                add(_Tick(elapsed));
              }
            });

            log('Emitting CallOngoing state for channel: ${e.channelId}');
            emit(
              CallOngoing(
                channelId: e.channelId,
                localUid: e.localUid,
                remoteUids: {..._remoteUids},
                muted: _muted,
                speakerOn: _speakerOn,
                elapsed: Duration.zero,
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
        false,
      ); // earpiece to reduce echo

      await _engine!.enableAudio();
      await _engine!.muteLocalAudioStream(_muted);
      _speakerOn = false; // start on earpiece
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
            const Duration(seconds: 15),
            onTimeout: () {
              log('Token fetch timeout after 15 seconds');
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
            const Duration(seconds: 30),
            onTimeout: () {
              log('Join channel timeout after 30 seconds');
              throw Exception(
                'Voice call connection timeout. Please try again.',
              );
            },
          );
      log('Successfully joined Agora channel');

      // Fallback: If onJoinChannelSuccess doesn't fire within 3 seconds,
      // assume the call is ongoing and emit the state manually
      Timer(const Duration(seconds: 3), () {
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

  Future<void> _onEndCall(EndCall e, Emitter<CallState> emit) async {
    _timer?.cancel();
    _timer = null;

    // Record call duration before clearing
    Duration? callDuration;
    if (_startedAt != null) {
      callDuration = DateTime.now().difference(_startedAt!);
      // Here you can save the call duration to your database
      await _recordCallDuration(callDuration);
    }

    _startedAt = null;
    _remoteUids.clear();
    try {
      await _engine?.leaveChannel();

      // Send call ended notification to chat
      if (_chatBloc != null && state is CallOngoing) {
        final ongoingState = state as CallOngoing;
        _chatBloc.add(
          SendCallStateMessage(
            requestId: ongoingState.channelId,
            callState: '__CALL_ENDED__',
          ),
        );
      }
    } finally {
      emit(CallEnded());
    }
  }

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

  void _onRemoteUserJoined(_RemoteUserJoined e, Emitter<CallState> emit) {
    _remoteUids.add(e.uid);
    if (state is CallOngoing) {
      emit((state as CallOngoing).copyWith(remoteUids: {..._remoteUids}));
    }
  }

  void _onRemoteUserLeft(_RemoteUserLeft e, Emitter<CallState> emit) {
    _remoteUids.remove(e.uid);
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
        elapsed: Duration.zero,
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
