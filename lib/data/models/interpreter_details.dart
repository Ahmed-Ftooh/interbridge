class InterpreterDetails {
  final String userId;

  InterpreterDetails({required this.userId});

  factory InterpreterDetails.fromJson(Map<String, dynamic> json) =>
      InterpreterDetails(userId: json['user_id']);

  Map<String, dynamic> toJson() => {'user_id': userId};
}
