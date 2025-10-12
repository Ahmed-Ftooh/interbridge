import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/config.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/core/error_handler.dart';

// EVENTS
abstract class ChatEvent {}

class LoadMessages extends ChatEvent {
  final String requestId;
  LoadMessages(this.requestId);
}

class SendMessage extends ChatEvent {
  final String requestId;
  final String content;
  SendMessage({required this.requestId, required this.content});
}

class SendCallStateMessage extends ChatEvent {
  final String requestId;
  final String callState; // 'CALL_ENDED', 'CALL_JOINED', etc.
  SendCallStateMessage({required this.requestId, required this.callState});
}

class NewIncomingMessage extends ChatEvent {
  final Map<String, dynamic> raw;
  NewIncomingMessage(this.raw);
}

class StartVoiceCall extends ChatEvent {
  final String channelId;
  final int uid;
  StartVoiceCall({required this.channelId, required this.uid});
}

class EndVoiceCall extends ChatEvent {}

// STATES
abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<Map<String, dynamic>> messages;
  final bool inCall;
  ChatLoaded({required this.messages, this.inCall = false});
}

class ChatError extends ChatState {
  final AppError error;
  ChatError(this.error);
}

class ChatCallStarted extends ChatState {
  final String channelId;
  final int uid;
  ChatCallStarted(this.channelId, this.uid);
}

class ChatCallEnded extends ChatState {}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService service;
  final SupabaseService _supabaseService = SupabaseService();
  RtcEngine? _engine;
  RealtimeChannel? _msgChannel;
  final Set<String> _seenMessageIds = {};

  ChatBloc({required this.service}) : super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<SendCallStateMessage>(_onSendCallStateMessage);
    on<NewIncomingMessage>(_onNewIncomingMessage);
    on<StartVoiceCall>(_onStartVoiceCall);
    on<EndVoiceCall>(_onEndVoiceCall);
  }

  Future<void> _onLoadMessages(LoadMessages e, Emitter<ChatState> emit) async {
    try {
      emit(ChatLoading());

      // Load existing messages from the database
      final messages = await service.fetchMessages(e.requestId);
      emit(ChatLoaded(messages: messages));

      // Subscribe to listen for new messages
      _msgChannel?.unsubscribe();
      _msgChannel = service.subscribeToMessages(e.requestId, (newRow) {
        add(NewIncomingMessage(newRow));
      });
    } catch (err) {
      emit(ChatError(ErrorHandler.handleError(err, context: 'LoadMessages')));
    }
  }

  Future<void> _onSendMessage(SendMessage e, Emitter<ChatState> emit) async {
    try {
      await service.sendMessage(e.requestId, e.content);
    } catch (err) {
      emit(ChatError(ErrorHandler.handleError(err, context: 'SendMessage')));
    }
  }

  Future<void> _onSendCallStateMessage(
    SendCallStateMessage e,
    Emitter<ChatState> emit,
  ) async {
    try {
      await service.sendMessage(e.requestId, e.callState);
    } catch (err) {
      emit(
        ChatError(
          ErrorHandler.handleError(err, context: 'SendCallStateMessage'),
        ),
      );
    }
  }

  void _onNewIncomingMessage(
    NewIncomingMessage e,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatLoaded) return;
    final id = e.raw['id']?.toString();
    if (id != null && _seenMessageIds.contains(id)) return;
    if (id != null) _seenMessageIds.add(id);

    final current = (state as ChatLoaded);
    final newMessage = Map<String, dynamic>.from(e.raw);

    // Check if the message has user profile data
    if (newMessage['user_profiles'] == null &&
        newMessage['sender_id'] != null) {
      try {
        // Fetch user profile for the sender
        final userProfile = await _supabaseService.getUserProfile(
          newMessage['sender_id'],
        );
        if (userProfile != null) {
          newMessage['user_profiles'] = {
            'username': userProfile.username,
            'profile_image': _supabaseService.getProfileImageUrl(
              userProfile.profileImage,
            ),
            'role': userProfile.role,
          };
        } else {
          // Fallback if profile not found
          newMessage['user_profiles'] = {
            'username': 'User',
            'profile_image': null,
            'role': 'user',
          };
        }
      } catch (error) {
        // Fallback if there's an error fetching profile
        newMessage['user_profiles'] = {
          'username': 'User',
          'profile_image': null,
          'role': 'user',
        };
      }
    }

    final updated = List<Map<String, dynamic>>.from(current.messages)
      ..add(newMessage);
    emit(ChatLoaded(messages: updated, inCall: current.inCall));
  }

  Future<void> _onStartVoiceCall(
    StartVoiceCall e,
    Emitter<ChatState> emit,
  ) async {
    await [Permission.microphone].request();

    _engine ??= createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (state is ChatLoaded) {
            final loaded = state as ChatLoaded;
            emit(ChatLoaded(messages: loaded.messages, inCall: true));
          }
          emit(ChatCallStarted(e.channelId, e.uid));
        },
      ),
    );

    final token = await service.fetchAgoraToken(e.channelId, e.uid);
    await _engine!.joinChannel(
      token: token,
      channelId: e.channelId,
      uid: e.uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _onEndVoiceCall(EndVoiceCall e, Emitter<ChatState> emit) async {
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
    if (state is ChatLoaded) {
      final loaded = state as ChatLoaded;
      emit(ChatLoaded(messages: loaded.messages, inCall: false));
    }
    emit(ChatCallEnded());
  }

  @override
  Future<void> close() async {
    await _msgChannel?.unsubscribe();
    _engine?.release();
    return super.close();
  }
}
