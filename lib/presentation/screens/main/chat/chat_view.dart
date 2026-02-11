import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';
import 'package:interbridge/presentation/services/call_state_manager.dart';
import 'package:interbridge/presentation/screens/main/chat/call_feedback_dialog.dart';

// --- ADDED IMPORTS ---
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/screens/main/preview/embedded_audio_player.dart';
// For ChatService instance
import 'package:interbridge/data/services/chat_service.dart'; // For ChatService
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as perm_handler;
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer'; // For logging
// --- THIS IS THE PDF FIX ---
import 'package:interbridge/presentation/screens/main/preview/pdf_preview_screen.dart';
import 'package:interbridge/presentation/screens/main/preview/image_preview_screen.dart';
// --- END OF FIX ---

class ChatView extends StatefulWidget {
  final String requestId;
  final String requesterId;
  final String interpreterId;

  const ChatView({
    super.key,
    required this.requestId,
    required this.requesterId,
    required this.interpreterId,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _handledInviteMessageId;
  String? _handledCallEndedMessageId;
  // Timer removed - no longer polling, real-time subscription handles all messages

  int _uidFromUuid(String uuid) {
    return uuid.hashCode.abs();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ChatBloc>().add(LoadMessages(widget.requestId));
    // _saveSessionState();

    // REMOVED: Polling is no longer needed because real-time subscription
    // in ChatBloc already handles new messages including voice messages.
    // The 5-second polling was causing unnecessary load and the real-time
    // subscription should catch all messages immediately.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Timer is no longer used, so no need to cancel
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _handleAppResume() {
    if (!mounted) return;
    context.read<ChatBloc>().add(LoadMessages(widget.requestId, silent: true));
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          // Voice Call button
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final isUploading = state is ChatLoaded && state.isUploading;
              return IconButton(
                icon: const Icon(Icons.call),
                tooltip: 'Voice Call',
                onPressed:
                    isUploading
                        ? null
                        : () {
                          if (myId == null) return;
                          context.read<ChatBloc>().add(
                            SendMessage(
                              requestId: widget.requestId,
                              content: '__CALL_INVITE__',
                            ),
                          );
                          context.read<CallBloc>().add(
                            StartCall(
                              channelId: widget.requestId,
                              localUid: _uidFromUuid(myId),
                              isVideoCall: false,
                            ),
                          );
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EnhancedCallScreen(
                                    channelId: widget.requestId,
                                    isVideoCall: false,
                                  ),
                            ),
                            (route) => false,
                          );
                        },
              );
            },
          ),
          // Video Call button
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final isUploading = state is ChatLoaded && state.isUploading;
              return IconButton(
                icon: const Icon(Icons.videocam),
                tooltip: 'Video Call',
                onPressed:
                    isUploading
                        ? null
                        : () {
                          if (myId == null) return;
                          context.read<ChatBloc>().add(
                            SendMessage(
                              requestId: widget.requestId,
                              content: '__VIDEO_CALL_INVITE__',
                            ),
                          );
                          context.read<CallBloc>().add(
                            StartCall(
                              channelId: widget.requestId,
                              localUid: _uidFromUuid(myId),
                              isVideoCall: true,
                            ),
                          );
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EnhancedCallScreen(
                                    channelId: widget.requestId,
                                    isVideoCall: true,
                                  ),
                            ),
                            (route) => false,
                          );
                        },
              );
            },
          ),
          // End Session button
          // PopupMenuButton<String>(
          //   icon: const Icon(Icons.more_vert),
          //   onSelected: (value) {
          //     if (value == 'end_session') {
          //       _showEndSessionDialog();
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
      body: Column(
        children: [
          // Call indicator
          StreamBuilder<String?>(
            stream: CallStateManager().activeCallStream,
            builder: (context, snapshot) {
              final activeChannelId = snapshot.data;
              final isCallActive = activeChannelId == widget.requestId;

              if (isCallActive) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.green,
                  child: Row(
                    children: [
                      const Icon(Icons.call, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Call in progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => EnhancedCallScreen(
                                    channelId: widget.requestId,
                                  ),
                            ),
                          );
                        },
                        child: const Text(
                          'Return to call',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            // --- ADDED BlocListener for Chat Errors and Session End ---
            child: BlocListener<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is ChatLoaded && state.messages.isNotEmpty) {
                  final lastMessage = state.messages.last;
                  final content = lastMessage['content'];
                  final senderId = lastMessage['sender_id'];
                  final myId = Supabase.instance.client.auth.currentUser?.id;

                  // Check for Session Ended message from the other party
                  if (content == '__SESSION_ENDED__' && senderId != myId) {
                    // Check if we already handled this specific message ID to avoid loops
                    // (Though showDialog is modal, it's safer)
                    // We can just show the dialog.

                    // Ensure we aren't already showing a dialog or navigating
                    // Ideally we should track this state, but for now:
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Session Ended'),
                            content: const Text(
                              'The other party has ended the session.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  Navigator.of(context).pop(); // Close dialog

                                  // End call if active
                                  if (context.read<CallBloc>().state
                                      is CallOngoing) {
                                    context.read<CallBloc>().add(
                                      EndCall(isRemote: true),
                                    );
                                  }

                                  // await SessionService.endSession(
                                  //   requestId: widget.requestId,
                                  // );
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/main',
                                      (route) => false,
                                    );
                                  }
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                    );
                  }
                }

                if (state is ChatError) {
                  // Show error as snackbar with actionable message
                  String errorMessage = state.error.message;

                  // Make error messages more user-friendly
                  if (errorMessage.contains('timeout')) {
                    errorMessage =
                        'Upload timed out. Check your connection and try again.';
                  } else if (errorMessage.contains('File does not exist')) {
                    errorMessage =
                        'Could not access the file. Please try again.';
                  } else if (errorMessage.contains('File too large')) {
                    errorMessage = 'File is too large. Maximum size is 50MB.';
                  } else if (errorMessage.contains('storage')) {
                    errorMessage = 'Storage error. Please try again later.';
                  } else if (errorMessage.contains('not authenticated')) {
                    errorMessage = 'Session expired. Please log in again.';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage)),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Dismiss',
                        textColor: Colors.white,
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                      ),
                    ),
                  );
                }
              },
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ChatError &&
                      state.error.type != ErrorType.validation) {
                    // Only show full error widget if messages aren't already loaded
                    if (state is! ChatLoaded) {
                      return ErrorDisplayWidget(
                        error: state.error,
                        onRetry: () {
                          context.read<ChatBloc>().add(
                            LoadMessages(widget.requestId),
                          );
                        },
                        title: 'Failed to load messages',
                      );
                    }
                  }
                  if (state is ChatLoaded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    if (state.messages.isNotEmpty) {
                      final last = state.messages.last;
                      final lastId = last['id']?.toString();
                      final isInvite = last['content'] == '__CALL_INVITE__';
                      final isCallEnded = last['content'] == '__CALL_ENDED__';
                      final isFromMe = last['sender_id'] == myId;

                      if (isInvite &&
                          !isFromMe &&
                          lastId != null &&
                          _handledInviteMessageId != lastId) {
                        _handledInviteMessageId = lastId;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || myId == null) return;
                          context.read<CallBloc>().add(
                            StartCall(
                              channelId: widget.requestId,
                              localUid: _uidFromUuid(myId),
                            ),
                          );
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EnhancedCallScreen(
                                    channelId: widget.requestId,
                                  ),
                            ),
                            (route) => false,
                          );
                        });
                      }

                      if (isCallEnded &&
                          !isFromMe &&
                          lastId != null &&
                          _handledCallEndedMessageId != lastId) {
                        _handledCallEndedMessageId = lastId;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          context.read<CallBloc>().add(EndCall(isRemote: true));
                        });
                      }
                    }

                    if (state.messages.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start the conversation by sending a message',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final filteredMessages =
                        state.messages.where((message) {
                          final content = message['content'] as String?;
                          final senderId = message['sender_id'] as String?;

                          if (content == '__CALL_INVITE__' &&
                              senderId == myId) {
                            return false;
                          }
                          if (content == '__CALL_ENDED__') {
                            return false;
                          }
                          if (content == '__SESSION_ENDED__') {
                            return false;
                          }
                          return true;
                        }).toList();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredMessages.length,
                      itemBuilder: (context, index) {
                        final m = filteredMessages[index];
                        final isMe = m['sender_id'] == myId;
                        final messageId = m['id']?.toString() ?? 'local_$index';
                        return _ChatBubble(
                          key: ValueKey(messageId),
                          message: m,
                          isMe: isMe,
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          // Loading indicator for uploads
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              if (state is ChatLoaded && state.isUploading) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Uploading attachment...'),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Input Row
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Attach button
                  IconButton(
                    icon: Icon(Icons.add, color: ColorManager.primary2),
                    onPressed: _showAttachmentMenu,
                  ),
                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: ColorManager.primary2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  // Send Button
                  const SizedBox(width: 4),
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      final isUploading =
                          state is ChatLoaded && state.isUploading;
                      return IconButton(
                        icon: Icon(Icons.send, color: ColorManager.primary2),
                        onPressed: isUploading ? null : _send,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(
      SendMessage(
        requestId: widget.requestId,
        content: text,
        messageType: 'text',
      ),
    );
    _input.clear();
    // _saveSessionState();
    _scrollToBottom();
  }

  // void _saveSessionState() {
  //   SessionService.saveSession(
  //     requestId: widget.requestId,
  //     requesterId: widget.requesterId,
  //     interpreterId: widget.interpreterId,
  //     currentScreen: 'chat',
  //   );
  // }

  // void _showEndSessionDialog() {
  //   // Capture blocs to avoid using dialog context
  //   final chatBloc = context.read<ChatBloc>();
  //   final callBloc = context.read<CallBloc>();

  //   showDialog(
  //     context: context,
  //     builder:
  //         (dialogContext) => AlertDialog(
  //           title: const Text('End Session'),
  //           content: const Text(
  //             'Are you sure you want to end this session? You will be returned to the home screen.',
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(dialogContext).pop(),
  //               child: const Text('Cancel'),
  //             ),
  //             ElevatedButton(
  //               onPressed: () async {
  //                 try {
  //                   Navigator.of(dialogContext).pop();

  //                   // Send session ended message to notify the other party
  //                   chatBloc.add(
  //                     SendMessage(
  //                       requestId: widget.requestId,
  //                       content: '__SESSION_ENDED__',
  //                       messageType: 'text',
  //                     ),
  //                   );

  //                   if (callBloc.state is CallOngoing) {
  //                     callBloc.add(EndCall());
  //                     await Future.delayed(const Duration(milliseconds: 500));
  //                   }

  //                   await SessionService.endSession(
  //                     requestId: widget.requestId,
  //                   );

  //                   // Use the root navigator to ensure we exit the chat flow completely
  //                   if (mounted) {
  //                     Navigator.of(
  //                       context,
  //                       rootNavigator: true,
  //                     ).pushNamedAndRemoveUntil('/main', (route) => false);
  //                   }
  //                 } catch (e) {
  //                   log('Error ending session: $e');
  //                   if (mounted) {
  //                     Navigator.of(
  //                       context,
  //                       rootNavigator: true,
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

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handlePickImage();
                },
              ),
              // --- THIS IS THE FIX ---
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF Document'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handlePickFile(); // Will now only pick PDFs
                },
              ),
              // --- END OF FIX ---
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Voice Message'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showRecordingSheet();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        if (mounted) {
          context.read<ChatBloc>().add(
            UploadAndSendAttachment(
              requestId: widget.requestId,
              file: file,
              fileName: fileName,
              messageType: 'image',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  // --- THIS IS THE FIX ---
  // Restrict file picking to only PDFs
  Future<void> _handlePickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], // Only allow PDF files
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        if (mounted) {
          context.read<ChatBloc>().add(
            UploadAndSendAttachment(
              requestId: widget.requestId,
              file: file,
              fileName: fileName,
              messageType: 'file',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }
  // --- END OF FIX ---

  void _showRecordingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _RecordingSheet(
          onSend: (file, fileName) {
            log('onSend callback called with file: $fileName');
            log('File path: ${file.path}');
            try {
              final exists = file.existsSync();
              log('File exists: $exists');
            } catch (e) {
              log('Error checking file existence: $e');
            }
            log('RequestId: ${widget.requestId}');
            if (mounted) {
              log('Widget is mounted, adding UploadAndSendAttachment event');
              final bloc = context.read<ChatBloc>();
              log('ChatBloc instance: ${bloc.runtimeType}');
              log('Current bloc state: ${bloc.state.runtimeType}');
              bloc.add(
                UploadAndSendAttachment(
                  requestId: widget.requestId,
                  file: file,
                  fileName: fileName,
                  messageType: 'audio',
                ),
              );
              log('UploadAndSendAttachment event added to bloc');
            } else {
              log('ERROR: Widget is not mounted, cannot send attachment');
            }
          },
        );
      },
    );
  }
}

