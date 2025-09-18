import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';
import 'bloc/profile_bloc.dart';

class ProfileEditView extends StatefulWidget {
  final UserProfile profile;

  const ProfileEditView({super.key, required this.profile});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedGender;
  String? _selectedRole;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _roleOptions = ['requester', 'interpreter'];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _usernameController.text = widget.profile.username ?? '';
    _selectedGender = widget.profile.gender;
    _selectedRole = widget.profile.role;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc()..add(LoadProfile(widget.profile.id)),
      child: Scaffold(
        backgroundColor: ColorManager.backgroundPrimary,
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: ColorManager.primary2,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: BlocConsumer<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileUpdated) {
              CustomSnackBar.show(
                context: context,
                message: 'Profile updated successfully!',
                type: SnackBarType.success,
              );
              Navigator.pop(context, true); // Return true to indicate update
            } else if (state is ProfileError) {
              CustomSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            } else if (state is ImageError) {
              CustomSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: ColorManager.error,
                    ),
                    const SizedBox(height: AppSize.s16),
                    Text(
                      'Failed to load profile',
                      style: TextStyle(
                        fontSize: AppSize.s18,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSize.s8),
                    Text(
                      state.message,
                      style: TextStyle(color: ColorManager.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSize.s24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                          LoadProfile(widget.profile.id),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image Section
                  _buildProfileImageSection(state),
                  const SizedBox(height: AppSize.s24),

                  // Profile Form
                  _buildProfileForm(),
                  const SizedBox(height: AppSize.s32),

                  // Save Button
                  _buildSaveButton(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileImageSection(ProfileState state) {
    return Center(
      child: Column(
        children: [
          // Profile Image
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ColorManager.primary2, width: 3),
                ),
                child: ClipOval(child: _buildProfileImage(state)),
              ),

              // Image Actions
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorManager.primary2,
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<ImageSource>(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                    onSelected: (source) {
                      context.read<ProfileBloc>().add(PickProfileImage(source));
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: ImageSource.camera,
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt),
                                SizedBox(width: 8),
                                Text('Camera'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: ImageSource.gallery,
                            child: Row(
                              children: [
                                Icon(Icons.photo_library),
                                SizedBox(width: 8),
                                Text('Gallery'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSize.s16),

          // Image Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state is ProfileLoaded &&
                  state.profile.profileImage != null &&
                  state.profile.profileImage!.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    context.read<ProfileBloc>().add(const RemoveProfileImage());
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),

          // Upload Progress
          if (state is ImageUploading) ...[
            const SizedBox(height: AppSize.s16),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: ColorManager.greyLight,
              valueColor: AlwaysStoppedAnimation<Color>(ColorManager.primary2),
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              'Uploading image...',
              style: TextStyle(
                color: ColorManager.textSecondary,
                fontSize: AppSize.s14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage(ProfileState state) {
    if (state is ImageUploading) {
      return Container(
        color: ColorManager.greyLight,
        child: const Icon(Icons.upload, size: 40, color: Colors.grey),
      );
    }

    if (state is ProfileLoaded &&
        state.profile.profileImage != null &&
        state.profile.profileImage!.isNotEmpty) {
      return Image.network(
        state.profile.profileImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultProfileImage();
        },
      );
    }

    return _buildDefaultProfileImage();
  }

  Widget _buildDefaultProfileImage() {
    return Container(
      color: ColorManager.greyLight,
      child: Icon(Icons.person, size: 60, color: ColorManager.textSecondary),
    );
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username
        _buildTextField(
          label: 'Username',
          controller: _usernameController,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: AppSize.s16),

        // Gender
        _buildDropdown(
          label: 'Gender',
          value: _selectedGender,
          items: _genderOptions,
          onChanged: (value) {
            setState(() => _selectedGender = value);
          },
          icon: Icons.wc,
        ),
        const SizedBox(height: AppSize.s16),

        // Role
        _buildDropdown(
          label: 'Role',
          value: _selectedRole,
          items: _roleOptions,
          onChanged: (value) {
            setState(() => _selectedRole = value);
          },
          icon: Icons.work_outline,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSize.s14,
            fontWeight: FontWeight.w600,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: ColorManager.greyMedium),
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: ColorManager.primary2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSize.s16,
                vertical: AppSize.s12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSize.s14,
            fontWeight: FontWeight.w600,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: ColorManager.greyMedium),
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: ColorManager.primary2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSize.s16,
                vertical: AppSize.s12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            hint: Text('Select $label'),
            items:
                items.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ProfileState state) {
    final isLoading = state is ProfileUpdating || state is ImageUploading;

    return SizedBox(
      width: double.infinity,
      height: AppSize.s55,
      child: CustomButton(
        onTap: isLoading ? () {} : _saveProfile,
        color: ColorManager.primary2,
        isLoading: isLoading,
        borderRadius: BorderRadius.circular(AppSize.s16),
        child: const Text(
          'Save Profile',
          style: TextStyle(
            fontSize: AppSize.s16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _saveProfile() {
    final updatedProfile = UserProfile(
      id: widget.profile.id,
      username: _usernameController.text.trim(),
      role: _selectedRole,
      profileImage: widget.profile.profileImage,
      gender: _selectedGender,
      createdAt: widget.profile.createdAt,
    );

    context.read<ProfileBloc>().add(UpdateProfile(updatedProfile));
  }
}
