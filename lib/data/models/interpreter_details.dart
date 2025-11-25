class InterpreterDetails {
  final String userId;
  final String? certificateUrl;
  final String? bio;
  final int? yearsExperience;

  InterpreterDetails({
    required this.userId,
    this.certificateUrl,
    this.bio,
    this.yearsExperience,
  });

  factory InterpreterDetails.fromJson(Map<String, dynamic> json) =>
      InterpreterDetails(
        userId: json['user_id'],
        certificateUrl: json['certificate_url'],
        bio: json['bio'],
        yearsExperience: json['years_experience'],
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (certificateUrl != null) 'certificate_url': certificateUrl,
    if (bio != null) 'bio': bio,
    if (yearsExperience != null) 'years_experience': yearsExperience,
  };
}
