import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bolc.dart';
import 'package:interbridge/presentation/screens/main/chat/call_view.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessages(widget.requestId));
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
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallScreen(channelId: widget.requestId),
                    ),
                  );
                },
              );
            },
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
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final m = state.messages[index];
                      final isMe = m['sender_id'] == myId;
                      final userProfile =
                          m['user_profiles'] as Map<String, dynamic>?;
                      final username =
                          userProfile?['username'] ?? 'Unknown User';
                      final profileImage =
                          userProfile?['profile_image'] as String?;
                      final role = userProfile?['role'] as String?;

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
                              if (isMe) ...[
                                const SizedBox(width: 8),
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
                              ],
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
  }
}
