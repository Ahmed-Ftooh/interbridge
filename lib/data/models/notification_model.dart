class NotificationModel {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final String type;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] ?? {},
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isRead: json['is_read'] ?? false,
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'type': type,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    String? type,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}
