import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_event.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_state.dart';

/// Modern web-specific profile view for requesters
class RequesterProfileViewWeb extends StatefulWidget {
  const RequesterProfileViewWeb({super.key});

  @override
  State<RequesterProfileViewWeb> createState() =>
      _RequesterProfileViewWebState();
}

class _RequesterProfileViewWebState extends State<RequesterProfileViewWeb> {
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

  String? _normalizeGender(String? gender) {
    if (gender == null) return null;
    final lower = gender.toLowerCase();
    for (final option in _genderOptions) {
      if (option.toLowerCase() == lower) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequesterProfileBloc, RequesterProfileState>(
      listener: (context, state) {
        if (state is RequesterProfileLoaded && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: state.isError ? Colors.red : Colors.green,
            ),
          );
        }
        if (state is RequesterProfileLoaded) {
          _usernameController.text = state.profile.username ?? '';
          _selectedGender = _normalizeGender(state.profile.gender);
        }
      },
      builder: (context, state) {
        if (state is RequesterProfileLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is RequesterProfileError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
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
      },
    );
  }

  Widget _buildLoadedContent(
    RequesterProfileLoaded state, {
    required bool showSaving,
  }) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          if (showSaving)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF0955FA),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage your profile information',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Profile Card
                      _buildProfileCard(state),
                      const SizedBox(height: 24),

                      // Account Info Card
                      _buildAccountInfoCard(state),
                      const SizedBox(height: 24),

                      // Organization Card
                      if (state.organizationName != null) ...[
                        _buildOrganizationCard(state),
                        const SizedBox(height: 24),
                      ],

                      // Tips Card
                      _buildTipsCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(RequesterProfileLoaded state) {
    final hasImage = state.profile.profileImage?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
                  ),
                  image:
                      hasImage
                          ? DecorationImage(
                            image: NetworkImage(state.profile.profileImage!),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    !hasImage
                        ? Center(
                          child: Text(
                            (state.profile.username ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0955FA),
                    shape: BoxShape.circle,
                  ),
                  child: InkWell(
                    onTap: _showImageOptions,
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.profile.username ?? 'No name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showEditDialog(state),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  state.userEmail ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.person,
                      label: _formatRole(state.profile.role),
                      color: const Color(0xFF0955FA),
                    ),
                    const SizedBox(width: 8),
                    if (state.profile.gender != null)
                      _buildInfoChip(
                        icon: Icons.accessibility,
                        label: state.profile.gender!,
                        color: const Color(0xFF8B5CF6),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard(RequesterProfileLoaded state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF0955FA)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Username',
            value: state.profile.username ?? 'Not set',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: state.userEmail ?? 'Not available',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_2_outlined,
            label: 'Gender',
            value: state.profile.gender ?? 'Not specified',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: _formatDate(state.profile.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationCard(RequesterProfileLoaded state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Organization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.corporate_fare,
            label: 'Organization',
            value: state.organizationName ?? 'Unknown',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: _formatRole(state.organizationRole),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0955FA).withValues(alpha: 0.05),
            const Color(0xFF6366F1).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0955FA).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF0955FA),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem('Keep your profile updated for better service'),
          const SizedBox(height: 12),
          _buildTipItem(
            'Add a profile picture to help interpreters recognize you',
          ),
          const SizedBox(height: 12),
          _buildTipItem('Update your gender for personalized experience'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  void _showImageOptions() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Change Profile Picture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF0955FA),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.read<RequesterProfileBloc>().add(
                    const PickRequesterProfileImage(ImageSource.gallery),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0955FA)),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  context.read<RequesterProfileBloc>().add(
                    const PickRequesterProfileImage(ImageSource.camera),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(RequesterProfileLoaded state) {
    _usernameController.text = state.profile.username ?? '';
    _selectedGender = _normalizeGender(state.profile.gender);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Profile'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _genderOptions
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) =>
                              setDialogState(() => _selectedGender = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    this.context.read<RequesterProfileBloc>().add(
                      UpdateRequesterProfile(
                        username: _usernameController.text.trim(),
                        gender: _selectedGender,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatRole(String? role) {
    if (role == null || role.isEmpty) return 'User';
    return role[0].toUpperCase() + role.substring(1);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}
