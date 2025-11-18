import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/models/fluency_level.dart';
import 'package:interbridge/data/models/interpreter_language.dart';
import 'package:interbridge/data/models/interpreter_skill.dart';
import 'package:interbridge/data/models/interpreter_specialization.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/models/skill.dart';
import 'package:interbridge/data/models/specialization.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _usernameController = TextEditingController();

  UserProfile? _userProfile;
  List<InterpreterLanguage> _interpreterLanguages = [];
  List<InterpreterSpecialization> _interpreterSpecializations = [];
  List<InterpreterSkill> _interpreterSkills = [];
  List<Language> _languages = [];
  List<Specialization> _specializations = [];
  List<Skill> _skills = [];
  List<FluencyLevel> _fluencyLevels = [];
  String? _selectedGender;
  String? _userEmail;

  bool _isLoading = true;
  bool _isSaving = false;
  XFile? _pickedImage;

  bool get _isInterpreter =>
      (_userProfile?.role ?? '').toLowerCase() == 'interpreter';

  int get _defaultFluencyId =>
      _fluencyLevels.isNotEmpty ? _fluencyLevels.first.id : 1;

  final List<String> _genderOptions = const [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final profile = await _supabaseService.getUserProfile(user.id);
      final interpreterLanguages = await _supabaseService
          .getInterpreterLanguages(user.id);
      final interpreterSpecializations = await _supabaseService
          .getInterpreterSpecializations(user.id);
      final interpreterSkills = await _supabaseService.getInterpreterSkills(
        user.id,
      );
      final languages = await _supabaseService.getLanguages();
      final specializations = await _supabaseService.getSpecializations();
      final skills = await _supabaseService.getSkills();
      final fluencyLevels = await _supabaseService.getFluencyLevels();

      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _interpreterLanguages = interpreterLanguages;
        _interpreterSpecializations = interpreterSpecializations;
        _interpreterSkills = interpreterSkills;
        _languages = languages;
        _specializations = specializations;
        _skills = skills;
        _fluencyLevels = fluencyLevels;
        _selectedGender = _normalizeGender(profile?.gender);
        _usernameController.text = profile?.username ?? '';
        _userEmail = user.email;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not load profile: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _pickedImage = picked);
      await _saveProfile();
    } catch (e) {
      _showSnackBar('Unable to update photo: $e', isError: true);
    }
  }

  Future<void> _saveProfile() async {
    try {
      setState(() => _isSaving = true);
      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;
      if (_pickedImage != null) {
        final bytes = await File(_pickedImage!.path).readAsBytes();
        final filename =
            'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.${_pickedImage!.path.split('.').last}';
        imageUrl = await _supabaseService.uploadProfileImage(filename, bytes);
      }

      final updatedProfile = UserProfile(
        id: user.id,
        username: _usernameController.text.trim(),
        role: _userProfile?.role,
        profileImage: imageUrl ?? _userProfile?.profileImage,
        gender: _selectedGender,
        createdAt: _userProfile?.createdAt,
      );

      await _supabaseService.updateUserProfile(updatedProfile);

      if (!mounted) return;
      setState(() {
        _userProfile = updatedProfile;
        _pickedImage = null;
      });
      _showSnackBar('Profile updated');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error saving profile: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _openLanguageEditor() async {
    if (!_isInterpreter) return;
    if (_languages.isEmpty || _fluencyLevels.isEmpty) {
      _showSnackBar('Languages or fluency levels are not configured yet');
      return;
    }

    final currentSelection = {
      for (final lang in _interpreterLanguages) lang.languageId: lang.fluencyId,
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
                        itemCount: _languages.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: AppSize.s1),
                        itemBuilder: (context, index) {
                          final language = _languages[index];
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
                                        _defaultFluencyId;
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
                                          _defaultFluencyId,
                                      items:
                                          _fluencyLevels
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
      await _persistLanguageChanges(result);
    }
  }

  Future<void> _openSpecializationEditor() async {
    if (!_isInterpreter) return;
    if (_specializations.isEmpty) {
      _showSnackBar('No specialization catalog found yet');
      return;
    }

    final currentIds =
        _interpreterSpecializations.map((e) => e.specializationId).toSet();

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
                        itemCount: _specializations.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: AppSize.s1),
                        itemBuilder: (context, index) {
                          final specialization = _specializations[index];
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
      await _persistSpecializationChanges(result);
    }
  }

  Future<void> _persistLanguageChanges(Map<int, int> desired) async {
    try {
      setState(() => _isSaving = true);
      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final current = {
        for (final lang in _interpreterLanguages)
          lang.languageId: lang.fluencyId,
      };

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

      for (final langId in current.keys) {
        if (!desired.containsKey(langId)) {
          await _supabaseService.deleteInterpreterLanguage(user.id, langId);
        }
      }

      await _refreshInterpreterData();
      _showSnackBar('Languages updated');
    } catch (e) {
      _showSnackBar('Failed to update languages: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _persistSpecializationChanges(Set<int> desiredIds) async {
    try {
      setState(() => _isSaving = true);
      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final currentIds =
          _interpreterSpecializations.map((e) => e.specializationId).toSet();

      final toAdd = desiredIds.difference(currentIds);
      final toRemove = currentIds.difference(desiredIds);

      for (final id in toAdd) {
        await _supabaseService.addInterpreterSpecialization(
          InterpreterSpecialization(userId: user.id, specializationId: id),
        );
      }
      for (final id in toRemove) {
        await _supabaseService.deleteInterpreterSpecialization(user.id, id);
      }

      await _refreshInterpreterData();
      _showSnackBar('Specializations updated');
    } catch (e) {
      _showSnackBar('Failed to update specializations: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _refreshInterpreterData() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return;

    final languages = await _supabaseService.getInterpreterLanguages(user.id);
    final specializations = await _supabaseService
        .getInterpreterSpecializations(user.id);
    final skills = await _supabaseService.getInterpreterSkills(user.id);

    if (!mounted) return;
    setState(() {
      _interpreterLanguages = languages;
      _interpreterSpecializations = specializations;
      _interpreterSkills = skills;
    });
  }

  void _showEditBasicsSheet() {
    _usernameController.text = _userProfile?.username ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppPadding.p20,
            right: AppPadding.p20,
            top: AppPadding.p20,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppPadding.p20,
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
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: AppSize.s20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveProfile();
                  },
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Profile'),
        foregroundColor: ColorManager.primary2,
        backgroundColor: ColorManager.backgroundPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_isSaving) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _loadProfile,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppPadding.p20,
                          vertical: AppPadding.p20,
                        ),
                        children: [
                          _buildHeroCard(),
                          const SizedBox(height: AppSize.s20),
                          _buildSnapshotCard(),
                          if (_interpreterSkills.isNotEmpty) ...[
                            const SizedBox(height: AppSize.s20),
                            _buildSkillsCard(),
                          ],
                          if (!_isInterpreter) ...[
                            const SizedBox(height: AppSize.s20),
                            _buildRequesterTipsCard(),
                          ],
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final imageProvider = _avatarProvider;
    final displayName =
        _userProfile?.username?.trim().isNotEmpty == true
            ? _userProfile!.username!.trim()
            : (_isInterpreter ? 'Interpreter' : 'Requester');
    final memberSince =
        _userProfile?.createdAt != null ? _userProfile!.createdAt!.year : null;
    final roleLabel = (_userProfile?.role ?? 'Member');

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
                              _initials,
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
          Row(
            children: [
              _ProfileStat(
                label: 'Languages',
                value: _interpreterLanguages.length.toString(),
              ),
              _ProfileStat(
                label: 'Specialties',
                value: _interpreterSpecializations.length.toString(),
              ),
              _ProfileStat(
                label: 'Skills',
                value: _interpreterSkills.length.toString(),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _showEditBasicsSheet,
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

  Widget _buildSnapshotCard() {
    if (_isInterpreter) {
      return _SectionCard(
        title: 'Interpreter snapshot',
        subtitle:
            'Keep your language pairs and niches current so requesters can match like Tarjimly.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChipGroup(
              title: 'Working languages',
              hint: 'Update languages to appear in search instantly.',
              chips: _buildLanguageChips(),
              action: TextButton.icon(
                onPressed: _openLanguageEditor,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(height: AppSize.s20),
            _ChipGroup(
              title: 'Specializations',
              hint: 'Highlight your strongest domains (legal, medical, etc.).',
              chips: _buildSpecializationChips(),
              action: TextButton.icon(
                onPressed: _openSpecializationEditor,
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
                _userProfile?.username?.trim().isNotEmpty == true
                    ? _userProfile!.username!.trim()
                    : 'Not set yet',
          ),
          const Divider(height: 32),
          _buildRequesterInfoRow(
            label: 'Email',
            value: _userEmail ?? 'Not available',
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
              onPressed: _showEditBasicsSheet,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Update basics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    final skillChips =
        _interpreterSkills.isEmpty
            ? const [Chip(label: Text('No skills listed yet'))]
            : _interpreterSkills
                .map((skill) => Chip(label: Text(_skillName(skill.skillId))))
                .toList();

    return _SectionCard(
      title: 'Skills & strengths',
      subtitle: 'Your go-to abilities that requesters can count on.',
      child: Wrap(spacing: 8, runSpacing: 8, children: skillChips),
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

  List<Widget> _buildLanguageChips() {
    if (_interpreterLanguages.isEmpty) {
      return const [Chip(label: Text('No languages yet'))];
    }

    return _interpreterLanguages.map((lang) {
      final label =
          '${_languageName(lang.languageId)} • ${_fluencyLevel(lang.fluencyId)}';
      return Chip(label: Text(label));
    }).toList();
  }

  List<Widget> _buildSpecializationChips() {
    if (_interpreterSpecializations.isEmpty) {
      return const [Chip(label: Text('No specializations yet'))];
    }

    return _interpreterSpecializations.map((spec) {
      return Chip(label: Text(_specializationName(spec.specializationId)));
    }).toList();
  }

  ImageProvider<Object>? get _avatarProvider {
    if (_pickedImage != null) {
      return FileImage(File(_pickedImage!.path));
    }
    final image = _userProfile?.profileImage;
    if (image != null && image.isNotEmpty) {
      return NetworkImage(image);
    }
    return null;
  }

  String get _initials {
    final name = _userProfile?.username?.trim();
    if (name == null || name.isEmpty) {
      return _isInterpreter ? 'IN' : 'RQ';
    }
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _languageName(int id) {
    final match = _languages.firstWhere(
      (lang) => lang.id == id,
      orElse: () => Language(id: id, name: 'Language $id'),
    );
    return match.name;
  }

  String _specializationName(int id) {
    final match = _specializations.firstWhere(
      (spec) => spec.id == id,
      orElse: () => Specialization(id: id, name: 'Specialization $id'),
    );
    return match.name;
  }

  String _skillName(int id) {
    final match = _skills.firstWhere(
      (skill) => skill.id == id,
      orElse: () => Skill(id: id, name: 'Skill $id'),
    );
    return match.name;
  }

  String _fluencyLevel(int id) {
    final match = _fluencyLevels.firstWhere(
      (level) => level.id == id,
      orElse: () => FluencyLevel(id: id, level: 'Fluent'),
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
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}
