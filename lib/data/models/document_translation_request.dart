class DocumentTranslationRequest {
  final String id;
  final String requesterId;
  final String fromLanguage;
  final String toLanguage;
  final String? specialization;
  final String? text;
  final String? fileUrl;
  final String status;
  final String? acceptedBy;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  DocumentTranslationRequest({
    required this.id,
    required this.requesterId,
    required this.fromLanguage,
    required this.toLanguage,
    this.specialization,
    this.text,
    this.fileUrl,
    required this.status,
    this.acceptedBy,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory DocumentTranslationRequest.fromJson(Map<String, dynamic> json) {
    return DocumentTranslationRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      fromLanguage: json['from_language'] as String,
      toLanguage: json['to_language'] as String,
      specialization: json['specialization'] as String?,
      text: json['text'] as String?,
      fileUrl: json['file_url'] as String?,
      status: json['status'] as String,
      acceptedBy: json['accepted_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt:
          json['accepted_at'] != null
              ? DateTime.parse(json['accepted_at'] as String)
              : null,
      completedAt:
          json['completed_at'] != null
              ? DateTime.parse(json['completed_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'from_language': fromLanguage,
      'to_language': toLanguage,
      'specialization': specialization,
      'text': text,
      'file_url': fileUrl,
      'status': status,
      'accepted_by': acceptedBy,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  DocumentTranslationRequest copyWith({
    String? id,
    String? requesterId,
    String? fromLanguage,
    String? toLanguage,
    String? specialization,
    String? text,
    String? fileUrl,
    String? status,
    String? acceptedBy,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return DocumentTranslationRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      fromLanguage: fromLanguage ?? this.fromLanguage,
      toLanguage: toLanguage ?? this.toLanguage,
      specialization: specialization ?? this.specialization,
      text: text ?? this.text,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
