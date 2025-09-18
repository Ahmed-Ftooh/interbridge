class InterpreterRequest {
  final String id;
  final String requesterId;
  final String fromLanguage;
  final String toLanguage;
  final String? specialization;
  final String urgency;
  final String status; // 'pending', 'accepted', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final String? description;

  InterpreterRequest({
    required this.id,
    required this.requesterId,
    required this.fromLanguage,
    required this.toLanguage,
    this.specialization,
    required this.urgency,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.acceptedBy,
    this.description,
  });

  factory InterpreterRequest.fromJson(Map<String, dynamic> json) {
    return InterpreterRequest(
      id: json['id'],
      requesterId: json['requester_id'],
      fromLanguage: json['from_language'],
      toLanguage: json['to_language'],
      specialization: json['specialization'],
      urgency: json['urgency'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      acceptedAt:
          json['accepted_at'] != null
              ? DateTime.parse(json['accepted_at'])
              : null,
      acceptedBy: json['accepted_by'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'from_language': fromLanguage,
      'to_language': toLanguage,
      'specialization': specialization,
      'urgency': urgency,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'accepted_by': acceptedBy,
      'description': description,
    };
  }

  InterpreterRequest copyWith({
    String? id,
    String? requesterId,
    String? fromLanguage,
    String? toLanguage,
    String? specialization,
    String? urgency,
    String? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? description,
  }) {
    return InterpreterRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      fromLanguage: fromLanguage ?? this.fromLanguage,
      toLanguage: toLanguage ?? this.toLanguage,
      specialization: specialization ?? this.specialization,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      description: description ?? this.description,
    );
  }
}
