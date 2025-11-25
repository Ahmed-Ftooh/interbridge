class InterpreterLanguageSkill {
  final String userId;
  final int languageId;
  final int skillId;

  InterpreterLanguageSkill({
    required this.userId,
    required this.languageId,
    required this.skillId,
  });

  factory InterpreterLanguageSkill.fromJson(Map<String, dynamic> json) {
    return InterpreterLanguageSkill(
      userId: json['user_id'] as String,
      languageId: json['language_id'] as int,
      skillId: json['skill_id'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'language_id': languageId,
    'skill_id': skillId,
  };
}