// --- NEW WIDGET: _ChatBubble (Stateful) ---
class _ChatBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _ChatBubble({super.key, required this.message, required this.isMe});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  String? _signedUrl;
  bool _isLoadingUrl = false;
  bool _errorLoadingUrl = false;
  String _messageType = 'text';
  String? _attachmentPath;
  String? _localPath; // <-- ADDED
  int _signedUrlRetryCount = 0;
  static const int _maxSignedUrlRetries = 3;

  @override
  void initState() {
    super.initState();
    _syncFromMessage(logSource: 'initState');
  }

  @override
  void didUpdateWidget(covariant _ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync when the message reference changes or signed URL updates
    if (!mapEquals(widget.message, oldWidget.message)) {
      setState(() {
        _syncFromMessage(logSource: 'didUpdateWidget');
      });
    }
  }

  void _syncFromMessage({required String logSource}) {
    final typeValue = widget.message['message_type'];
    _messageType =
        typeValue is String && typeValue.isNotEmpty ? typeValue : 'text';
    final attachmentValue = widget.message['attachment_url'];
    final newAttachmentPath =
        attachmentValue is String
            ? attachmentValue
            : attachmentValue?.toString();
    final signedUrlValue = widget.message['attachment_signed_url'];
    final existingSignedUrl =
        signedUrlValue is String ? signedUrlValue : signedUrlValue?.toString();

    log('_ChatBubble $_messageType sync ($logSource):');
    log('  message_id: ${widget.message['id']}');
    log('  attachment_url: $newAttachmentPath');
    log('  signed_url_present: ${existingSignedUrl != null}');

    final localPathValue = widget.message['local_path']; // <-- ADDED
    _localPath = localPathValue is String ? localPathValue : null; // <-- ADDED
    log('  local_path: $_localPath'); // <-- ADDED

    final pathChanged = newAttachmentPath != _attachmentPath;
    _attachmentPath = newAttachmentPath;

    if (existingSignedUrl != null && existingSignedUrl.isNotEmpty) {
      _signedUrl = existingSignedUrl;
      _isLoadingUrl = false;
      _errorLoadingUrl = false;
      _signedUrlRetryCount = 0;
    } else if (pathChanged) {
      _signedUrl = null;
    }

    final needsSignedUrl = _needsSignedUrl();
    if (_signedUrl == null && needsSignedUrl) {
      _isLoadingUrl = true;
      _errorLoadingUrl = false;
      // Fetch on next frame to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _getSignedUrl();
        }
      });
    }
  }

  bool _needsSignedUrl() {
    // If we have a local path, we don't strictly need a signed URL immediately
    if (_localPath != null && File(_localPath!).existsSync()) {
      return false;
    }
    return (_messageType == 'image' ||
            _messageType == 'audio' ||
            _messageType == 'file') &&
        (_attachmentPath?.isNotEmpty ?? false) &&
        _signedUrl == null &&
        !_isLoadingUrl &&
        !_errorLoadingUrl;
  }

  Future<void> _getSignedUrl() async {
    final attachmentPath = _attachmentPath;
    if (attachmentPath == null || attachmentPath.isEmpty) {
      log('Cannot fetch signed URL: attachment path is null or empty');
      return;
    }

    if (_signedUrlRetryCount >= _maxSignedUrlRetries) {
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
          _errorLoadingUrl = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingUrl = true;
        _errorLoadingUrl = false;
      });
    }

    try {
      // Add timeout to prevent infinite loading
      final url = await context
          .read<ChatService>()
          .createSignedUrl(attachmentPath)
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoadingUrl = false;
          _errorLoadingUrl = false;
          _signedUrlRetryCount = 0;
        });
      }
    } catch (e) {
      log(
        'Error fetching signed URL (attempt ${_signedUrlRetryCount + 1}): $e',
      );
      if (mounted) {
        _signedUrlRetryCount++;
        if (_signedUrlRetryCount < _maxSignedUrlRetries) {
          // Retry with backoff
          Future.delayed(
            Duration(seconds: _signedUrlRetryCount * 2),
            _getSignedUrl,
          );
        } else {
          setState(() {
            _isLoadingUrl = false;
            _errorLoadingUrl = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile =
        widget.message['user_profiles'] as Map<String, dynamic>?;
    final username = userProfile?['username'] ?? (widget.isMe ? 'You' : 'User');
    final profileImage = userProfile?['profile_image'] as String?;
    final messageStatus = widget.message['_status'] as String?;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    profileImage != null && profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                child:
                    profileImage == null || profileImage.isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Builder(
                builder: (context) {
                  final messageType = widget.message['message_type'] ?? 'text';
                  final isImage = messageType == 'image';
                  final isAudio = messageType == 'audio';
                  final isFile = messageType == 'file';

                  // For media types (image/audio/file), don't apply the outer blue/grey bubble
                  // because the inner widget has its own styled container. This avoids the
                  // "all blue" look on the sender side for audio messages.
                  final useOuterBubble = !(isImage || isAudio || isFile);

                  return Container(
                    padding:
                        useOuterBubble
                            ? const EdgeInsets.all(10)
                            : EdgeInsets.zero,
                    decoration:
                        useOuterBubble
                            ? BoxDecoration(
                              color:
                                  widget.isMe
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            )
                            : null,
                    child:
                        isImage
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildMessageContent(context),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!widget.isMe) ...[
                                  Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          widget.isMe
                                              ? Colors.white70
                                              : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                _buildMessageContent(context),
                                // Show status indicator for own messages
                                if (widget.isMe && messageStatus != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (messageStatus == 'sending') ...[
                                        const SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Sending...',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ] else if (messageStatus == 'sent') ...[
                                        const Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Sent',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final String content = widget.message['content'] ?? '';

    // Handle loading and error states for attachments
    if (_isLoadingUrl) {
      return const SizedBox(
        width: 100,
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_errorLoadingUrl) {
      return GestureDetector(
        onTap: () {
          if (!_isLoadingUrl) {
            _signedUrlRetryCount = 0;
            _getSignedUrl();
          }
        },
        child: Text(
          '[Error loading attachment - tap to retry]',
          style: TextStyle(
            color: widget.isMe ? Colors.white70 : Colors.red.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Use _signedUrl if it's available, otherwise check for local path
    final String? url = _signedUrl;
    final String? localPath = _localPath;
    final bool hasLocalFile = localPath != null && File(localPath).existsSync();
    final bool isSending = widget.message['_status'] == 'sending';

    switch (_messageType) {
      case 'image':
        if (url == null && !hasLocalFile) {
          return _buildAttachmentPlaceholder('image');
        }
        final heroTag = 'chat_image_${widget.message['id'] ?? url ?? content}';
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => ImagePreviewScreen(
                          imageUrl: url ?? '', // Handle null if using file
                          imageFile:
                              hasLocalFile
                                  ? File(localPath)
                                  : null, // Support local file
                          heroTag: heroTag,
                          fileName: content,
                        ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 250,
                    maxHeight: 250,
                  ),
                  child:
                      hasLocalFile
                          ? Image.file(
                            File(localPath),
                            errorBuilder: (context, error, stack) {
                              return const Icon(Icons.broken_image);
                            },
                          )
                          : Image.network(
                            url!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stack) {
                              return const Icon(Icons.broken_image);
                            },
                          ),
                ),
              ),
            ),
            if (isSending)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );

      case 'audio':
        if (url == null && !hasLocalFile) {
          return _buildAttachmentPlaceholder('audio');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: EmbeddedAudioPlayer(
                url: url ?? '',
                localFile: hasLocalFile ? File(localPath) : null,
                fileName: content,
                isMe: widget.isMe,
              ),
            ),
            if (isSending)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Text(
                  'Sending...',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isMe ? Colors.white70 : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );

      // --- THIS IS THE PDF FIX ---
      case 'file':
        if (url == null && !hasLocalFile) {
          return _buildAttachmentPlaceholder('file');
        }
        final bool isPdf = content.toLowerCase().endsWith('.pdf');

        return InkWell(
          onTap: () async {
            if (isPdf) {
              // Open PDF viewer
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (ctx) => PdfPreviewScreen(
                        url: url ?? '',
                        localFile: hasLocalFile ? File(localPath) : null,
                        fileName: content,
                      ),
                ),
              );
            } else {
              // Fallback to external launcher for other files
              if (hasLocalFile) {
                // Open local file if possible (might need platform channel or open_file package)
                // For now, we might not be able to easily open local non-pdf files without extra packages
                // But at least it won't show "Preparing..."
              } else if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            }
          },
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.blue.shade700 : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isPdf
                      ? Icons.picture_as_pdf
                      : Icons.attach_file, // Show PDF icon
                  color: widget.isMe ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content, // File name
                    style: TextStyle(
                      color: widget.isMe ? Colors.white : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      // --- END OF FIX ---

      case '__CALL_INVITE__':
        return Card(
          color: Colors.green.shade100,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isMe ? 'You started a call' : 'Incoming call...',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'text':
      default:
        return Text(
          content,
          style: TextStyle(color: widget.isMe ? Colors.white : Colors.black87),
        );
    }
  }

  Widget _buildAttachmentPlaceholder(String type) {
    final isSelf = widget.isMe;
    final textColor = isSelf ? Colors.white70 : Colors.black54;
    final label = () {
      switch (type) {
        case 'audio':
          return 'voice message';
        case 'file':
          return 'document';
        default:
          return 'image';
      }
    }();
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelf ? Colors.blue.shade600 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Preparing $label...',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW WIDGET: _RecordingSheet ---
class _RecordingSheet extends StatefulWidget {
  final Function(File file, String fileName) onSend;

  const _RecordingSheet({required this.onSend});

  @override
  State<_RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends State<_RecordingSheet> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await perm_handler.Permission.microphone.request();
    if (hasPermission.isGranted) {
      try {
        final dir = await getTemporaryDirectory();
        final fileName =
            'voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _filePath = '${dir.path}/$fileName';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
          ), // Standard AAC encoder
          path: _filePath!,
        );

        setState(() => _isRecording = true);
        _startTimer();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting recording: $e')),
          );
        }
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _filePath = path;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _sendRecording() {
    if (_filePath != null) {
      final file = File(_filePath!);
      // Use path separator that works on all platforms
      final fileName = _filePath!.split(Platform.pathSeparator).last;
      log('Sending voice recording: $fileName from path: $_filePath');
      widget.onSend(file, fileName);
      Navigator.of(context).pop();
    } else {
      log('Error: _filePath is null when trying to send recording');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Recording file not found')),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRecording ? 'Recording...' : 'Recording complete',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(fontSize: 40, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording)
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red, size: 40),
                  onPressed: _stopRecording,
                ),
              if (!_isRecording) ...[
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.grey.shade700,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: ColorManager.primary2,
                    size: 30,
                  ),
                  onPressed: _sendRecording,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
