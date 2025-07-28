class InterpreterSkill {
  final String userId;
  final int skillId;

  InterpreterSkill({required this.userId, required this.skillId});

  factory InterpreterSkill.fromJson(Map<String, dynamic> json) =>
      InterpreterSkill(userId: json['user_id'], skillId: json['skill_id']);

  Map<String, dynamic> toJson() => {'user_id': userId, 'skill_id': skillId};
}
