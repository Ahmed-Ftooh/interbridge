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
