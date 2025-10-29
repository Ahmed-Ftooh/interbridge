class DocumentTranslationRequest {
  final String id;
  final String requesterId;
  final String fromLanguage;
  final String toLanguage;
  final String? specialization;
  final String? text;
  final String? title;
  final String? comment;
  final String? translationMethod; // 'text', 'pdf', 'image', 'voice'
  final String? fileUrl;
  final String? fileType; // File extension or mime type
  final String? fileName; // Original filename
  final String status;
  final String? acceptedBy;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? translatedText;
  final String? translatedFileUrl;

  DocumentTranslationRequest({
    required this.id,
    required this.requesterId,
    required this.fromLanguage,
    required this.toLanguage,
    this.specialization,
    this.text,
    this.title,
    this.comment,
    this.translationMethod,
    this.fileUrl,
    this.fileType,
    this.fileName,
    required this.status,
    this.acceptedBy,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.translatedText,
    this.translatedFileUrl,
  });

  factory DocumentTranslationRequest.fromJson(Map<String, dynamic> json) {
    return DocumentTranslationRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      fromLanguage: json['from_language'] as String,
      toLanguage: json['to_language'] as String,
      specialization: json['specialization'] as String?,
      text: json['text'] as String?,
      title: json['title'] as String?,
      comment: json['comment'] as String?,
      translationMethod: json['translation_method'] as String?,
      fileUrl: json['file_url'] as String?,
      fileType: json['file_type'] as String?,
      fileName: json['file_name'] as String?,
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
      translatedText: json['translated_text'] as String?,
      translatedFileUrl: json['translated_file_url'] as String?,
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
      'title': title,
      'comment': comment,
      'translation_method': translationMethod,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_name': fileName,
      'status': status,
      'accepted_by': acceptedBy,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'translated_text': translatedText,
      'translated_file_url': translatedFileUrl,
    };
  }

  DocumentTranslationRequest copyWith({
    String? id,
    String? requesterId,
    String? fromLanguage,
    String? toLanguage,
    String? specialization,
    String? text,
    String? title,
    String? comment,
    String? translationMethod,
    String? fileUrl,
    String? fileType,
    String? fileName,
    String? status,
    String? acceptedBy,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? translatedText,
    String? translatedFileUrl,
  }) {
    return DocumentTranslationRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      fromLanguage: fromLanguage ?? this.fromLanguage,
      toLanguage: toLanguage ?? this.toLanguage,
      specialization: specialization ?? this.specialization,
      text: text ?? this.text,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      translationMethod: translationMethod ?? this.translationMethod,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      translatedText: translatedText ?? this.translatedText,
      translatedFileUrl: translatedFileUrl ?? this.translatedFileUrl,
    );
  }
}
