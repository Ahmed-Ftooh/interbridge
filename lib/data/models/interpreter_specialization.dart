class InterpreterSpecialization {
  final String userId;
  final int specializationId;

  InterpreterSpecialization({
    required this.userId,
    required this.specializationId,
  });

  factory InterpreterSpecialization.fromJson(Map<String, dynamic> json) =>
      InterpreterSpecialization(
        userId: json['user_id'],
        specializationId: json['specialization_id'],
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'specialization_id': specializationId,
  };
}
