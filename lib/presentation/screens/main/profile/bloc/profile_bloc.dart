import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/services/supabase_service.dart';

// Events
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {
  final String userId;
  const LoadProfile(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UpdateProfile extends ProfileEvent {
  final UserProfile profile;
  const UpdateProfile(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PickProfileImage extends ProfileEvent {
  final ImageSource source;
  const PickProfileImage(this.source);

  @override
  List<Object?> get props => [source];
}

class UploadProfileImage extends ProfileEvent {
  final File imageFile;
  const UploadProfileImage(this.imageFile);

  @override
  List<Object?> get props => [imageFile];
}

class RemoveProfileImage extends ProfileEvent {
  const RemoveProfileImage();
}

// States
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserProfile profile;
  final bool hasChanges;

  const ProfileLoaded(this.profile, {this.hasChanges = false});

  @override
  List<Object?> get props => [profile, hasChanges];

  ProfileLoaded copyWith({UserProfile? profile, bool? hasChanges}) {
    return ProfileLoaded(
      profile ?? this.profile,
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }
}

class ProfileUpdating extends ProfileState {
  final UserProfile profile;
  const ProfileUpdating(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileUpdated extends ProfileState {
  final UserProfile profile;
  const ProfileUpdated(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class ImagePicking extends ProfileState {}

class ImageUploading extends ProfileState {
  final double progress;
  const ImageUploading(this.progress);

  @override
  List<Object?> get props => [progress];
}

class ImageUploaded extends ProfileState {
  final String imageUrl;
  const ImageUploaded(this.imageUrl);

  @override
  List<Object?> get props => [imageUrl];
}

class ImageError extends ProfileState {
  final String message;
  const ImageError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  ProfileBloc() : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<PickProfileImage>(_onPickProfileImage);
    on<UploadProfileImage>(_onUploadProfileImage);
    on<RemoveProfileImage>(_onRemoveProfileImage);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(ProfileLoading());

      final profile = await _supabaseService.getUserProfile(event.userId);

      if (profile != null) {
        emit(ProfileLoaded(profile));
      } else {
        emit(const ProfileError('Profile not found'));
      }
    } catch (e) {
      emit(ProfileError('Failed to load profile: $e'));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(ProfileUpdating(event.profile));

      await _supabaseService.updateUserProfile(event.profile);

      emit(ProfileUpdated(event.profile));
    } catch (e) {
      emit(ProfileError('Failed to update profile: $e'));
    }
  }

  Future<void> _onPickProfileImage(
    PickProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(ImagePicking());

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: event.source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        add(UploadProfileImage(file));
      } else {
        // User cancelled image picking
        if (state is ProfileLoaded) {
          emit(state);
        } else {
          emit(ProfileInitial());
        }
      }
    } catch (e) {
      emit(ImageError('Failed to pick image: $e'));
    }
  }

  Future<void> _onUploadProfileImage(
    UploadProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(const ImageUploading(0.0));

      // Upload image to Supabase storage
      final imageUrl = await _uploadImageToSupabase(event.imageFile);

      // Update profile with new image URL regardless of current state
      final userId = _supabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final currentProfile = await _supabaseService.getUserProfile(userId);
      final updatedProfile = UserProfile(
        id: userId,
        username: currentProfile?.username,
        role: currentProfile?.role,
        profileImage: imageUrl,
        gender: currentProfile?.gender,
        createdAt: currentProfile?.createdAt,
      );

      // Emit uploaded state for UI feedback, then persist
      emit(ImageUploaded(imageUrl));
      add(UpdateProfile(updatedProfile));
    } catch (e) {
      emit(ImageError('Failed to upload image: $e'));
    }
  }

  Future<void> _onRemoveProfileImage(
    RemoveProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      if (state is ProfileLoaded) {
        final currentProfile = (state as ProfileLoaded).profile;

        // Delete image from Supabase storage if it exists
        if (currentProfile.profileImage != null &&
            currentProfile.profileImage!.isNotEmpty) {
          await _deleteImageFromSupabase(currentProfile.profileImage!);
        }

        // Update profile to remove image URL
        final updatedProfile = UserProfile(
          id: currentProfile.id,
          username: currentProfile.username,
          role: currentProfile.role,
          profileImage: null,
          gender: currentProfile.gender,
          createdAt: currentProfile.createdAt,
        );

        add(UpdateProfile(updatedProfile));
      }
    } catch (e) {
      emit(ImageError('Failed to remove image: $e'));
    }
  }

  Future<String> _uploadImageToSupabase(File imageFile) async {
    try {
      final userId = _supabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final filename = 'profile_${userId}_$timestamp.$extension';

      // Upload to Supabase storage
      final bytes = await imageFile.readAsBytes();
      final response = await _supabaseService.uploadProfileImage(
        filename,
        bytes,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _deleteImageFromSupabase(String imageUrl) async {
    try {
      // Extract filename from URL
      final filename = imageUrl.split('/').last;
      await _supabaseService.deleteProfileImage(filename);
    } catch (e) {
      // Log error but don't throw - image deletion is not critical
      log('Warning: Failed to delete image: $e');
    }
  }
}
