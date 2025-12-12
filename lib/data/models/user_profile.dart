class UserProfile {
  final String id;
  final String? role;
  final String? username;
  final String? profileImage;
  final String? gender;
  final String? country;
  final DateTime? createdAt;
  final String? institutionId;

  UserProfile({
    required this.id,
    required this.role,
    required this.username,
    this.profileImage,
    this.gender,
    this.country,
    this.createdAt,
    this.institutionId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['user_id'],
    username: json['username'],
    role: json['role'],
    profileImage: json['profile_image'],
    gender: json['gender'],
    country: json['country'],
    institutionId: json['institution_id'],
    createdAt:
        json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'username': username,
    'role': role,
    'profile_image': profileImage ?? '',
    'gender': gender ?? '',
    'country': country,
    'institution_id': institutionId,
    // Don't include created_at as it has a default value
  };
}
