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
  final bool silent; // If true, don't show loading indicator
  LoadMessages(this.requestId, {this.silent = false});
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
      // Only show loading if not silent (initial load)
      if (!e.silent) {
        emit(ChatLoading());
      }

      // Load existing messages from the database
      final messages = await service.fetchMessages(e.requestId);
      log('Loaded ${messages.length} messages from database');

      // For silent polling, only update if we have new messages
      if (e.silent && state is ChatLoaded) {
        final currentState = state as ChatLoaded;
        final currentMessageIds =
            currentState.messages.map((m) => m['id']?.toString()).toSet();
        final newMessages =
            messages.where((m) {
              final id = m['id']?.toString();
              return id != null && !currentMessageIds.contains(id);
            }).toList();

        // If no new messages, don't emit anything (keep UI stable)
        if (newMessages.isEmpty) {
          log('Silent poll: No new messages, keeping current state');
          return;
        }

        log(
          'Silent poll: Found ${newMessages.length} new messages, updating UI',
        );
      }

      // Track all loaded message IDs to prevent duplicates from real-time subscription
      for (final msg in messages) {
        final id = msg['id']?.toString();
        if (id != null) {
          _seenMessageIds.add(id);
        }
      }

      emit(ChatLoaded(messages: messages));

      // Always ensure we have an active real-time subscription
      _msgChannel?.unsubscribe();
      _msgChannel = service.subscribeToMessages(e.requestId, (newRow) {
        log('Real-time message received via subscription: ${newRow['id']}');
        add(NewIncomingMessage(newRow));
      });

      log(
        'Subscribed to real-time messages for request: ${e.requestId} (silent=${e.silent})',
      );
    } catch (err) {
      log('Error loading messages: $err');
      // Only emit error if not silent polling
      if (!e.silent) {
        emit(ChatError(ErrorHandler.handleError(err, context: 'LoadMessages')));
      }
    }
  }

  // --- MODIFIED _onSendMessage ---
  Future<void> _onSendMessage(SendMessage e, Emitter<ChatState> emit) async {
    log('SendMessage event received: ${e.content}');
    log('Current state: ${state.runtimeType}');

    // If state is not ChatLoaded, load messages first
    ChatLoaded currentState;
    if (state is ChatLoaded) {
      currentState = state as ChatLoaded;
      log('State is ChatLoaded, proceeding with send...');
    } else {
      log(
        'State is not ChatLoaded (${state.runtimeType}), loading messages first...',
      );
      try {
        emit(ChatLoading());
        final messages = await service.fetchMessages(e.requestId);

        // Track all loaded message IDs
        for (final msg in messages) {
          final id = msg['id']?.toString();
          if (id != null) {
            _seenMessageIds.add(id);
          }
        }

        currentState = ChatLoaded(messages: messages);
        emit(currentState);
        log('Messages loaded, proceeding with send...');

        // Subscribe to listen for new messages if not already subscribed
        _msgChannel?.unsubscribe();
        _msgChannel = service.subscribeToMessages(e.requestId, (newRow) {
          add(NewIncomingMessage(newRow));
        });
      } catch (err) {
        log('Error loading messages: $err');
        emit(ChatError(ErrorHandler.handleError(err, context: 'LoadMessages')));
        return;
      }
    }

    try {
      log('Sending message to service...');
      final newMessage = await service.sendMessage(
        e.requestId,
        e.content,
        messageType: e.messageType,
        attachmentUrl: e.attachmentUrl,
      );
      log('Message sent successfully, adding to UI...');

      // Optimistically add the new message to the UI immediately
      final updatedMessages = List<Map<String, dynamic>>.from(
        currentState.messages,
      )..add(newMessage);
      final newMessageId = newMessage['id']?.toString();
      if (newMessageId != null) {
        _seenMessageIds.add(newMessageId);
      }
      emit(
        ChatLoaded(
          messages: updatedMessages,
          inCall: currentState.inCall,
          isUploading: currentState.isUploading,
        ),
      );
      log('Message added to UI successfully');
    } catch (err, stackTrace) {
      log('Error in _onSendMessage: $err');
      log('Stack trace: $stackTrace');
      emit(ChatError(ErrorHandler.handleError(err, context: 'SendMessage')));
    }
  }
  // --- END OF MODIFICATION ---

  // --- NEW HANDLER: _onUploadAndSendAttachment ---
  Future<void> _onUploadAndSendAttachment(
    UploadAndSendAttachment e,
    Emitter<ChatState> emit,
  ) async {
    log('=== UploadAndSendAttachment event received ===');
    log('RequestId: ${e.requestId}');
    log('FileName: ${e.fileName}');
    log('MessageType: ${e.messageType}');
    log('File path: ${e.file.path}');
    log('Current state type: ${state.runtimeType}');

    // If state is not ChatLoaded, load messages first
    ChatLoaded currentState;
    if (state is ChatLoaded) {
      currentState = state as ChatLoaded;
      log('State is ChatLoaded, proceeding with upload...');
    } else {
      log(
        'State is not ChatLoaded (${state.runtimeType}), loading messages first...',
      );
      try {
        emit(ChatLoading());
        final messages = await service.fetchMessages(e.requestId);

        // Track all loaded message IDs
        for (final msg in messages) {
          final id = msg['id']?.toString();
          if (id != null) {
            _seenMessageIds.add(id);
          }
        }

        currentState = ChatLoaded(messages: messages);
        emit(currentState);
        log('Messages loaded, proceeding with upload...');

        // Subscribe to listen for new messages if not already subscribed
        _msgChannel?.unsubscribe();
        _msgChannel = service.subscribeToMessages(e.requestId, (newRow) {
          add(NewIncomingMessage(newRow));
        });
      } catch (err) {
        log('Error loading messages: $err');
        emit(ChatError(ErrorHandler.handleError(err, context: 'LoadMessages')));
        return;
      }
    }

    try {
      // Check if file exists
      final fileExists = await e.file.exists();
      log('File exists check: $fileExists');
      if (!fileExists) {
        throw Exception('File does not exist at path: ${e.file.path}');
      }

      // Emit loading state
      log('Emitting loading state...');
      emit(currentState.copyWith(isUploading: true));

      // 1. Upload the file
      log('Starting file upload for voice message: ${e.fileName}');
      log('File size: ${await e.file.length()} bytes');
      final attachmentUrl = await service.uploadChatAttachment(
        e.file,
        e.fileName,
        e.messageType,
      );
      log('File uploaded successfully to: $attachmentUrl');

      // 2. Send the message with the URL - await it directly instead of adding event
      log('Sending message with attachment URL: $attachmentUrl');
      final newMessage = await service.sendMessage(
        e.requestId,
        e.fileName, // Use file name as content
        messageType: e.messageType,
        attachmentUrl: attachmentUrl,
      );
      log('Message sent successfully to Supabase');
      log('Signed URL in newMessage: ${newMessage['attachment_signed_url']}');

      // Verify signed URL was generated
      if (newMessage['attachment_signed_url'] == null) {
        log('WARNING: Signed URL not generated, fetching manually...');
        try {
          newMessage['attachment_signed_url'] = await service.createSignedUrl(
            attachmentUrl,
          );
          log(
            'Manually fetched signed URL: ${newMessage['attachment_signed_url']}',
          );
        } catch (e) {
          log('ERROR: Failed to fetch signed URL manually: $e');
        }
      }

      // Optimistically add the new message to the UI immediately
      final updatedMessages = List<Map<String, dynamic>>.from(
        currentState.messages,
      )..add(newMessage);
      final newMessageId = newMessage['id']?.toString();
      if (newMessageId != null) {
        _seenMessageIds.add(newMessageId);
      }
      emit(
        ChatLoaded(
          messages: updatedMessages,
          inCall: currentState.inCall,
          isUploading: false,
        ),
      );
      log('=== UploadAndSendAttachment completed successfully ===');
    } catch (err, stackTrace) {
      log("=== ERROR in _onUploadAndSendAttachment ===");
      log("Error: $err");
      log("Error type: ${err.runtimeType}");
      log("Error details: ${err.toString()}");
      log("Stack trace: $stackTrace");
      // Restore previous state on error - reload messages to get current state
      try {
        final messages = await service.fetchMessages(e.requestId);
        emit(ChatLoaded(messages: messages, isUploading: false));
        // Emit error state so the listener can show it to the user
        // Note: This will be received by the listener, then the builder will see ChatError
        // but the chat_view handles this by checking if state is ChatLoaded first
        emit(
          ChatError(ErrorHandler.handleError(err, context: 'UploadAttachment')),
        );
      } catch (e) {
        // If we can't reload messages, just emit error state
        emit(
          ChatError(ErrorHandler.handleError(err, context: 'UploadAttachment')),
        );
      }
      log("=== Error handled, state restored ===");
    }
  }
  // --- END OF NEW HANDLER ---

  Future<void> _onSendCallStateMessage(
    SendCallStateMessage e,
    Emitter<ChatState> emit,
  ) async {
    try {
      log('Sending call state message: ${e.callState}');
      final newMessage = await service.sendMessage(e.requestId, e.callState);
      log('Call state message sent successfully');

      // Update the UI immediately (like in SendMessage)
      if (state is ChatLoaded) {
        final currentState = state as ChatLoaded;
        final updatedMessages = List<Map<String, dynamic>>.from(
          currentState.messages,
        )..add(newMessage);
        final newMessageId = newMessage['id']?.toString();
        if (newMessageId != null) {
          _seenMessageIds.add(newMessageId);
        }
        emit(
          ChatLoaded(
            messages: updatedMessages,
            inCall: currentState.inCall,
            isUploading: currentState.isUploading,
          ),
        );
        log('Call state message added to UI immediately');
      }
    } catch (err) {
      log('Error sending call state message: $err');
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
    if (id != null && _seenMessageIds.contains(id)) {
      log('Skipping duplicate message: $id');
      return;
    }
    if (id != null) _seenMessageIds.add(id);

    final current = (state as ChatLoaded);
    final newMessage = Map<String, dynamic>.from(e.raw);
    log(
      'Processing new incoming message: $id, type: ${newMessage['message_type']}',
    );

    // Check if the message has user profile data
    if (newMessage['user_profiles'] == null &&
        newMessage['sender_id'] != null) {
      try {
        // Fetch user profile for the sender
        log('Fetching user profile for sender: ${newMessage['sender_id']}');
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
          log('User profile fetched: ${userProfile.username}');
        } else {
          // Fallback if profile not found
          newMessage['user_profiles'] = {
            'username': 'User',
            'profile_image': null,
            'role': 'user',
          };
          log('User profile not found, using fallback');
        }
      } catch (error) {
        // Fallback if there's an error fetching profile
        log('Error fetching user profile: $error');
        newMessage['user_profiles'] = {
          'username': 'User',
          'profile_image': null,
          'role': 'user',
        };
      }
    }

    // CRITICAL FIX: Fetch signed URL for attachment messages
    final attachmentPath = newMessage['attachment_url'] as String?;
    final messageType = newMessage['message_type'] as String?;
    if (attachmentPath != null &&
        (messageType == 'image' ||
            messageType == 'audio' ||
            messageType == 'file') &&
        newMessage['attachment_signed_url'] == null) {
      try {
        log('Fetching signed URL for attachment: $attachmentPath');
        final signedUrl = await service.createSignedUrl(attachmentPath);
        newMessage['attachment_signed_url'] = signedUrl;
        log('Signed URL fetched successfully');
      } catch (error) {
        log('Failed to prefetch signed URL: $error');
        // Don't block message delivery if signed URL fails
      }
    }

    final updated = List<Map<String, dynamic>>.from(current.messages)
      ..add(newMessage);

    log('Emitting updated chat state with new message');
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
