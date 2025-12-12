import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
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
    on<UploadAndSendAttachment>(_onUploadAndSendAttachment);
    on<SendCallStateMessage>(_onSendCallStateMessage);
    on<NewIncomingMessage>(_onNewIncomingMessage);
    // Removed StartVoiceCall and EndVoiceCall handlers to avoid conflict with CallBloc
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
      if (state is ChatLoaded) {
        final currentMessages = List<Map<String, dynamic>>.from(
          (state as ChatLoaded).messages,
        );
        // Check if already exists (from realtime)
        final existingIndex = currentMessages.indexWhere(
          (m) => m['id'] == newMessage['id'],
        );
        if (existingIndex == -1) {
          currentMessages.add(newMessage);
        } else {
          currentMessages[existingIndex] = newMessage;
        }

        final newMessageId = newMessage['id']?.toString();
        if (newMessageId != null) {
          _seenMessageIds.add(newMessageId);
        }

        emit((state as ChatLoaded).copyWith(messages: currentMessages));
      }
      log('Message added to UI successfully');
    } catch (err, stackTrace) {
      log('Error in _onSendMessage: $err');
      log('Stack trace: $stackTrace');
      emit(ChatError(ErrorHandler.handleError(err, context: 'SendMessage')));
    }
  }
  // --- END OF MODIFICATION ---

  // --- NEW HANDLER: _onUploadAndSendAttachment with Retry Logic ---
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

    // Create temporary message ID for optimistic update
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Check if file exists
      final fileExists = await e.file.exists();
      log('File exists check: $fileExists');
      if (!fileExists) {
        throw Exception('File does not exist at path: ${e.file.path}');
      }

      final fileSize = await e.file.length();
      log('File size: $fileSize bytes');

      // Create optimistic message for immediate UI feedback
      final currentUser = Supabase.instance.client.auth.currentUser;
      final optimisticMessage = {
        'id': tempMessageId,
        'request_id': e.requestId,
        'sender_id': currentUser?.id,
        'content': e.fileName,
        'message_type': e.messageType,
        'created_at': DateTime.now().toIso8601String(),
        'attachment_url': null,
        'attachment_signed_url': null,
        '_status': 'sending', // Custom field to track upload status
        'user_profiles': {
          'username': 'You',
          'profile_image': null,
          'role': 'user',
        },
        'local_path':
            e.file.path, // <-- ADDED: Store local path for immediate display
      };

      // Add optimistic message to UI immediately
      final messagesWithOptimistic = List<Map<String, dynamic>>.from(
        currentState.messages,
      )..add(optimisticMessage);

      emit(
        ChatLoaded(
          messages: messagesWithOptimistic,
          inCall: currentState.inCall,
          isUploading: true,
        ),
      );
      log('Optimistic message added to UI');

      // Retry logic for upload
      const maxRetries = 3;
      String? attachmentUrl;
      Map<String, dynamic>? newMessage;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          log('Upload attempt $attempt of $maxRetries');

          // 1. Upload the file with retry
          attachmentUrl = await service.uploadChatAttachment(
            e.file,
            e.fileName,
            e.messageType,
          );
          log('File uploaded successfully to: $attachmentUrl');

          // 2. Send the message with the URL
          log('Sending message with attachment URL: $attachmentUrl');
          newMessage = await service.sendMessage(
            e.requestId,
            e.fileName,
            messageType: e.messageType,
            attachmentUrl: attachmentUrl,
          );
          log('Message sent successfully to Supabase');

          // Success - break out of retry loop
          break;
        } catch (e) {
          log('Attempt $attempt failed: $e');
          if (attempt < maxRetries) {
            // Exponential backoff: wait 1s, 2s, 4s
            final delaySeconds = attempt * attempt;
            log('Retrying in $delaySeconds seconds...');
            await Future.delayed(Duration(seconds: delaySeconds));
          } else {
            // All retries exhausted
            rethrow;
          }
        }
      }

      if (newMessage == null) {
        throw Exception('Failed to send message after $maxRetries attempts');
      }

      log('Message from database: ${newMessage.keys.join(", ")}');
      log('attachment_url from DB: ${newMessage['attachment_url']}');
      log(
        'attachment_signed_url from DB: ${newMessage['attachment_signed_url']}',
      );

      // CRITICAL: Ensure both attachment_url and signed URL are available
      if (attachmentUrl != null) {
        // Make sure attachment_url is set (it should be from sendMessage)
        newMessage['attachment_url'] ??= attachmentUrl;
        log('Ensured attachment_url is set: ${newMessage['attachment_url']}');

        // Ensure signed URL is available for immediate display
        if (newMessage['attachment_signed_url'] == null) {
          log('Signed URL missing, fetching now...');
          try {
            final signedUrl = await service
                .createSignedUrl(attachmentUrl)
                .timeout(const Duration(seconds: 10));
            newMessage['attachment_signed_url'] = signedUrl;
            log('Successfully fetched signed URL: $signedUrl');
          } catch (e) {
            log('ERROR: Failed to fetch signed URL: $e');
            // Try to use the attachment_url as fallback
            log('Will rely on _ChatBubble to fetch signed URL lazily');
          }
        } else {
          log(
            'Signed URL already present: ${newMessage['attachment_signed_url']}',
          );
        }
      }

      // CRITICAL: Preserve local_path so the UI can continue to show the local file
      // while the network URL is being processed or if it fails to load.
      newMessage['local_path'] = e.file.path;
      log('Preserved local_path in final message: ${e.file.path}');

      // Mark as successfully sent
      newMessage['_status'] = 'sent';

      // Update state safely using the LATEST state
      if (state is ChatLoaded) {
        final currentMessages = List<Map<String, dynamic>>.from(
          (state as ChatLoaded).messages,
        );

        // Remove optimistic message
        // We use a more robust removal strategy to ensure it's gone
        currentMessages.removeWhere((m) {
          final isIdMatch = m['id'] == tempMessageId;
          final isOptimisticMatch =
              m['_status'] == 'sending' &&
              m['content'] == e.fileName &&
              m['message_type'] == e.messageType;
          // Also check by local path if available
          final isPathMatch =
              m['local_path'] != null && m['local_path'] == e.file.path;
          return isIdMatch || isOptimisticMatch || isPathMatch;
        });

        // Check if message already exists (from realtime)
        // Use toString() for safe comparison regardless of type (int vs String)
        final newMessageIdStr = newMessage['id']?.toString();
        final existingIndex = currentMessages.indexWhere(
          (m) => m['id']?.toString() == newMessageIdStr,
        );

        if (existingIndex != -1) {
          // Update existing message (merge to keep any other updates)
          log(
            'Merging with existing real-time message at index $existingIndex',
          );
          final existingMsg = currentMessages[existingIndex];

          // We want to keep the local_path we just added, but also respect
          // any newer data from real-time (though our newMessage is likely freshest for own fields)
          currentMessages[existingIndex] = {
            ...existingMsg,
            ...newMessage,
            // Ensure local_path is definitely kept
            'local_path': e.file.path,
          };
        } else {
          // Add new message
          log('Adding new message to list (not found in real-time yet)');
          // Ensure local_path is present in the new message being added
          newMessage['local_path'] = e.file.path;
          currentMessages.add(newMessage);
        }

        if (newMessageIdStr != null) {
          _seenMessageIds.add(newMessageIdStr);
        }

        emit(
          (state as ChatLoaded).copyWith(
            messages: currentMessages,
            isUploading: false,
          ),
        );
      }
      log('=== UploadAndSendAttachment completed successfully ===');
    } catch (err, stackTrace) {
      log("=== ERROR in _onUploadAndSendAttachment ===");
      log("Error: $err");
      log("Error type: ${err.runtimeType}");
      log("Error details: ${err.toString()}");
      log("Stack trace: $stackTrace");

      // Remove optimistic message and restore previous state safely
      if (state is ChatLoaded) {
        final currentMessages = List<Map<String, dynamic>>.from(
          (state as ChatLoaded).messages,
        );
        currentMessages.removeWhere((m) {
          final isIdMatch = m['id'] == tempMessageId;
          final isOptimisticMatch =
              m['_status'] == 'sending' &&
              m['content'] == e.fileName &&
              m['message_type'] == e.messageType;
          return isIdMatch || isOptimisticMatch;
        });

        emit(
          (state as ChatLoaded).copyWith(
            messages: currentMessages,
            isUploading: false,
          ),
        );
      }

      // Emit error for user feedback
      emit(
        ChatError(ErrorHandler.handleError(err, context: 'UploadAttachment')),
      );
      log("=== Error handled, optimistic message removed ===");
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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final id = e.raw['id']?.toString();

    // Check if this is a duplicate message
    if (id != null && _seenMessageIds.contains(id)) {
      log('Message $id already seen, checking if it needs updating...');

      final messageType = e.raw['message_type'] as String?;
      final isAttachmentMessage =
          messageType == 'image' ||
          messageType == 'audio' ||
          messageType == 'file';

      if (isAttachmentMessage) {
        final current = (state as ChatLoaded);
        final messages = List<Map<String, dynamic>>.from(current.messages);
        final index = messages.indexWhere((m) => m['id']?.toString() == id);
        if (index != -1) {
          final updatedMessage = Map<String, dynamic>.from(messages[index])
            ..addAll(e.raw);

          // Ensure user profile is set
          if (updatedMessage['user_profiles'] == null &&
              updatedMessage['sender_id'] != null) {
            try {
              final userProfile = await _supabaseService.getUserProfile(
                updatedMessage['sender_id'],
              );
              if (userProfile != null) {
                updatedMessage['user_profiles'] = {
                  'username': userProfile.username,
                  'profile_image': _supabaseService.getProfileImageUrl(
                    userProfile.profileImage,
                  ),
                  'role': userProfile.role,
                };
              }
            } catch (error) {
              log('Error fetching user profile for update: $error');
            }
          }

          // Ensure signed URL exists
          final attachmentPath = updatedMessage['attachment_url'] as String?;
          if (attachmentPath != null &&
              updatedMessage['attachment_signed_url'] == null) {
            try {
              log('Duplicate message missing signed URL, fetching now...');
              updatedMessage['attachment_signed_url'] = await service
                  .createSignedUrl(attachmentPath)
                  .timeout(const Duration(seconds: 10));
              log('Signed URL attached to duplicate message');
            } catch (error) {
              log('Failed to fetch signed URL for duplicate message: $error');
            }
          }

          messages[index] = updatedMessage;

          final isOwnMessage =
              currentUserId != null &&
              updatedMessage['sender_id'] == currentUserId;
          final shouldClearUploading = current.isUploading && isOwnMessage;

          log('Updated duplicate attachment message $id');
          emit(
            ChatLoaded(
              messages: messages,
              inCall: current.inCall,
              isUploading: shouldClearUploading ? false : current.isUploading,
            ),
          );
          return;
        }
      }
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
        final signedUrl = await service
            .createSignedUrl(attachmentPath)
            .timeout(const Duration(seconds: 10));
        newMessage['attachment_signed_url'] = signedUrl;
        log('Signed URL fetched successfully');
      } catch (error) {
        log('Failed to prefetch signed URL: $error');
        // Don't block message delivery if signed URL fails
      }
    }

    final currentMessages = List<Map<String, dynamic>>.from(current.messages);

    // Check for optimistic match and replace it
    final optimisticIndex = currentMessages.indexWhere(
      (m) =>
          m['_status'] == 'sending' &&
          m['content'] == newMessage['content'] &&
          m['message_type'] == newMessage['message_type'],
    );

    if (optimisticIndex != -1) {
      log('Replacing optimistic message with real message $id');
      // Preserve local_path from optimistic message
      newMessage['local_path'] = currentMessages[optimisticIndex]['local_path'];
      currentMessages[optimisticIndex] = newMessage;
    } else {
      currentMessages.add(newMessage);
    }

    final isOwnMessage =
        currentUserId != null && newMessage['sender_id'] == currentUserId;
    final shouldClearUploading = current.isUploading && isOwnMessage;

    log('Emitting updated chat state with new message');
    emit(
      ChatLoaded(
        messages: currentMessages,
        inCall: current.inCall,
        isUploading: shouldClearUploading ? false : current.isUploading,
      ),
    );
  }

  // Removed _onStartVoiceCall and _onEndVoiceCall methods
  // Call logic is now exclusively handled by CallBloc

  @override
  Future<void> close() async {
    await _msgChannel?.unsubscribe();
    _engine?.release();
    return super.close();
  }
}
