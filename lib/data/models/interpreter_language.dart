class InterpreterLanguage {
  final String userId;
  final int languageId;
  final int fluencyId;

  InterpreterLanguage({
    required this.userId,
    required this.languageId,
    required this.fluencyId,
  });

  factory InterpreterLanguage.fromJson(Map<String, dynamic> json) =>
      InterpreterLanguage(
        userId: json['user_id'],
        languageId: json['language_id'],
        fluencyId: json['fluency_id'],
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'language_id': languageId,
    'fluency_id': fluencyId,
  };
}
