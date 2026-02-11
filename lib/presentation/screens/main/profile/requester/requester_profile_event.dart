import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

/// Base class for all requester profile events
abstract class RequesterProfileEvent extends Equatable {
  const RequesterProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load the requester profile data
class LoadRequesterProfile extends RequesterProfileEvent {
  final String? userId;

  const LoadRequesterProfile({this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Update basic profile info (username, gender)
class UpdateRequesterProfile extends RequesterProfileEvent {
  final String? username;
  final String? gender;
  final File? newImageFile;

  const UpdateRequesterProfile({this.username, this.gender, this.newImageFile});

  @override
  List<Object?> get props => [username, gender, newImageFile];
}

/// Pick a profile image
class PickRequesterProfileImage extends RequesterProfileEvent {
  final ImageSource source;

  const PickRequesterProfileImage(this.source);

  @override
  List<Object?> get props => [source];
}

/// Upload the picked profile image
class UploadRequesterProfileImage extends RequesterProfileEvent {
  final File imageFile;

  const UploadRequesterProfileImage(this.imageFile);

  @override
  List<Object?> get props => [imageFile];
}

/// Remove the profile image
class RemoveRequesterProfileImage extends RequesterProfileEvent {
  const RemoveRequesterProfileImage();
}
