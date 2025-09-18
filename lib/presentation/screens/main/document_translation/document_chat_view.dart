import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/document_translation_request.dart';

class DocumentChatView extends StatefulWidget {
  final DocumentTranslationRequest request;
  final bool isInterpreter;

  const DocumentChatView({
    super.key,
    required this.request,
    required this.isInterpreter,
  });

  @override
  State<DocumentChatView> createState() => _DocumentChatViewState();
}

class _DocumentChatViewState extends State<DocumentChatView> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final welcomeMessage =
        widget.isInterpreter
            ? 'You have accepted this document translation request. You can now communicate with the requester.'
            : 'Your document translation request has been accepted. You can now communicate with the interpreter.';

    _messages.add(
      ChatMessage(
        text: welcomeMessage,
        isFromUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = ChatMessage(
      text: _messageController.text.trim(),
      isFromUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });

    _messageController.clear();
    _scrollToBottom();

    // Simulate response (in real app, this would be sent to backend)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final response = ChatMessage(
          text:
              widget.isInterpreter
                  ? 'I understand your request. I will start working on the translation.'
                  : 'Thank you for accepting my request. I look forward to working with you.',
          isFromUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(response);
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Translation Chat - ${widget.request.fromLanguage} → ${widget.request.toLanguage}',
        ),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Request Info Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSize.s16),
            padding: const EdgeInsets.all(AppSize.s16),
            decoration: BoxDecoration(
              color: ColorManager.primary2.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSize.s12),
              border: Border.all(color: ColorManager.primary2.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Translation Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.primary2,
                  ),
                ),
                const SizedBox(height: AppSize.s8),
                Text(
                  'From: ${widget.request.fromLanguage}',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  'To: ${widget.request.toLanguage}',
                  style: TextStyle(fontSize: 14),
                ),
                if (widget.request.specialization != null)
                  Text(
                    'Specialization: ${widget.request.specialization}',
                    style: TextStyle(fontSize: 14),
                  ),
                Text(
                  'Status: ${widget.request.status}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        widget.request.status == 'accepted'
                            ? Colors.green
                            : Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppSize.s16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(AppSize.s16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppSize.s24),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSize.s16,
                        vertical: AppSize.s12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: AppSize.s8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: ColorManager.primary2,
                  foregroundColor: Colors.white,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isFromUser = message.isFromUser;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSize.s12),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ColorManager.primary2,
              child: Text(
                widget.isInterpreter ? 'I' : 'R',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSize.s8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSize.s16,
                vertical: AppSize.s12,
              ),
              decoration: BoxDecoration(
                color:
                    isFromUser
                        ? ColorManager.primary2
                        : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSize.s16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isFromUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isFromUser) ...[
            const SizedBox(width: AppSize.s8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              child: Text(
                'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isFromUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isFromUser,
    required this.timestamp,
  });
}
