import 'dart:typed_data';

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
  final String? country;
  final List<String> languages;
  final Map<String, String?> fluency;
  final List<int> skillIds;
  final List<int> specializationIds;
  final String role;
  final String? voiceSampleUrl;
  final String? voicePrompt;
  final String? certificateUrl;
  final String? medicalCertificateUrl;
  // Local paths for deferred upload
  final String? voiceSamplePath;
  final String? certificatePath;
  final String? medicalCertificatePath;
  // Web: raw bytes for certificate upload (since path is unavailable on web)
  final Uint8List? certificateBytes;
  final String? certificateName;
  final Uint8List? medicalCertificateBytes;
  final String? medicalCertificateName;
  final String? bio;
  final int? yearsExperience;
  final String? preferredShift;
  final List<String>? shiftAvailability;
  final bool? isOnlineNow;
  final String? employmentType; // 'volunteer' or 'paid'

  RegisterSubmitted({
    required this.email,
    required this.password,
    required this.username,
    required this.gender,
    this.country,
    required this.languages,
    required this.fluency,
    required this.skillIds,
    required this.specializationIds,
    required this.role,
    this.voiceSampleUrl,
    this.voicePrompt,
    this.certificateUrl,
    this.medicalCertificateUrl,
    this.voiceSamplePath,
    this.certificatePath,
    this.medicalCertificatePath,
    this.certificateBytes,
    this.certificateName,
    this.medicalCertificateBytes,
    this.medicalCertificateName,
    this.bio,
    this.yearsExperience,
    this.preferredShift,
    this.shiftAvailability,
    this.isOnlineNow,
    this.employmentType,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    username,
    gender,
    country,
    languages,
    fluency,
    skillIds,
    specializationIds,
    role,
    voiceSampleUrl,
    voicePrompt,
    certificateUrl,
    medicalCertificateUrl,
    voiceSamplePath,
    certificatePath,
    medicalCertificatePath,
    certificateBytes,
    certificateName,
    medicalCertificateBytes,
    medicalCertificateName,
    bio,
    yearsExperience,
    preferredShift,
    shiftAvailability,
    isOnlineNow,
    employmentType,
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

class OrganizationRegisterSubmitted extends RegisterEvent {
  final String email;
  final String password;
  final String username;
  final String organizationName;
  final String organizationEmail;
  final String? organizationPhone;
  final String? organizationAddress;

  OrganizationRegisterSubmitted({
    required this.email,
    required this.password,
    required this.username,
    required this.organizationName,
    required this.organizationEmail,
    this.organizationPhone,
    this.organizationAddress,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    username,
    organizationName,
    organizationEmail,
    organizationPhone,
    organizationAddress,
  ];
}

/// Event for doctors registering with an organization invite code
class DoctorWithInviteRegisterSubmitted extends RegisterEvent {
  final String email;
  final String password;
  final String username;
  final String organizationId;
  final String role;
  final String? inviteId;

  DoctorWithInviteRegisterSubmitted({
    required this.email,
    required this.password,
    required this.username,
    required this.organizationId,
    required this.role,
    this.inviteId,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    username,
    organizationId,
    role,
    inviteId,
  ];
}
