import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';

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

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  String? _handledInviteMessageId;
  String? _handledCallEndedMessageId;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessages(widget.requestId));
    _saveSessionState();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          // Call button
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {
                  // Send a special chat message that renders a Join button on the other side
                  context.read<ChatBloc>().add(
                    SendMessage(
                      requestId: widget.requestId,
                      content: '__CALL_INVITE__',
                    ),
                  );
                  // Open enhanced call screen locally
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (_) => EnhancedCallScreen(
                            channelId: widget.requestId,
                            chatBloc: context.read<ChatBloc>(),
                          ),
                    ),
                  );
                },
              );
            },
          ),
          // End Session button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'end_session') {
                _showEndSessionDialog();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'end_session',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 8),
                        Text('End Session'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ChatError) {
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
                if (state is ChatLoaded) {
                  // Auto-join if the latest message is a call invite from the other user
                  if (state.messages.isNotEmpty) {
                    final last = state.messages.last;
                    final lastId = last['id']?.toString();
                    final isInvite = last['content'] == '__CALL_INVITE__';
                    final isCallEnded = last['content'] == '__CALL_ENDED__';
                    final isFromMe = last['sender_id'] == myId;

                    // Handle call invite
                    if (isInvite &&
                        !isFromMe &&
                        lastId != null &&
                        _handledInviteMessageId != lastId) {
                      _handledInviteMessageId = lastId;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => EnhancedCallScreen(
                                  channelId: widget.requestId,
                                  chatBloc: context.read<ChatBloc>(),
                                ),
                          ),
                        );
                      });
                    }

                    // Handle call ended notification
                    if (isCallEnded &&
                        !isFromMe &&
                        lastId != null &&
                        _handledCallEndedMessageId != lastId) {
                      _handledCallEndedMessageId = lastId;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        // Close any open call screens
                        Navigator.of(context).popUntil((route) {
                          return route.isFirst;
                        });
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
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter out call invite messages that are no longer relevant
                  final filteredMessages =
                      state.messages.where((message) {
                        // Keep all messages except call invites that are from the current user
                        // (call invites from others are shown as join buttons)
                        if (message['content'] == '__CALL_INVITE__' &&
                            message['sender_id'] == myId) {
                          return false; // Hide call invites from current user
                        }
                        return true; // Keep all other messages
                      }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      final m = filteredMessages[index];
                      final isMe = m['sender_id'] == myId;
                      final userProfile =
                          m['user_profiles'] as Map<String, dynamic>?;
                      final username =
                          userProfile?['username'] ?? (isMe ? 'You' : 'User');
                      final profileImage =
                          userProfile?['profile_image'] as String?;

                      // Render call invite as a button card for the recipient
                      if (m['content'] == '__CALL_INVITE__' && !isMe) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          child: Card(
                            color: Colors.green.shade50,
                            child: ListTile(
                              leading: const Icon(
                                Icons.call,
                                color: Colors.green,
                              ),
                              title: const Text('Incoming call'),
                              subtitle: Text(
                                'Tap to join — Channel: ${widget.requestId}',
                              ),
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => EnhancedCallScreen(
                                          channelId: widget.requestId,
                                          chatBloc: context.read<ChatBloc>(),
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      profileImage != null &&
                                              profileImage.isNotEmpty
                                          ? NetworkImage(profileImage)
                                          : null,
                                  child:
                                      profileImage == null ||
                                              profileImage.isEmpty
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isMe) ...[
                                        Text(
                                          username,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isMe
                                                    ? Colors.white70
                                                    : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        m['content'] ?? '',
                                        style: TextStyle(
                                          color:
                                              isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Remove the profile image from the sender's side (isMe)
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ),
              ],
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
      SendMessage(requestId: widget.requestId, content: text),
    );
    _input.clear();
    _saveSessionState();
  }

  void _saveSessionState() {
    SessionService.saveSession(
      requestId: widget.requestId,
      requesterId: widget.requesterId,
      interpreterId: widget.interpreterId,
      currentScreen: 'chat',
    );
  }

  void _showEndSessionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('End Session'),
            content: const Text(
              'Are you sure you want to end this session? You will be returned to the home screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Close the dialog first
                    Navigator.of(context).pop();

                    // End the session
                    await SessionService.endSession();

                    // Ensure we're still mounted before navigating
                    if (mounted) {
                      // Clear the entire navigation stack and go to home
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/main', (route) => false);
                    }
                  } catch (e) {
                    // If there's an error, still try to navigate back
                    if (mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/main', (route) => false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Session'),
              ),
            ],
          ),
    );
  }
}
