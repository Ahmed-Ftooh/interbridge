import 'package:equatable/equatable.dart';
import 'package:interbridge/data/models/user_profile.dart';

/// Base class for all requester profile states
abstract class RequesterProfileState extends Equatable {
  const RequesterProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class RequesterProfileInitial extends RequesterProfileState {}

/// Loading state while fetching profile data
class RequesterProfileLoading extends RequesterProfileState {}

/// Main state when profile data is loaded
class RequesterProfileLoaded extends RequesterProfileState {
  final UserProfile profile;
  final String? userEmail;
  final String? organizationName;
  final String? organizationRole;

  // UI state flags
  final bool isSaving;
  final String? message;
  final bool isError;

  const RequesterProfileLoaded({
    required this.profile,
    this.userEmail,
    this.organizationName,
    this.organizationRole,
    this.isSaving = false,
    this.message,
    this.isError = false,
  });

  @override
  List<Object?> get props => [
    profile,
    userEmail,
    organizationName,
    organizationRole,
    isSaving,
    message,
    isError,
  ];

  RequesterProfileLoaded copyWith({
    UserProfile? profile,
    String? userEmail,
    String? organizationName,
    String? organizationRole,
    bool? isSaving,
    String? message,
    bool? isError,
  }) {
    return RequesterProfileLoaded(
      profile: profile ?? this.profile,
      userEmail: userEmail ?? this.userEmail,
      organizationName: organizationName ?? this.organizationName,
      organizationRole: organizationRole ?? this.organizationRole,
      isSaving: isSaving ?? this.isSaving,
      message: message,
      isError: isError ?? this.isError,
    );
  }
}

/// Error state when profile loading fails
class RequesterProfileError extends RequesterProfileState {
  final String message;

  const RequesterProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State while picking image
class RequesterImagePicking extends RequesterProfileState {
  final RequesterProfileLoaded previousState;

  const RequesterImagePicking(this.previousState);

  @override
  List<Object?> get props => [previousState];
}

/// State while uploading image
class RequesterImageUploading extends RequesterProfileState {
  final RequesterProfileLoaded previousState;

  const RequesterImageUploading(this.previousState);

  @override
  List<Object?> get props => [previousState];
}
