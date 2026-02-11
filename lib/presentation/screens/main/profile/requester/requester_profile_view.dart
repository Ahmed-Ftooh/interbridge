import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'requester_profile_bloc.dart';
import 'requester_profile_event.dart';
import 'requester_profile_state.dart';

class RequesterProfileView extends StatefulWidget {
  const RequesterProfileView({super.key});

  @override
  State<RequesterProfileView> createState() => _RequesterProfileViewState();
}

class _RequesterProfileViewState extends State<RequesterProfileView> {
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedGender;

  final List<String> _genderOptions = const [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    context.read<RequesterProfileBloc>().add(const LoadRequesterProfile());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequesterProfileBloc, RequesterProfileState>(
      listener: (context, state) {
        if (state is RequesterProfileLoaded && state.message != null) {
          _showSnackBar(state.message!, isError: state.isError);
        }

        if (state is RequesterProfileLoaded) {
          _usernameController.text = state.profile.username ?? '';
          _selectedGender = _normalizeGender(state.profile.gender);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: ColorManager.backgroundPrimary,
          appBar: AppBar(
            title: const Text('Profile'),
            foregroundColor: ColorManager.primary,
            elevation: 0,
          ),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(RequesterProfileState state) {
    if (state is RequesterProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is RequesterProfileError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  () => context.read<RequesterProfileBloc>().add(
                    const LoadRequesterProfile(),
                  ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is RequesterImagePicking) {
      return _buildLoadedContent(state.previousState, showSaving: false);
    }

    if (state is RequesterImageUploading) {
      return _buildLoadedContent(state.previousState, showSaving: true);
    }

    if (state is RequesterProfileLoaded) {
      return _buildLoadedContent(state, showSaving: state.isSaving);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadedContent(
    RequesterProfileLoaded state, {
    required bool showSaving,
  }) {
    return Column(
      children: [
        if (showSaving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<RequesterProfileBloc>().add(
                const LoadRequesterProfile(),
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppPadding.p20,
                vertical: AppPadding.p20,
              ),
              children: [
                _buildHeroCard(state),
                const SizedBox(height: AppSize.s20),
                _buildInfoCard(state),
                if (state.organizationName != null) ...[
                  const SizedBox(height: AppSize.s20),
                  _buildOrganizationCard(state),
                ],
                const SizedBox(height: AppSize.s20),
                _buildTipsCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(RequesterProfileLoaded state) {
    final hasImage = state.profile.profileImage?.isNotEmpty == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.p20),
        child: Column(
          children: [
            // Profile Image
            GestureDetector(
              onTap: _showImageOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: ColorManager.primary.withOpacity(0.1),
                    backgroundImage:
                        hasImage
                            ? NetworkImage(state.profile.profileImage!)
                            : null,
                    child:
                        !hasImage
                            ? Icon(
                              Icons.person,
                              size: 50,
                              color: ColorManager.primary,
                            )
                            : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ColorManager.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSize.s16),

            // Username
            Text(
              state.profile.username ?? 'No name',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              state.userEmail ?? '',
              style: TextStyle(color: ColorManager.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ColorManager.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatRole(state.profile.role),
                style: TextStyle(
                  color: ColorManager.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSize.s16),

            // Edit button
            OutlinedButton.icon(
              onPressed: () => _showEditBasicsSheet(state),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorManager.primary,
                side: BorderSide(color: ColorManager.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(RequesterProfileLoaded state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: ColorManager.primary),
                const SizedBox(width: 8),
                Text(
                  'Account Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.person_outline,
              'Username',
              state.profile.username ?? 'Not set',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.email_outlined,
              'Email',
              state.userEmail ?? 'Not available',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.person_2_outlined,
              'Gender',
              state.profile.gender ?? 'Not specified',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Member Since',
              _formatDate(state.profile.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationCard(RequesterProfileLoaded state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business_outlined, color: ColorManager.primary),
                const SizedBox(width: 8),
                Text(
                  'Organization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.corporate_fare,
              'Organization',
              state.organizationName ?? 'Unknown',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.badge_outlined,
              'Role',
              _formatRole(state.organizationRole),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      color: ColorManager.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: ColorManager.primary),
                const SizedBox(width: 8),
                Text(
                  'Tips',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ColorManager.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              Icons.translate,
              'Request interpretation services anytime',
            ),
            const SizedBox(height: 8),
            _buildTipItem(
              Icons.description_outlined,
              'Submit documents for translation',
            ),
            const SizedBox(height: 8),
            _buildTipItem(
              Icons.history,
              'View your request history in the History tab',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: ColorManager.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: ColorManager.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ColorManager.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: ColorManager.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<RequesterProfileBloc>().add(
                      const PickRequesterProfileImage(ImageSource.gallery),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<RequesterProfileBloc>().add(
                      const PickRequesterProfileImage(ImageSource.camera),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<RequesterProfileBloc>().add(
                      const RemoveRequesterProfileImage(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditBasicsSheet(RequesterProfileLoaded state) {
    _usernameController.text = state.profile.username ?? '';
    _selectedGender = _normalizeGender(state.profile.gender);

    // Capture the bloc reference before showing the modal
    final bloc = context.read<RequesterProfileBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppPadding.p20,
                right: AppPadding.p20,
                top: AppPadding.p20,
                bottom:
                    MediaQuery.of(builderContext).viewInsets.bottom +
                    AppPadding.p20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Profile',
                    style: Theme.of(builderContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSize.s16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSize.s16),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _genderOptions
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                    onChanged: (val) {
                      setModalState(() => _selectedGender = val);
                    },
                  ),
                  const SizedBox(height: AppSize.s24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        bloc.add(
                          UpdateRequesterProfile(
                            username: _usernameController.text.trim(),
                            gender: _selectedGender,
                          ),
                        );
                        Navigator.pop(modalContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? _normalizeGender(String? gender) {
    if (gender == null || gender.isEmpty) return null;
    final lower = gender.toLowerCase();
    for (final option in _genderOptions) {
      if (option.toLowerCase() == lower) return option;
    }
    return null;
  }

  String _formatRole(String? role) {
    if (role == null || role.isEmpty) return 'User';
    return role
        .split('_')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1)}'
                  : word,
        )
        .join(' ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : ColorManager.primary,
      ),
    );
  }
}
