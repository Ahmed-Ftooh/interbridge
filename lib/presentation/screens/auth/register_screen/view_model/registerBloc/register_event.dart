import 'package:equatable/equatable.dart';

class RegisterEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class RegisterSubmitted extends RegisterEvent {
  final String email;
  final String password;
  final String username;
  final String gender;
  final List<String> languages;
  final Map<String, String?> fluency;
  final List<int> skillIds;
  final List<int> specializationIds;
  final String role;
  final String? voiceSampleUrl;
  final String? voicePrompt;
  final String? certificateUrl;
  // Local paths for deferred upload
  final String? voiceSamplePath;
  final String? certificatePath;
  final String? bio;
  final int? yearsExperience;

  RegisterSubmitted({
    required this.email,
    required this.password,
    required this.username,
    required this.gender,
    required this.languages,
    required this.fluency,
    required this.skillIds,
    required this.specializationIds,
    required this.role,
    this.voiceSampleUrl,
    this.voicePrompt,
    this.certificateUrl,
    this.voiceSamplePath,
    this.certificatePath,
    this.bio,
    this.yearsExperience,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    username,
    gender,
    languages,
    fluency,
    skillIds,
    specializationIds,
    role,
    voiceSampleUrl,
    voicePrompt,
    certificateUrl,
    voiceSamplePath,
    certificatePath,
    bio,
    yearsExperience,
  ];
}

class RequesterRegisterSubmitted extends RegisterEvent {
  final String email;
  final String password;
  final String username;

  RequesterRegisterSubmitted({
    required this.email,
    required this.password,
    required this.username,
  });

  @override
  List<Object?> get props => [email, password, username];
}
