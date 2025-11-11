import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/config.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/core/error_handler.dart';
import 'dart:io'; // <-- ADDED
import 'dart:developer'; // <-- ADDED

// EVENTS
abstract class ChatEvent {}

class LoadMessages extends ChatEvent {
  final String requestId;
  LoadMessages(this.requestId);
}

// --- MODIFIED SendMessage Event ---
class SendMessage extends ChatEvent {
  final String requestId;
  final String content;
  final String messageType;
  final String? attachmentUrl;
  SendMessage({
    required this.requestId,
    required this.content,
    this.messageType = 'text',
    this.attachmentUrl,
  });
}
// --- END OF MODIFICATION ---

// --- NEW Event: UploadAndSendAttachment ---
class UploadAndSendAttachment extends ChatEvent {
  final String requestId;
  final File file;
  final String fileName;
  final String messageType; // 'image', 'audio', 'file'
  UploadAndSendAttachment({
    required this.requestId,
    required this.file,
    required this.fileName,
    required this.messageType,
  });
}
// --- END OF NEW Event ---

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
  final bool isUploading; // <-- ADDED
  ChatLoaded({
    required this.messages,
    this.inCall = false,
    this.isUploading = false, // <-- ADDED
  });

  // <-- ADDED copyWith method ---
  ChatLoaded copyWith({
    List<Map<String, dynamic>>? messages,
    bool? inCall,
    bool? isUploading,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      inCall: inCall ?? this.inCall,
      isUploading: isUploading ?? this.isUploading,
    );
  }
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
    on<UploadAndSendAttachment>(_onUploadAndSendAttachment); // <-- ADDED
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

  // --- MODIFIED _onSendMessage ---
  Future<void> _onSendMessage(SendMessage e, Emitter<ChatState> emit) async {
    try {
      await service.sendMessage(
        e.requestId,
        e.content,
        messageType: e.messageType,
        attachmentUrl: e.attachmentUrl,
      );
    } catch (err) {
      emit(ChatError(ErrorHandler.handleError(err, context: 'SendMessage')));
    }
  }
  // --- END OF MODIFICATION ---

  // --- NEW HANDLER: _onUploadAndSendAttachment ---
  Future<void> _onUploadAndSendAttachment(
    UploadAndSendAttachment e,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatLoaded) return;
    final currentState = state as ChatLoaded;

    try {
      // Emit loading state
      emit(currentState.copyWith(isUploading: true));

      // 1. Upload the file
      final attachmentUrl = await service.uploadChatAttachment(
        e.file,
        e.fileName,
        e.messageType,
      );

      // 2. Send the message with the URL
      add(
        SendMessage(
          requestId: e.requestId,
          content: e.fileName, // Use file name as content
          messageType: e.messageType,
          attachmentUrl: attachmentUrl,
        ),
      );

      // Emit loaded state (isUploading will be reset by the time messages reload)
    } catch (err) {
      log("Error in _onUploadAndSendAttachment: $err");
      emit(
        ChatError(ErrorHandler.handleError(err, context: 'UploadAttachment')),
      );
      // Restore previous state on error
      emit(currentState.copyWith(isUploading: false));
    } finally {
      // Ensure loading is turned off
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(isUploading: false));
      }
    }
  }
  // --- END OF NEW HANDLER ---

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

    emit(
      ChatLoaded(
        messages: updated,
        inCall: current.inCall,
        isUploading: current.isUploading, // <-- Pass the uploading state
      ),
    );
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
            emit(
              ChatLoaded(
                messages: loaded.messages,
                inCall: true,
                isUploading: loaded.isUploading, // <-- Pass the uploading state
              ),
            );
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
      emit(
        ChatLoaded(
          messages: loaded.messages,
          inCall: false,
          isUploading: loaded.isUploading, // <-- Pass the uploading state
        ),
      );
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
