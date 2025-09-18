class UserProfile {
  final String id;
  final String? role;
  final String? username;
  final String? profileImage;
  final String? gender;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.role,
    required this.username,
    this.profileImage,
    this.gender,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['user_id'],
    username: json['username'],
    role: json['role'],
    profileImage: json['profile_image'],
    gender: json['gender'],
    createdAt:
        json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'username': username,
    'role': role,
    'profile_image': profileImage ?? '',
    'gender': gender ?? '',
    // Don't include created_at as it has a default value
  };
}
