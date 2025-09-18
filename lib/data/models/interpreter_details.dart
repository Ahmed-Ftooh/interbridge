class InterpreterDetails {
  final String userId;
  final String? certificateUrl;

  InterpreterDetails({required this.userId, this.certificateUrl});

  factory InterpreterDetails.fromJson(Map<String, dynamic> json) =>
      InterpreterDetails(
        userId: json['user_id'],
        certificateUrl: json['certificate_url'],
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (certificateUrl != null) 'certificate_url': certificateUrl,
  };
}
