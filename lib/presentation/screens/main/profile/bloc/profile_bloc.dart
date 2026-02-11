import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/models/interpreter_language.dart';
import 'package:interbridge/data/models/interpreter_specialization.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_event.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_state.dart';

/// BLoC for managing user profile data and interpreter-specific information
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final SupabaseService _supabaseService;
  final ImagePicker _imagePicker;

  ProfileBloc({
    SupabaseService? supabaseService,
    ImagePicker? imagePicker,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _imagePicker = imagePicker ?? ImagePicker(),
        super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateBasicProfile>(_onUpdateBasicProfile);
    on<PickProfileImage>(_onPickProfileImage);
    on<UploadProfileImage>(_onUploadProfileImage);
    on<RemoveProfileImage>(_onRemoveProfileImage);
    on<UpdateInterpreterLanguages>(_onUpdateInterpreterLanguages);
    on<UpdateInterpreterSpecializations>(_onUpdateInterpreterSpecializations);
    on<UpdateLanguageSkills>(_onUpdateLanguageSkills);
    on<RefreshInterpreterData>(_onRefreshInterpreterData);
  }

  /// Load all profile data including interpreter-specific data
  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(ProfileLoading());

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        emit(const ProfileError('User not authenticated'));
        return;
      }

      final userId = event.userId ?? user.id;

      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        _supabaseService.getUserProfile(userId),
        _supabaseService.getInterpreterDetails(userId),
        _supabaseService.getInterpreterLanguages(userId),
        _supabaseService.getInterpreterSpecializations(userId),
        _supabaseService.getInterpreterSkills(userId),
        _supabaseService.getInterpreterLanguageSkills(userId),
        _supabaseService.getLanguages(),
        _supabaseService.getSpecializations(),
        _supabaseService.getSkills(),
        _supabaseService.getFluencyLevels(),
      ]);

      final profile = results[0] as UserProfile?;
      if (profile == null) {
        emit(const ProfileError('Profile not found'));
        return;
      }

      // Build language skill map from entries
      final languageSkillEntries = results[5] as List;
      final languageSkillMap = <int, Set<int>>{};
      for (final entry in languageSkillEntries) {
        final langId = entry.languageId as int;
        final skillId = entry.skillId as int;
        languageSkillMap.putIfAbsent(langId, () => <int>{}).add(skillId);
      }

      emit(ProfileLoaded(
        profile: profile,
        userEmail: user.email,
        interpreterDetails: results[1] as dynamic,
        interpreterLanguages: List.from(results[2] as List),
        interpreterSpecializations: List.from(results[3] as List),
        interpreterSkills: List.from(results[4] as List),
        languageSkillMap: languageSkillMap,
        availableLanguages: List.from(results[6] as List),
        availableSpecializations: List.from(results[7] as List),
        availableSkills: List.from(results[8] as List),
        fluencyLevels: List.from(results[9] as List),
      ));
    } catch (e) {
      log('ProfileBloc._onLoadProfile error: $e');
      emit(ProfileError('Failed to load profile: $e'));
    }
  }

  /// Update basic profile information (username, gender)
  Future<void> _onUpdateBasicProfile(
    UpdateBasicProfile event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

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

      emit(currentState.copyWith(
        profile: updatedProfile,
        isSaving: false,
        message: 'Profile updated',
        isError: false,
      ));
    } catch (e) {
      log('ProfileBloc._onUpdateBasicProfile error: $e');
      emit(currentState.copyWith(
        isSaving: false,
        message: 'Error saving profile: $e',
        isError: true,
      ));
    }
  }

  /// Pick a profile image from gallery or camera
  Future<void> _onPickProfileImage(
    PickProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      emit(ImagePicking(currentState));

      final pickedFile = await _imagePicker.pickImage(
        source: event.source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        add(UploadProfileImage(file));
      } else {
        // User cancelled - restore previous state
        emit(currentState);
      }
    } catch (e) {
      log('ProfileBloc._onPickProfileImage error: $e');
      emit(currentState.copyWith(
        message: 'Failed to pick image: $e',
        isError: true,
      ));
    }
  }

  /// Upload a profile image to storage
  Future<void> _onUploadProfileImage(
    UploadProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    ProfileLoaded? previousState;
    
    if (state is ProfileLoaded) {
      previousState = state as ProfileLoaded;
    } else if (state is ImagePicking) {
      previousState = (state as ImagePicking).previousState;
    }
    
    if (previousState == null) return;

    try {
      emit(ImageUploading(0.0, previousState));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload image
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = event.imageFile.path.split('.').last;
      final filename = 'profile_${user.id}_$timestamp.$extension';

      final bytes = await event.imageFile.readAsBytes();
      final imageUrl = await _supabaseService.uploadProfileImage(filename, bytes);

      // Update profile with new image URL
      final updatedProfile = UserProfile(
        id: user.id,
        username: previousState.profile.username,
        role: previousState.profile.role,
        profileImage: imageUrl,
        gender: previousState.profile.gender,
        createdAt: previousState.profile.createdAt,
      );

      await _supabaseService.updateUserProfile(updatedProfile);

      emit(previousState.copyWith(
        profile: updatedProfile,
        message: 'Profile photo updated',
        isError: false,
      ));
    } catch (e) {
      log('ProfileBloc._onUploadProfileImage error: $e');
      emit(previousState.copyWith(
        message: 'Failed to upload image: $e',
        isError: true,
      ));
    }
  }

  /// Remove the profile image
  Future<void> _onRemoveProfileImage(
    RemoveProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      emit(currentState.copyWith(isSaving: true));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Delete image from storage if it exists
      if (currentState.profile.profileImage != null &&
          currentState.profile.profileImage!.isNotEmpty) {
        try {
          final filename = currentState.profile.profileImage!.split('/').last;
          await _supabaseService.deleteProfileImage(filename);
        } catch (e) {
          // Log but don't fail - image deletion is not critical
          log('Warning: Failed to delete image: $e');
        }
      }

      // Update profile to remove image URL
      final updatedProfile = UserProfile(
        id: user.id,
        username: currentState.profile.username,
        role: currentState.profile.role,
        profileImage: null,
        gender: currentState.profile.gender,
        createdAt: currentState.profile.createdAt,
      );

      await _supabaseService.updateUserProfile(updatedProfile);

      emit(currentState.copyWith(
        profile: updatedProfile,
        isSaving: false,
        message: 'Profile photo removed',
        isError: false,
      ));
    } catch (e) {
      log('ProfileBloc._onRemoveProfileImage error: $e');
      emit(currentState.copyWith(
        isSaving: false,
        message: 'Failed to remove image: $e',
        isError: true,
      ));
    }
  }

  /// Update interpreter languages and fluency levels
  Future<void> _onUpdateInterpreterLanguages(
    UpdateInterpreterLanguages event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      emit(currentState.copyWith(isSaving: true));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final current = {
        for (final lang in currentState.interpreterLanguages)
          lang.languageId: lang.fluencyId,
      };

      final desired = event.languageFluencyMap;

      // Add new languages or update fluency
      for (final entry in desired.entries) {
        final langId = entry.key;
        final fluencyId = entry.value;
        if (!current.containsKey(langId)) {
          await _supabaseService.addInterpreterLanguage(
            InterpreterLanguage(
              userId: user.id,
              languageId: langId,
              fluencyId: fluencyId,
            ),
          );
        } else if (current[langId] != fluencyId) {
          await _supabaseService.updateInterpreterLanguageFluency(
            user.id,
            langId,
            fluencyId,
          );
        }
      }

      // Remove languages no longer selected
      for (final langId in current.keys) {
        if (!desired.containsKey(langId)) {
          await _supabaseService.deleteInterpreterLanguage(user.id, langId);
        }
      }

      // Refresh interpreter data
      add(RefreshInterpreterData(successMessage: 'Languages updated'));
    } catch (e) {
      log('ProfileBloc._onUpdateInterpreterLanguages error: $e');
      emit(currentState.copyWith(
        isSaving: false,
        message: 'Failed to update languages: $e',
        isError: true,
      ));
    }
  }

  /// Update interpreter specializations
  Future<void> _onUpdateInterpreterSpecializations(
    UpdateInterpreterSpecializations event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      emit(currentState.copyWith(isSaving: true));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final currentIds = currentState.interpreterSpecializations
          .map((e) => e.specializationId)
          .toSet();

      final toAdd = event.specializationIds.difference(currentIds);
      final toRemove = currentIds.difference(event.specializationIds);

      for (final id in toAdd) {
        await _supabaseService.addInterpreterSpecialization(
          InterpreterSpecialization(userId: user.id, specializationId: id),
        );
      }
      for (final id in toRemove) {
        await _supabaseService.deleteInterpreterSpecialization(user.id, id);
      }

      // Refresh interpreter data
      add(RefreshInterpreterData(successMessage: 'Specializations updated'));
    } catch (e) {
      log('ProfileBloc._onUpdateInterpreterSpecializations error: $e');
      emit(currentState.copyWith(
        isSaving: false,
        message: 'Failed to update specializations: $e',
        isError: true,
      ));
    }
  }

  /// Update skills for a specific language
  Future<void> _onUpdateLanguageSkills(
    UpdateLanguageSkills event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      emit(currentState.copyWith(isSaving: true));

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabaseService.replaceInterpreterLanguageSkills(
        user.id,
        event.languageId,
        event.skillIds,
      );

      // Refresh interpreter data
      add(RefreshInterpreterData(successMessage: 'Language skills updated'));
    } catch (e) {
      log('ProfileBloc._onUpdateLanguageSkills error: $e');
      emit(currentState.copyWith(
        isSaving: false,
        message: 'Failed to update language skills: $e',
        isError: true,
      ));
    }
  }

  /// Refresh interpreter-specific data (languages, specializations, skills)
  Future<void> _onRefreshInterpreterData(
    RefreshInterpreterData event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) return;

      final results = await Future.wait([
        _supabaseService.getInterpreterLanguages(user.id),
        _supabaseService.getInterpreterSpecializations(user.id),
        _supabaseService.getInterpreterSkills(user.id),
        _supabaseService.getInterpreterLanguageSkills(user.id),
      ]);

      // Build language skill map
      final languageSkillEntries = results[3] as List;
      final languageSkillMap = <int, Set<int>>{};
      for (final entry in languageSkillEntries) {
        final langId = entry.languageId as int;
        final skillId = entry.skillId as int;
        languageSkillMap.putIfAbsent(langId, () => <int>{}).add(skillId);
      }

      emit(currentState.copyWith(
        interpreterLanguages: List.from(results[0] as List),
        interpreterSpecializations: List.from(results[1] as List),
        interpreterSkills: List.from(results[2] as List),
        languageSkillMap: languageSkillMap,
        isSaving: false,
        message: event.successMessage,
        isError: false,
      ));
    } catch (e) {
      log('ProfileBloc._onRefreshInterpreterData error: $e');
      emit(currentState.copyWith(
        isSaving: false,
        message: 'Failed to refresh data: $e',
        isError: true,
      ));
    }
  }
}
