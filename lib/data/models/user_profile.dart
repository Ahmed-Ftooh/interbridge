class UserProfile {
  final String id;
  final String? role;
  final String? username;
  final String? profileImage;
  final String? gender;

  UserProfile({
    required this.id,
    required this.role,
    required this.username,
    this.profileImage,
    this.gender,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['user_id'],
    username: json['username'],
    role: json['role'],
    profileImage: json['profile_image'],
    gender: json['gender'],
  );

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'username': username,
    'role': role,
    'profile_image': profileImage,
    'gender': gender,
  };
}
