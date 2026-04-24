class InterpreterDetails {
  final String userId;
  final String? certificateUrl;
  final String? bio;
  final int? yearsExperience;
  final bool isVerified;
  final bool isSuspended;

  InterpreterDetails({
    required this.userId,
    this.certificateUrl,
    this.bio,
    this.yearsExperience,
    this.isVerified = false,
    this.isSuspended = false,
  });

  factory InterpreterDetails.fromJson(Map<String, dynamic> json) =>
      InterpreterDetails(
        userId: json['user_id'],
        certificateUrl: json['certificate_url'],
        bio: json['bio'],
        yearsExperience: json['years_experience'],
        isVerified: json['is_verified'] ?? false,
        isSuspended: json['is_suspended'] ?? false,
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (certificateUrl != null) 'certificate_url': certificateUrl,
    if (bio != null) 'bio': bio,
    if (yearsExperience != null) 'years_experience': yearsExperience,
    'is_verified': isVerified,
    'is_suspended': isSuspended,
  };
}
