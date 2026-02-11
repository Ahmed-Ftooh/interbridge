import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_event.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_state.dart';

/// Modern web-specific profile view for interpreters
class ProfileViewWeb extends StatefulWidget {
  const ProfileViewWeb({super.key});

  @override
  State<ProfileViewWeb> createState() => _ProfileViewWebState();
}

class _ProfileViewWebState extends State<ProfileViewWeb> {
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
    context.read<ProfileBloc>().add(const LoadProfile());
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
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: state.isError ? Colors.red : Colors.green,
            ),
          );
        }
        if (state is ProfileLoaded) {
          _usernameController.text = state.profile.username ?? '';
          _selectedGender = _normalizeGender(state.profile.gender);
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
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      () =>
                          context.read<ProfileBloc>().add(const LoadProfile()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is ProfileLoaded) {
          return _buildLoadedContent(state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadedContent(ProfileLoaded state) {
    return Container(
      color: const Color(0xFFF8FAFC),
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
                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),

                // Profile Card
                _buildProfileCard(state),
                const SizedBox(height: 24),

                // Stats Card
                _buildStatsCard(state),
                const SizedBox(height: 24),

                // Languages Card (for interpreters)
                if (state.isInterpreter) ...[
                  _buildLanguagesCard(state),
                  const SizedBox(height: 24),
                ],

                // Skills Card (for interpreters)
                if (state.isInterpreter &&
                    state.interpreterSkills.isNotEmpty) ...[
                  _buildSkillsCard(state),
                  const SizedBox(height: 24),
                ],

                // Specializations Card (for interpreters)
                if (state.isInterpreter &&
                    state.interpreterSpecializations.isNotEmpty) ...[
                  _buildSpecializationsCard(state),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(ProfileLoaded state) {
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
                      state.profile.profileImage != null
                          ? DecorationImage(
                            image: NetworkImage(state.profile.profileImage!),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    state.profile.profileImage == null
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
                    onTap:
                        () => context.read<ProfileBloc>().add(
                          const PickProfileImage(ImageSource.gallery),
                        ),
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
                      label: state.profile.role?.toUpperCase() ?? 'USER',
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

  Widget _buildStatsCard(ProfileLoaded state) {
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
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.translate,
                  label: 'Languages',
                  value: state.interpreterLanguages.length.toString(),
                  color: const Color(0xFF0955FA),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.psychology,
                  label: 'Skills',
                  value: state.interpreterSkills.length.toString(),
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.medical_services,
                  label: 'Specializations',
                  value: state.interpreterSpecializations.length.toString(),
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesCard(ProfileLoaded state) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Languages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showLanguageEditor(state),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.interpreterLanguages.isEmpty)
            const Text(
              'No languages added yet',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  state.interpreterLanguages.map((lang) {
                    final language = state.availableLanguages.firstWhere(
                      (l) => l.id == lang.languageId,
                      orElse: () => Language(id: 0, name: 'Unknown'),
                    );
                    final fluency = state.fluencyLevels.firstWhere(
                      (f) => f.id == lang.fluencyId,
                      orElse:
                          () =>
                              state.fluencyLevels.isNotEmpty
                                  ? state.fluencyLevels.first
                                  : throw Exception('No fluency levels'),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF0955FA).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            language.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0955FA),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              fluency.level,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard(ProfileLoaded state) {
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
          const Text(
            'Skills',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                state.interpreterSkills.map((interpreterSkill) {
                  final skill = state.availableSkills.firstWhere(
                    (s) => s.id == interpreterSkill.skillId,
                    orElse:
                        () =>
                            state.availableSkills.isNotEmpty
                                ? state.availableSkills.first
                                : throw Exception('No skills available'),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      skill.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF166534),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationsCard(ProfileLoaded state) {
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
          const Text(
            'Specializations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                state.interpreterSpecializations.map((interpreterSpec) {
                  final spec = state.availableSpecializations.firstWhere(
                    (s) => s.id == interpreterSpec.specializationId,
                    orElse:
                        () =>
                            state.availableSpecializations.isNotEmpty
                                ? state.availableSpecializations.first
                                : throw Exception(
                                  'No specializations available',
                                ),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      spec.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ProfileLoaded state) {
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
                      value: _selectedGender,
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
                    this.context.read<ProfileBloc>().add(
                      UpdateBasicProfile(
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

  void _showLanguageEditor(ProfileLoaded state) {
    if (state.availableLanguages.isEmpty || state.fluencyLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Languages or fluency levels are not configured yet'),
        ),
      );
      return;
    }

    final currentSelection = {
      for (final lang in state.interpreterLanguages)
        lang.languageId: lang.fluencyId,
    };

    showDialog(
      context: context,
      builder: (dialogContext) {
        final tempSelection = Map<int, int>.from(currentSelection);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Languages'),
              content: SizedBox(
                width: 500,
                height: 400,
                child: ListView.separated(
                  itemCount: state.availableLanguages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final language = state.availableLanguages[index];
                    final selected = tempSelection.containsKey(language.id);
                    return ListTile(
                      leading: Checkbox(
                        value: selected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              tempSelection[language.id] =
                                  tempSelection[language.id] ??
                                  state.defaultFluencyId;
                            } else {
                              tempSelection.remove(language.id);
                            }
                          });
                        },
                      ),
                      title: Text(language.name),
                      subtitle:
                          selected
                              ? DropdownButton<int>(
                                value:
                                    tempSelection[language.id] ??
                                    state.defaultFluencyId,
                                items:
                                    state.fluencyLevels
                                        .map(
                                          (level) => DropdownMenuItem(
                                            value: level.id,
                                            child: Text(level.level),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(
                                    () => tempSelection[language.id] = value,
                                  );
                                },
                              )
                              : null,
                    );
                  },
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
                    this.context.read<ProfileBloc>().add(
                      UpdateInterpreterLanguages(tempSelection),
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
}
