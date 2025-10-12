import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/models/specialization.dart';
import 'package:interbridge/data/models/skill.dart';
import 'package:file_picker/file_picker.dart';
import 'package:interbridge/data/models/interpreter_details.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  bool _isLoading = false;
  UserProfile? _userProfile;

  // Form controllers
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedGender;
  String? _selectedRole;

  // Lists for dropdowns
  List<Language> _languages = [];
  List<Specialization> _specializations = [];
  List<Skill> _skills = [];

  // Selected items for interpreter
  List<Language> _selectedLanguages = [];
  List<Specialization> _selectedSpecializations = [];
  List<Skill> _selectedSkills = [];

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  final List<String> _roleOptions = ['requester', 'interpreter'];

  String? _certificateUrl;
  File? _certificateFile;

  // Certificate form controllers
  final TextEditingController _certificateTypeController =
      TextEditingController();
  final TextEditingController _issuingOrganizationController =
      TextEditingController();
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    _validateDropdownData();
    _loadUserProfile();
    _loadData();
    _loadInterpreterDetailsIfAny();
  }

  void _validateDropdownData() {
    // Validate hardcoded lists don't have duplicates
    final genderSet = _genderOptions.toSet();
    final roleSet = _roleOptions.toSet();

    if (genderSet.length != _genderOptions.length) {
      log('Warning: Duplicate values found in _genderOptions');
      _genderOptions.clear();
      _genderOptions.addAll(genderSet);
    }

    if (roleSet.length != _roleOptions.length) {
      log('Warning: Duplicate values found in _roleOptions');
      _roleOptions.clear();
      _roleOptions.addAll(roleSet);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);
      final userId = SupabaseService().getCurrentUser()?.id;

      if (userId != null) {
        final profile = await SupabaseService().getUserProfile(userId);
        if (profile != null) {
          // Debug: Check profile values
          log(
            'Profile loaded - Gender: "${profile.gender}", Role: "${profile.role}"',
          );
          log('Available gender options: $_genderOptions');
          log('Available role options: $_roleOptions');

          // Validate that loaded values exist in the options
          final validGender =
              _genderOptions.contains(profile.gender) ? profile.gender : null;
          final validRole =
              _roleOptions.contains(profile.role) ? profile.role : null;

          if (validGender != profile.gender) {
            log(
              'Warning: Invalid gender value "${profile.gender}" reset to null',
            );
          }
          if (validRole != profile.role) {
            log('Warning: Invalid role value "${profile.role}" reset to null');
          }

          setState(() {
            _userProfile = profile;
            _usernameController.text = profile.username ?? '';
            _selectedGender = validGender;
            _selectedRole = validRole;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error loading profile: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    try {
      final supabaseService = SupabaseService();
      final languages = await supabaseService.getLanguages();
      final specializations = await supabaseService.getSpecializations();
      final skills = await supabaseService.getSkills();

      // Debug: Check for duplicate values
      final languageNames = languages.map((l) => l.name).toList();
      final specializationNames = specializations.map((s) => s.name).toList();
      final skillNames = skills.map((s) => s.name).toList();

      log('Languages loaded: ${languageNames.length}');
      log(
        'Languages with duplicates: ${languageNames.length != languageNames.toSet().length}',
      );
      log('Specializations loaded: ${specializationNames.length}');
      log(
        'Specializations with duplicates: ${specializationNames.length != specializationNames.toSet().length}',
      );
      log('Skills loaded: ${skillNames.length}');
      log(
        'Skills with duplicates: ${skillNames.length != skillNames.toSet().length}',
      );

      setState(() {
        _languages = languages;
        _specializations = specializations;
        _skills = skills;
      });
    } catch (e) {
      _showSnackBar('Error loading data: $e', isError: true);
    }
  }

  Future<void> _loadInterpreterDetailsIfAny() async {
    try {
      final userId = SupabaseService().getCurrentUser()?.id;
      if (userId == null) return;
      final details = await SupabaseService().getInterpreterDetails(userId);
      setState(() {
        _certificateUrl = details?.certificateUrl;
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _saveProfile() async {
    try {
      setState(() => _isLoading = true);

      final supabaseService = SupabaseService();
      final userId = supabaseService.getCurrentUser()?.id;

      if (userId == null) {
        _showSnackBar('User not authenticated', isError: true);
        return;
      }

      // If a new image was picked, upload it first
      String? newImageUrl;
      if (_pickedImage != null) {
        try {
          final bytes = await File(_pickedImage!.path).readAsBytes();
          final filename =
              'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.${_pickedImage!.path.split('.').last}';
          newImageUrl = await supabaseService.uploadProfileImage(
            filename,
            bytes,
          );
        } catch (e) {
          _showSnackBar('Image upload failed: $e', isError: true);
        }
      }

      // Create updated profile
      final updatedProfile = UserProfile(
        id: userId,
        username: _usernameController.text.trim(),
        role: _selectedRole,
        profileImage: newImageUrl ?? _userProfile?.profileImage,
        gender: _selectedGender,
        createdAt: _userProfile?.createdAt,
      );

      await supabaseService.updateUserProfile(updatedProfile);

      // If user is interpreter, update their data
      if (_selectedRole == 'interpreter') {
        await _updateInterpreterData(userId);
      }

      _showSnackBar('Profile updated successfully!');
      if (newImageUrl != null) {
        setState(() {
          _pickedImage = null;
        });
      }
      await _loadUserProfile(); // Reload to get updated data
    } catch (e) {
      _showSnackBar('Error updating profile: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateInterpreterData(String userId) async {
    try {
      // Update languages
      for (final _ in _selectedLanguages) {
        // Add language if not exists
        // This would need to be implemented in your service
      }

      // Update specializations
      for (final _ in _selectedSpecializations) {
        // Add specialization if not exists
        // This would need to be implemented in your service
      }

      // Update skills
      for (final _ in _selectedSkills) {
        // Add skill if not exists
        // This would need to be implemented in your service
      }
    } catch (e) {
      _showSnackBar('Error updating interpreter data: $e', isError: true);
    }
  }

  Future<void> _pickCertificateFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _certificateFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking certificate: $e', isError: true);
    }
  }

  Future<void> _uploadCertificate() async {
    if (_certificateFile == null) return;
    try {
      setState(() => _isLoading = true);

      // Get certificate details from form
      final certificateType =
          _certificateTypeController.text.isNotEmpty
              ? _certificateTypeController.text
              : 'medical_interpreter';
      final issuingOrg =
          _issuingOrganizationController.text.isNotEmpty
              ? _issuingOrganizationController.text
              : null;
      final expirationDate = _expirationDate;

      final url = await SupabaseService().uploadInterpreterCertificate(
        _certificateFile!,
        certificateType: certificateType,
        issuingOrganization: issuingOrg,
        expirationDate: expirationDate,
      );

      final userId = SupabaseService().getCurrentUser()?.id;
      if (userId != null) {
        final details = InterpreterDetails(userId: userId, certificateUrl: url);
        await SupabaseService().updateInterpreterDetails(details);
      }

      setState(() {
        _certificateUrl = url;
        _certificateFile = null;
        _certificateTypeController.clear();
        _issuingOrganizationController.clear();
        _expirationDate = null;
      });
      _showSnackBar(
        'Certificate uploaded successfully! It will be reviewed by our team.',
      );
    } catch (e) {
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ColorManager.error : ColorManager.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSize.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: AppSize.s24),
                    _buildBasicInfoSection(),
                    const SizedBox(height: AppSize.s24),
                    if (_selectedRole == 'interpreter') ...[
                      _buildInterpreterSection(),
                      const SizedBox(height: AppSize.s24),
                    ],
                    _buildSaveButton(),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          // Profile Picture
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ColorManager.primary2, width: 4),
                ),
                child: ClipOval(
                  child:
                      _pickedImage != null
                          ? Image.file(
                            File(_pickedImage!.path),
                            fit: BoxFit.cover,
                          )
                          : _userProfile?.profileImage != null
                          ? Image.network(
                            _userProfile!.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    _buildDefaultAvatar(),
                          )
                          : _buildDefaultAvatar(),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(AppSize.s8),
                    decoration: BoxDecoration(
                      color: ColorManager.primary2,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: AppSize.s20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s16),
          Text(
            _userProfile?.username ?? 'Username',
            style: TextStyle(
              fontSize: AppSize.s24,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          Text(
            _userProfile?.role?.toUpperCase() ?? 'USER',
            style: TextStyle(
              fontSize: AppSize.s14,
              fontWeight: FontWeight.w500,
              color: ColorManager.primary2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: ColorManager.greyLight,
      child: Icon(
        Icons.person,
        size: AppSize.s60,
        color: ColorManager.greyMedium,
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: AppSize.s18,
                fontWeight: FontWeight.bold,
                color: ColorManager.textPrimary,
              ),
            ),
            const SizedBox(height: AppSize.s20),

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
        ),
      ),
    );
  }

  Widget _buildInterpreterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.translate,
                  color: ColorManager.primary2,
                  size: AppSize.s20,
                ),
                const SizedBox(width: AppSize.s8),
                Text(
                  'Interpreter Details',
                  style: TextStyle(
                    fontSize: AppSize.s18,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s20),

            // Languages
            _buildMultiSelectDropdown(
              label: 'Languages',
              selectedItems: _selectedLanguages.map((l) => l.name).toList(),
              allItems: _languages.map((l) => l.name).toList(),
              onChanged: (selectedNames) {
                setState(() {
                  _selectedLanguages =
                      _languages
                          .where((l) => selectedNames.contains(l.name))
                          .toList();
                });
              },
              icon: Icons.language,
            ),
            const SizedBox(height: AppSize.s16),

            // Specializations
            _buildMultiSelectDropdown(
              label: 'Specializations',
              selectedItems:
                  _selectedSpecializations.map((s) => s.name).toList(),
              allItems: _specializations.map((s) => s.name).toList(),
              onChanged: (selectedNames) {
                setState(() {
                  _selectedSpecializations =
                      _specializations
                          .where((s) => selectedNames.contains(s.name))
                          .toList();
                });
              },
              icon: Icons.medical_services,
            ),
            const SizedBox(height: AppSize.s16),

            // Skills
            _buildMultiSelectDropdown(
              label: 'Skills',
              selectedItems: _selectedSkills.map((s) => s.name).toList(),
              allItems: _skills.map((s) => s.name).toList(),
              onChanged: (selectedNames) {
                setState(() {
                  _selectedSkills =
                      _skills
                          .where((s) => selectedNames.contains(s.name))
                          .toList();
                });
              },
              icon: Icons.star,
            ),
            const SizedBox(height: AppSize.s16),

            // Certificate Upload Section
            _buildCertificateUploadSection(),
          ],
        ),
      ),
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
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: ColorManager.primary2),
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.greyMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.greyMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.primary2, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
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
    // Remove duplicates from items list
    final uniqueItems = items.toSet().toList();

    // Validate that the selected value exists in the items list
    String? validValue = value;
    if (value != null && !uniqueItems.contains(value)) {
      validValue = null; // Reset to null if value doesn't exist in items
      log(
        'Warning: Selected value "$value" not found in items list for $label',
      );
      log('Available items: $uniqueItems');
    }

    // Ensure we have at least one item to prevent dropdown assertion error
    if (uniqueItems.isEmpty) {
      log('Warning: No items available for dropdown $label');
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
            padding: const EdgeInsets.all(AppSize.s16),
            decoration: BoxDecoration(
              border: Border.all(color: ColorManager.greyMedium),
              borderRadius: BorderRadius.circular(AppSize.s12),
              color: Colors.grey[200],
            ),
            child: Text(
              'No options available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      );
    }

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
            value: validValue,
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
                uniqueItems.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<String> selectedItems,
    required List<String> allItems,
    required Function(List<String>) onChanged,
    required IconData icon,
  }) {
    // Remove duplicates from all items list
    final uniqueAllItems = allItems.toSet().toList();

    // Filter selected items to only include valid ones
    final validSelectedItems =
        selectedItems.where((item) => uniqueAllItems.contains(item)).toList();

    // If there are invalid selected items, update the parent
    if (validSelectedItems.length != selectedItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChanged(validSelectedItems);
      });
    }

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
        GestureDetector(
          onTap:
              () => _showMultiSelectDialog(
                label,
                validSelectedItems,
                uniqueAllItems,
                onChanged,
              ),
          child: Container(
            padding: const EdgeInsets.all(AppSize.s16),
            decoration: BoxDecoration(
              border: Border.all(color: ColorManager.greyMedium),
              borderRadius: BorderRadius.circular(AppSize.s12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(icon, color: ColorManager.primary2),
                const SizedBox(width: AppSize.s12),
                Expanded(
                  child: Text(
                    validSelectedItems.isEmpty
                        ? 'Select $label'
                        : validSelectedItems.join(', '),
                    style: TextStyle(
                      color:
                          validSelectedItems.isEmpty
                              ? ColorManager.textSecondary
                              : ColorManager.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: ColorManager.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMultiSelectDialog(
    String label,
    List<String> selectedItems,
    List<String> allItems,
    Function(List<String>) onChanged,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select $label'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final isSelected = selectedItems.contains(item);

                  return CheckboxListTile(
                    title: Text(item),
                    value: isSelected,
                    onChanged: (value) {
                      if (value == true) {
                        onChanged([...selectedItems, item]);
                      } else {
                        onChanged(
                          selectedItems.where((i) => i != item).toList(),
                        );
                      }
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSize.s55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.primary2,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.s16),
          ),
          elevation: 2,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: AppSize.s20,
                  width: AppSize.s20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Text(
                  'Save Profile',
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Widget _buildCertificateUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.verified_user,
              color: ColorManager.primary2,
              size: AppSize.s20,
            ),
            const SizedBox(width: AppSize.s8),
            Text(
              'Medical/Interpreting Certificate',
              style: TextStyle(
                fontSize: AppSize.s16,
                fontWeight: FontWeight.w600,
                color: ColorManager.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSize.s8),

        // Certificate type field
        TextField(
          controller: _certificateTypeController,
          decoration: InputDecoration(
            labelText:
                'Certificate Type (e.g., Medical Interpreter, CCHI, NBCMI)',
            hintText: 'Enter the type of certificate',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s8),
            ),
            prefixIcon: const Icon(Icons.school),
          ),
        ),
        const SizedBox(height: AppSize.s12),

        // Issuing organization field
        TextField(
          controller: _issuingOrganizationController,
          decoration: InputDecoration(
            labelText: 'Issuing Organization',
            hintText: 'Enter the organization that issued the certificate',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s8),
            ),
            prefixIcon: const Icon(Icons.business),
          ),
        ),
        const SizedBox(height: AppSize.s12),

        // Expiration date field
        InkWell(
          onTap: _selectExpirationDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSize.s12,
              vertical: AppSize.s16,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(AppSize.s8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: AppSize.s8),
                Expanded(
                  child: Text(
                    _expirationDate != null
                        ? 'Expires: ${_expirationDate!.toLocal().toString().split(' ')[0]}'
                        : 'Select expiration date (optional)',
                    style: TextStyle(
                      color:
                          _expirationDate != null
                              ? ColorManager.textPrimary
                              : Colors.grey[600],
                    ),
                  ),
                ),
                if (_expirationDate != null)
                  IconButton(
                    onPressed: () => setState(() => _expirationDate = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSize.s12),

        // File upload section
        Container(
          padding: const EdgeInsets.all(AppSize.s16),
          decoration: BoxDecoration(
            color: ColorManager.greyLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSize.s8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _certificateFile != null
                          ? 'Selected: ${_certificateFile!.path.split('/').last}'
                          : (_certificateUrl != null
                              ? 'Certificate uploaded ✓'
                              : 'No certificate selected'),
                      style: TextStyle(
                        color:
                            _certificateUrl != null
                                ? Colors.green
                                : ColorManager.textPrimary,
                        fontWeight:
                            _certificateUrl != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickCertificateFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose File'),
                  ),
                  const SizedBox(width: AppSize.s8),
                  ElevatedButton(
                    onPressed:
                        _certificateFile != null ? _uploadCertificate : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primary2,
                    ),
                    child: const Text(
                      'Upload',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (_certificateUrl != null) ...[
                const SizedBox(height: AppSize.s8),
                SelectableText(
                  _certificateUrl!,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSize.s8),

        // Qualification requirements info
        Container(
          padding: const EdgeInsets.all(AppSize.s12),
          decoration: BoxDecoration(
            color: ColorManager.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSize.s8),
            border: Border.all(color: ColorManager.info.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: ColorManager.info,
                    size: AppSize.s16,
                  ),
                  const SizedBox(width: AppSize.s8),
                  Text(
                    'Qualification Requirements',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorManager.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSize.s8),
              Text(
                '• Medical interpreters must have valid certification from recognized organizations\n'
                '• Certificates must be current and not expired\n'
                '• All certificates will be verified by our team\n'
                '• Accepted formats: PDF, JPG, JPEG, PNG (max 25MB)',
                style: TextStyle(
                  fontSize: AppSize.s12,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _expirationDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 10),
      ), // 10 years from now
    );
    if (picked != null && picked != _expirationDate) {
      setState(() => _expirationDate = picked);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _certificateTypeController.dispose();
    _issuingOrganizationController.dispose();
    super.dispose();
  }
}
