import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'requester_profile_event.dart';
import 'requester_profile_state.dart';

/// BLoC for managing requester profile data
class RequesterProfileBloc
    extends Bloc<RequesterProfileEvent, RequesterProfileState> {
  final SupabaseService _supabaseService;
  final ImagePicker _imagePicker;

  RequesterProfileBloc({
    SupabaseService? supabaseService,
    ImagePicker? imagePicker,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _imagePicker = imagePicker ?? ImagePicker(),
       super(RequesterProfileInitial()) {
    on<LoadRequesterProfile>(_onLoadProfile);
    on<UpdateRequesterProfile>(_onUpdateProfile);
    on<PickRequesterProfileImage>(_onPickImage);
    on<UploadRequesterProfileImage>(_onUploadImage);
    on<RemoveRequesterProfileImage>(_onRemoveImage);
  }

  /// Load requester profile data
  Future<void> _onLoadProfile(
    LoadRequesterProfile event,
    Emitter<RequesterProfileState> emit,
  ) async {
    try {
      emit(RequesterProfileLoading());

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        emit(const RequesterProfileError('User not authenticated'));
        return;
      }

      final userId = event.userId ?? user.id;

      // Fetch profile
      final profile = await _supabaseService.getUserProfile(userId);
      if (profile == null) {
        emit(const RequesterProfileError('Profile not found'));
        return;
      }

      // Try to get organization info if user is part of one
      String? orgName;
      String? orgRole;
      try {
        final membership = await _supabaseService.getUserOrganizationMembership(
          userId,
        );
        if (membership != null) {
          orgName = membership['organization_name'] as String?;
          orgRole = membership['role'] as String?;
        }
      } catch (e) {
        log('RequesterProfileBloc: No organization membership found: $e');
      }

      emit(
        RequesterProfileLoaded(
          profile: profile,
          userEmail: user.email,
          organizationName: orgName,
          organizationRole: orgRole,
        ),
      );
    } catch (e) {
      log('RequesterProfileBloc._onLoadProfile error: $e');
      emit(RequesterProfileError('Failed to load profile: $e'));
    }
  }

  /// Update basic profile information
  Future<void> _onUpdateProfile(
    UpdateRequesterProfile event,
    Emitter<RequesterProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RequesterProfileLoaded) return;

    try {
      emit(currentState.copyWith(isSaving: true));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;
      if (event.newImageFile != null) {
        final bytes = await event.newImageFile!.readAsBytes();
        final filename =
            'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.${event.newImageFile!.path.split('.').last}';
        imageUrl = await _supabaseService.uploadProfileImage(filename, bytes);
      }

      final updatedProfile = UserProfile(
        id: user.id,
        username: event.username ?? currentState.profile.username,
        role: currentState.profile.role,
        profileImage: imageUrl ?? currentState.profile.profileImage,
        gender: event.gender ?? currentState.profile.gender,
        createdAt: currentState.profile.createdAt,
      );

      await _supabaseService.updateUserProfile(updatedProfile);

      emit(
        currentState.copyWith(
          profile: updatedProfile,
          isSaving: false,
          message: 'Profile updated',
          isError: false,
        ),
      );
    } catch (e) {
      log('RequesterProfileBloc._onUpdateProfile error: $e');
      emit(
        currentState.copyWith(
          isSaving: false,
          message: 'Error saving profile: $e',
          isError: true,
        ),
      );
    }
  }

  /// Pick a profile image from gallery or camera
  Future<void> _onPickImage(
    PickRequesterProfileImage event,
    Emitter<RequesterProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RequesterProfileLoaded) return;

    try {
      emit(RequesterImagePicking(currentState));

      final pickedFile = await _imagePicker.pickImage(
        source: event.source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Automatically upload the picked image
        add(UploadRequesterProfileImage(File(pickedFile.path)));
      } else {
        emit(currentState);
      }
    } catch (e) {
      log('RequesterProfileBloc._onPickImage error: $e');
      emit(
        currentState.copyWith(
          message: 'Error picking image: $e',
          isError: true,
        ),
      );
    }
  }

  /// Upload the picked profile image
  Future<void> _onUploadImage(
    UploadRequesterProfileImage event,
    Emitter<RequesterProfileState> emit,
  ) async {
    final currentState = state;
    RequesterProfileLoaded loadedState;

    if (currentState is RequesterImagePicking) {
      loadedState = currentState.previousState;
    } else if (currentState is RequesterProfileLoaded) {
      loadedState = currentState;
    } else {
      return;
    }

    try {
      emit(RequesterImageUploading(loadedState));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final bytes = await event.imageFile.readAsBytes();
      final filename =
          'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.${event.imageFile.path.split('.').last}';
      final imageUrl = await _supabaseService.uploadProfileImage(
        filename,
        bytes,
      );

      final updatedProfile = UserProfile(
        id: user.id,
        username: loadedState.profile.username,
        role: loadedState.profile.role,
        profileImage: imageUrl,
        gender: loadedState.profile.gender,
        createdAt: loadedState.profile.createdAt,
      );

      await _supabaseService.updateUserProfile(updatedProfile);

      emit(
        loadedState.copyWith(
          profile: updatedProfile,
          message: 'Profile image updated',
          isError: false,
        ),
      );
    } catch (e) {
      log('RequesterProfileBloc._onUploadImage error: $e');
      emit(
        loadedState.copyWith(
          message: 'Error uploading image: $e',
          isError: true,
        ),
      );
    }
  }

  /// Remove the profile image
  Future<void> _onRemoveImage(
    RemoveRequesterProfileImage event,
    Emitter<RequesterProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RequesterProfileLoaded) return;

    try {
      emit(currentState.copyWith(isSaving: true));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final updatedProfile = UserProfile(
        id: user.id,
        username: currentState.profile.username,
        role: currentState.profile.role,
        profileImage: '',
        gender: currentState.profile.gender,
        createdAt: currentState.profile.createdAt,
      );

      await _supabaseService.updateUserProfile(updatedProfile);

      emit(
        currentState.copyWith(
          profile: updatedProfile,
          isSaving: false,
          message: 'Profile image removed',
          isError: false,
        ),
      );
    } catch (e) {
      log('RequesterProfileBloc._onRemoveImage error: $e');
      emit(
        currentState.copyWith(
          isSaving: false,
          message: 'Error removing image: $e',
          isError: true,
        ),
      );
    }
  }
}
