import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

/// Base class for all profile events
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load complete profile data including interpreter details if applicable
class LoadProfile extends ProfileEvent {
  final String? userId;
  const LoadProfile({this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Update basic profile information (username, gender, optionally image)
class UpdateBasicProfile extends ProfileEvent {
  final String? username;
  final String? gender;
  final File? newImageFile;

  const UpdateBasicProfile({this.username, this.gender, this.newImageFile});

  @override
  List<Object?> get props => [username, gender, newImageFile];
}

/// Pick an image from gallery or camera
class PickProfileImage extends ProfileEvent {
  final ImageSource source;
  const PickProfileImage(this.source);

  @override
  List<Object?> get props => [source];
}

/// Upload a picked image file
class UploadProfileImage extends ProfileEvent {
  final File imageFile;
  const UploadProfileImage(this.imageFile);

  @override
  List<Object?> get props => [imageFile];
}

/// Remove the current profile image
class RemoveProfileImage extends ProfileEvent {
  const RemoveProfileImage();
}

// ============ Interpreter-specific Events ============

/// Update interpreter languages with fluency levels
/// Map key: languageId, value: fluencyId
class UpdateInterpreterLanguages extends ProfileEvent {
  final Map<int, int> languageFluencyMap;
  const UpdateInterpreterLanguages(this.languageFluencyMap);

  @override
  List<Object?> get props => [languageFluencyMap];
}

/// Update interpreter specializations
class UpdateInterpreterSpecializations extends ProfileEvent {
  final Set<int> specializationIds;
  const UpdateInterpreterSpecializations(this.specializationIds);

  @override
  List<Object?> get props => [specializationIds];
}

/// Update skills for a specific language
class UpdateLanguageSkills extends ProfileEvent {
  final int languageId;
  final Set<int> skillIds;
  const UpdateLanguageSkills(this.languageId, this.skillIds);

  @override
  List<Object?> get props => [languageId, skillIds];
}

/// Refresh interpreter-specific data only
class RefreshInterpreterData extends ProfileEvent {
  final String? successMessage;
  const RefreshInterpreterData({this.successMessage});

  @override
  List<Object?> get props => [successMessage];
}
