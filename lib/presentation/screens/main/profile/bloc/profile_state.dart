import 'package:equatable/equatable.dart';
import 'package:interbridge/data/models/fluency_level.dart';
import 'package:interbridge/data/models/interpreter_details.dart';
import 'package:interbridge/data/models/interpreter_language.dart';
import 'package:interbridge/data/models/interpreter_skill.dart';
import 'package:interbridge/data/models/interpreter_specialization.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/models/skill.dart';
import 'package:interbridge/data/models/specialization.dart';
import 'package:interbridge/data/models/user_profile.dart';

/// Base class for all profile states
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class ProfileInitial extends ProfileState {}

/// Loading state while fetching profile data
class ProfileLoading extends ProfileState {}

/// Main state when profile data is loaded
class ProfileLoaded extends ProfileState {
  final UserProfile profile;
  final String? userEmail;

  // Interpreter-specific data (null for non-interpreters)
  final InterpreterDetails? interpreterDetails;
  final List<InterpreterLanguage> interpreterLanguages;
  final List<InterpreterSpecialization> interpreterSpecializations;
  final List<InterpreterSkill> interpreterSkills;
  final Map<int, Set<int>> languageSkillMap;

  // Reference data for dropdowns/selection
  final List<Language> availableLanguages;
  final List<Specialization> availableSpecializations;
  final List<Skill> availableSkills;
  final List<FluencyLevel> fluencyLevels;

  // UI state flags
  final bool isSaving;
  final String? message;
  final bool isError;

  const ProfileLoaded({
    required this.profile,
    this.userEmail,
    this.interpreterDetails,
    this.interpreterLanguages = const [],
    this.interpreterSpecializations = const [],
    this.interpreterSkills = const [],
    this.languageSkillMap = const {},
    this.availableLanguages = const [],
    this.availableSpecializations = const [],
    this.availableSkills = const [],
    this.fluencyLevels = const [],
    this.isSaving = false,
    this.message,
    this.isError = false,
  });

  bool get isInterpreter => profile.role?.toLowerCase() == 'interpreter';

  int get defaultFluencyId =>
      fluencyLevels.isNotEmpty ? fluencyLevels.first.id : 1;

  @override
  List<Object?> get props => [
    profile,
    userEmail,
    interpreterDetails,
    interpreterLanguages,
    interpreterSpecializations,
    interpreterSkills,
    languageSkillMap,
    availableLanguages,
    availableSpecializations,
    availableSkills,
    fluencyLevels,
    isSaving,
    message,
    isError,
  ];

  ProfileLoaded copyWith({
    UserProfile? profile,
    String? userEmail,
    InterpreterDetails? interpreterDetails,
    List<InterpreterLanguage>? interpreterLanguages,
    List<InterpreterSpecialization>? interpreterSpecializations,
    List<InterpreterSkill>? interpreterSkills,
    Map<int, Set<int>>? languageSkillMap,
    List<Language>? availableLanguages,
    List<Specialization>? availableSpecializations,
    List<Skill>? availableSkills,
    List<FluencyLevel>? fluencyLevels,
    bool? isSaving,
    String? message,
    bool? isError,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      userEmail: userEmail ?? this.userEmail,
      interpreterDetails: interpreterDetails ?? this.interpreterDetails,
      interpreterLanguages: interpreterLanguages ?? this.interpreterLanguages,
      interpreterSpecializations:
          interpreterSpecializations ?? this.interpreterSpecializations,
      interpreterSkills: interpreterSkills ?? this.interpreterSkills,
      languageSkillMap: languageSkillMap ?? this.languageSkillMap,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      availableSpecializations:
          availableSpecializations ?? this.availableSpecializations,
      availableSkills: availableSkills ?? this.availableSkills,
      fluencyLevels: fluencyLevels ?? this.fluencyLevels,
      isSaving: isSaving ?? this.isSaving,
      message: message, // Don't use ?? here to allow clearing message
      isError: isError ?? false,
    );
  }

  /// Create a copy that clears any message
  ProfileLoaded clearMessage() {
    return copyWith(message: null, isError: false);
  }
}

/// Error state when profile loading fails
class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State while image is being picked
class ImagePicking extends ProfileState {
  final ProfileLoaded previousState;
  const ImagePicking(this.previousState);

  @override
  List<Object?> get props => [previousState];
}

/// State while image is being uploaded
class ImageUploading extends ProfileState {
  final double progress;
  final ProfileLoaded previousState;
  const ImageUploading(this.progress, this.previousState);

  @override
  List<Object?> get props => [progress, previousState];
}
