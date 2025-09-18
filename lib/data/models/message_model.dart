class ChatMessage {
  final String id;
  final String senderId;
  final String requestId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.requestId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      requestId: json['request_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
