class InterpreterLanguage {
  final String userId;
  final int languageId;
  final int fluencyId;

  InterpreterLanguage({
    required this.userId,
    required this.languageId,
    required this.fluencyId,
  });

  factory InterpreterLanguage.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    final rawFluency =
        json.containsKey('fluency_id')
            ? json['fluency_id']
            : json['fluency_level_id'];

    return InterpreterLanguage(
      userId: json['user_id']?.toString() ?? '',
      languageId: parseInt(json['language_id'], 0),
      fluencyId: parseInt(rawFluency, 1),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'language_id': languageId,
    'fluency_id': fluencyId,
  };
}
