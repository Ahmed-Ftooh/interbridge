import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/models/skill.dart';
import 'package:interbridge/data/models/specialization.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_event.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_state.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedGender;
  XFile? _pickedImage;

  final List<String> _genderOptions = const [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    // Trigger profile load when view initializes
    context.read<ProfileBloc>().add(const LoadProfile());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        // Handle message display from state
        if (state is ProfileLoaded && state.message != null) {
          _showSnackBar(state.message!, isError: state.isError);
        }

        // Sync local state with loaded data
        if (state is ProfileLoaded) {
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

  Widget _buildBody(ProfileState state) {
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
                  () => context.read<ProfileBloc>().add(const LoadProfile()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state is ImagePicking) {
      return _buildLoadedContent(state.previousState, showSaving: false);
    }

    if (state is ImageUploading) {
      return _buildLoadedContent(state.previousState, showSaving: true);
    }

    if (state is ProfileLoaded) {
      return _buildLoadedContent(state, showSaving: state.isSaving);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadedContent(ProfileLoaded state, {required bool showSaving}) {
    return Column(
      children: [
        if (showSaving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>().add(const LoadProfile());
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
                _buildSnapshotCard(state),
                if (state.isInterpreter) ...[
                  const SizedBox(height: AppSize.s20),
                  _buildSkillsCard(state),
                ],
                if (!state.isInterpreter) ...[
                  const SizedBox(height: AppSize.s20),
                  _buildRequesterTipsCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _pickImage() {
    context.read<ProfileBloc>().add(
      const PickProfileImage(ImageSource.gallery),
    );
  }

  void _showEditBasicsSheet(ProfileLoaded state) {
    _usernameController.text = state.profile.username ?? '';
    _selectedGender = _normalizeGender(state.profile.gender);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppPadding.p20,
                right: AppPadding.p20,
                top: AppPadding.p20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppPadding.p20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile basics',
                    style: Theme.of(context).textTheme.titleMedium,
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
                        (value) => setModalState(() => _selectedGender = value),
                  ),
                  const SizedBox(height: AppSize.s20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        this.context.read<ProfileBloc>().add(
                          UpdateBasicProfile(
                            username: _usernameController.text.trim(),
                            gender: _selectedGender,
                          ),
                        );
                      },
                      child: const Text('Save changes'),
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

  Future<void> _openLanguageEditor(ProfileLoaded state) async {
    if (!state.isInterpreter) return;
    if (state.availableLanguages.isEmpty || state.fluencyLevels.isEmpty) {
      _showSnackBar('Languages or fluency levels are not configured yet');
      return;
    }

    final currentSelection = {
      for (final lang in state.interpreterLanguages)
        lang.languageId: lang.fluencyId,
    };

    final result = await showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final tempSelection = Map<int, int>.from(currentSelection);
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: AppPadding.p20,
                  right: AppPadding.p20,
                  top: AppPadding.p20,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + AppPadding.p20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Languages & fluency',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSize.s16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.availableLanguages.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: AppSize.s1),
                        itemBuilder: (context, index) {
                          final language = state.availableLanguages[index];
                          final selected = tempSelection.containsKey(
                            language.id,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Checkbox(
                              value: selected,
                              onChanged: (value) {
                                setModalState(() {
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
                                        setModalState(
                                          () =>
                                              tempSelection[language.id] =
                                                  value,
                                        );
                                      },
                                    )
                                    : const SizedBox.shrink(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => Navigator.of(context).pop(tempSelection),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(UpdateInterpreterLanguages(result));
    }
  }

  Future<void> _openSpecializationEditor(ProfileLoaded state) async {
    if (!state.isInterpreter) return;
    if (state.availableSpecializations.isEmpty) {
      _showSnackBar('No specialization catalog found yet');
      return;
    }

    final currentIds =
        state.interpreterSpecializations.map((e) => e.specializationId).toSet();

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final tempSelection = Set<int>.from(currentIds);
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: AppPadding.p20,
                  right: AppPadding.p20,
                  top: AppPadding.p20,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + AppPadding.p20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Specializations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSize.s16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.availableSpecializations.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: AppSize.s1),
                        itemBuilder: (context, index) {
                          final specialization =
                              state.availableSpecializations[index];
                          return CheckboxListTile(
                            value: tempSelection.contains(specialization.id),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelection.add(specialization.id);
                                } else {
                                  tempSelection.remove(specialization.id);
                                }
                              });
                            },
                            title: Text(specialization.name),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => Navigator.of(context).pop(tempSelection),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(UpdateInterpreterSpecializations(result));
    }
  }

  Future<void> _openLanguageSkillEditor(
    ProfileLoaded state,
    int languageId,
  ) async {
    if (!state.isInterpreter) return;
    if (state.availableSkills.isEmpty) {
      _showSnackBar('No skills catalog configured yet');
      return;
    }

    final language = state.availableLanguages.firstWhere(
      (lang) => lang.id == languageId,
      orElse: () => Language(id: languageId, name: 'Language $languageId'),
    );

    final currentSelection = Set<int>.from(
      state.languageSkillMap[languageId] ?? <int>{},
    );

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final tempSelection = Set<int>.from(currentSelection);
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: AppPadding.p20,
                  right: AppPadding.p20,
                  top: AppPadding.p20,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + AppPadding.p20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tag skills for ${language.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSize.s8),
                    Text(
                      'These skills will appear when requesters view this language.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorManager.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.availableSkills.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: AppSize.s1),
                        itemBuilder: (context, index) {
                          final skill = state.availableSkills[index];
                          return CheckboxListTile(
                            value: tempSelection.contains(skill.id),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelection.add(skill.id);
                                } else {
                                  tempSelection.remove(skill.id);
                                }
                              });
                            },
                            title: Text(skill.name),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => Navigator.of(context).pop(tempSelection),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(UpdateLanguageSkills(languageId, result));
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ColorManager.error : ColorManager.primary,
      ),
    );
  }

  // ============================================
  // UI Building Methods
  // ============================================

  Widget _buildHeroCard(ProfileLoaded state) {
    final imageProvider = _getAvatarProvider(state);
    final displayName =
        state.profile.username?.trim().isNotEmpty == true
            ? state.profile.username!.trim()
            : (state.isInterpreter ? 'Interpreter' : 'Requester');
    final memberSince = state.profile.createdAt?.year;
    final roleLabel = (state.profile.role ?? 'Member');

    return Container(
      padding: const EdgeInsets.all(AppPadding.p20),
      decoration: BoxDecoration(
        gradient: ColorManager.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ColorManager.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: imageProvider,
                    child:
                        imageProvider == null
                            ? Text(
                              _getInitials(state),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                            : const SizedBox(),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: ColorManager.primary2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSize.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSize.s8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroChip(label: _capitalize(roleLabel)),
                        if (_selectedGender != null)
                          _HeroChip(label: _selectedGender!),
                        if (memberSince != null)
                          _HeroChip(label: 'Since $memberSince'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s20),
          if (state.isInterpreter) ...[
            Row(
              children: [
                _ProfileStat(
                  label: 'Languages',
                  value: state.interpreterLanguages.length.toString(),
                ),
                _ProfileStat(
                  label: 'Specialties',
                  value: state.interpreterSpecializations.length.toString(),
                ),
                _ProfileStat(
                  label: 'Skills',
                  value: state.interpreterSkills.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s20),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showEditBasicsSheet(state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ColorManager.primary2,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit basics'),
              ),
              OutlinedButton.icon(
                onPressed: _pickImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.camera_enhance_outlined),
                label: const Text('Change photo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(ProfileLoaded state) {
    if (state.isInterpreter) {
      return _SectionCard(
        title: 'Interpreter snapshot',
        subtitle:
            'Keep your language pairs and specialties current so requesters can match you faster.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInterpreterBioSection(state),
            const SizedBox(height: AppSize.s20),
            _ChipGroup(
              title: 'Working languages',
              hint: 'Update languages to appear in search instantly.',
              chips: _buildLanguageChips(state),
              action: TextButton.icon(
                onPressed: () => _openLanguageEditor(state),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(height: AppSize.s20),
            _ChipGroup(
              title: 'Specializations',
              hint: 'Highlight your strongest domains (legal, medical, etc.).',
              chips: _buildSpecializationChips(state),
              action: TextButton.icon(
                onPressed: () => _openSpecializationEditor(state),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'Profile overview',
      subtitle: 'A quick glance for interpreters who accept your requests.',
      child: Column(
        children: [
          _buildRequesterInfoRow(
            label: 'Display name',
            value:
                state.profile.username?.trim().isNotEmpty == true
                    ? state.profile.username!.trim()
                    : 'Not set yet',
          ),
          const Divider(height: 32),
          _buildRequesterInfoRow(
            label: 'Email',
            value: state.userEmail ?? 'Not available',
          ),
          const Divider(height: 32),
          _buildRequesterInfoRow(
            label: 'Preferred pronouns',
            value: _selectedGender ?? 'Prefer not to share',
          ),
          const SizedBox(height: AppSize.s20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditBasicsSheet(state),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Update basics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpreterBioSection(ProfileLoaded state) {
    final bio = state.interpreterDetails?.bio;
    final years = state.interpreterDetails?.yearsExperience;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional summary',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: ColorManager.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          (bio != null && bio.trim().isNotEmpty)
              ? bio.trim()
              : 'No bio provided yet.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: ColorManager.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.workspace_premium,
              size: 18,
              color: ColorManager.primary2,
            ),
            const SizedBox(width: 8),
            Text(
              years != null && years > 0
                  ? '$years year${years == 1 ? '' : 's'} experience'
                  : 'Experience not set',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorManager.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillsCard(ProfileLoaded state) {
    return _SectionCard(
      title: 'Skills & strengths',
      subtitle: 'Tag skills for each language to show your expertise.',
      child: _buildLanguageSkillMatrix(state),
    );
  }

  Widget _buildLanguageSkillMatrix(ProfileLoaded state) {
    if (state.interpreterLanguages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Add working languages first to tag skills.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: ColorManager.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          state.interpreterLanguages.map((lang) {
            final skillIds = state.languageSkillMap[lang.languageId] ?? <int>{};
            final chips =
                skillIds.isEmpty
                    ? <Widget>[]
                    : skillIds
                        .map((id) => Chip(label: Text(_skillName(state, id))))
                        .toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColorManager.backgroundCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ColorManager.primary.withOpacity(0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _languageName(state, lang.languageId),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_fluencyLevel(state, lang.fluencyId)} fluency',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ColorManager.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            () => _openLanguageSkillEditor(
                              state,
                              lang.languageId,
                            ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          skillIds.isEmpty ? 'Add skills' : 'Edit skills',
                        ),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: chips),
                  ],
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildRequesterTipsCard() {
    final tips = [
      {
        'title': 'Share context early',
        'body':
            'Let interpreters know topic, participants, and desired tone inside the request message.',
      },
      {
        'title': 'Stay reachable',
        'body':
            'Keep notifications on after posting so you can accept the first available interpreter.',
      },
      {
        'title': 'Confirm logistics',
        'body':
            'Double-check timezone and meeting link details before the session starts.',
      },
    ];

    return _SectionCard(
      title: 'Make requests smoother',
      subtitle: 'Simple reminders that help interpreters jump in confidently.',
      child: Column(
        children:
            tips
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.brightness_1,
                          size: 8,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title'] as String,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip['body'] as String,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: ColorManager.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildRequesterInfoRow({
    required String label,
    required String value,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ColorManager.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: ColorManager.textPrimary),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLanguageChips(ProfileLoaded state) {
    if (state.interpreterLanguages.isEmpty) {
      return const [Chip(label: Text('No languages yet'))];
    }

    return state.interpreterLanguages.map((lang) {
      final label =
          '${_languageName(state, lang.languageId)} • ${_fluencyLevel(state, lang.fluencyId)}';
      return Chip(label: Text(label));
    }).toList();
  }

  List<Widget> _buildSpecializationChips(ProfileLoaded state) {
    return state.interpreterSpecializations.map((spec) {
      return Chip(
        label: Text(_specializationName(state, spec.specializationId)),
      );
    }).toList();
  }

  // ============================================
  // Helper Methods
  // ============================================

  ImageProvider<Object>? _getAvatarProvider(ProfileLoaded state) {
    if (_pickedImage != null) {
      return FileImage(File(_pickedImage!.path));
    }
    final image = state.profile.profileImage;
    if (image != null && image.isNotEmpty) {
      return NetworkImage(image);
    }
    return null;
  }

  String _getInitials(ProfileLoaded state) {
    final name = state.profile.username?.trim();
    if (name == null || name.isEmpty) {
      return state.isInterpreter ? 'IN' : 'RQ';
    }
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _languageName(ProfileLoaded state, int id) {
    final match = state.availableLanguages.firstWhere(
      (lang) => lang.id == id,
      orElse: () => Language(id: id, name: 'Language $id'),
    );
    return match.name;
  }

  String _specializationName(ProfileLoaded state, int id) {
    final match = state.availableSpecializations.firstWhere(
      (spec) => spec.id == id,
      orElse: () => Specialization(id: id, name: 'Specialization $id'),
    );
    return match.name;
  }

  String _skillName(ProfileLoaded state, int id) {
    final match = state.availableSkills.firstWhere(
      (skill) => skill.id == id,
      orElse: () => Skill(id: id, name: 'Skill $id'),
    );
    return match.name;
  }

  String _fluencyLevel(ProfileLoaded state, int id) {
    final match = state.fluencyLevels.firstWhere(
      (level) => level.id == id,
      orElse: () => throw Exception('Fluency level not found'),
    );
    return match.level;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String? _normalizeGender(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    for (final option in _genderOptions) {
      if (option.toLowerCase() == trimmed.toLowerCase()) {
        return option;
      }
    }
    return null;
  }
}

// ============================================
// Helper Widgets
// ============================================

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppPadding.p20),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ColorManager.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSize.s8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorManager.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSize.s16),
          child,
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.chips,
    this.hint,
    this.action,
  });

  final String title;
  final List<Widget> chips;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ColorManager.textPrimary,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorManager.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: AppSize.s12),
        if (chips.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorManager.backgroundPrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorManager.primary.withOpacity(0.08)),
            ),
            child: Text(
              hint ?? 'Nothing added yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorManager.textSecondary,
              ),
            ),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}
