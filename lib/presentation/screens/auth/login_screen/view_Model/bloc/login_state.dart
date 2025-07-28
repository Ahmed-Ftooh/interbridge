import 'package:equatable/equatable.dart';

// States
class LoginState extends Equatable {
  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool isRememberMeChecked;
  final bool isSubmitting;
  final bool isSuccess;
  final bool isFailure;
  final String? errorMessage;

  const LoginState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = true,
    this.isRememberMeChecked = false,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isFailure = false,
    this.errorMessage,
  });

  LoginState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? isRememberMeChecked,
    bool? isSubmitting,
    bool? isSuccess,
    bool? isFailure,
    String? errorMessage,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isRememberMeChecked: isRememberMeChecked ?? this.isRememberMeChecked,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isFailure: isFailure ?? this.isFailure,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    isPasswordVisible,
    isRememberMeChecked,
    isSubmitting,
    isSuccess,
    isFailure,
    errorMessage,
  ];
}
