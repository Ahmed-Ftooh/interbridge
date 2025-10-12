import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/widgets/custom_dialog.dart';

import 'package:interbridge/data/models/language.dart';

class RequesterHomeView extends StatefulWidget {
  const RequesterHomeView({super.key});

  @override
  State<RequesterHomeView> createState() => _RequesterHomeViewState();
}

class _RequesterHomeViewState extends State<RequesterHomeView> {
  String? selectedSpecialization;
  String? selectedUrgency;
  bool isOnlineFilter = false;
  bool isAvailableFilter = false;

  // Language selection variables
  Language? selectedFromLanguage;
  Language? selectedToLanguage;
  List<Language> languages = [];
  bool isLoadingLanguages = true;

  final List<String> specializations = [
    'Medical',
    'Legal',
    'Business',
    'Education',
    'Mental Health',
    'Emergency Response',
    'Social Services',
    'Documentation',
  ];

  final List<String> urgencyLevels = ['Low', 'Normal', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    try {
      final languagesList = await SupabaseService().getLanguages();
      setState(() {
        languages = languagesList;
        isLoadingLanguages = false;
      });
    } catch (e) {
      log('Error loading languages: $e');
      setState(() {
        isLoadingLanguages = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: AppSize.s24),

                // Language Selection Section
                _buildLanguageSelection(),
                const SizedBox(height: AppSize.s24),

                // Filters Section
                _buildFiltersSection(),
                const SizedBox(height: AppSize.s24),

                // Action Buttons
                _buildActionButtons(),
                const SizedBox(height: AppSize.s24),

                // Recent Activity
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSize.s20),
      decoration: BoxDecoration(
        gradient: ColorManager.primaryGradient,
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSize.s28,
            backgroundColor: ColorManager.white,
            child: Icon(
              Icons.person,
              color: ColorManager.primary,
              size: AppSize.s28,
            ),
          ),
          const SizedBox(width: AppSize.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.welcomeBackExclamation,
                  style: TextStyle(
                    color: ColorManager.white,
                    fontSize: AppSize.s20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSize.s4),
                Text(
                  'Ready to connect with interpreters?',
                  style: TextStyle(
                    color: ColorManager.white.withValues(alpha: 0.9),
                    fontSize: AppSize.s14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelection() {
    if (isLoadingLanguages) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Language Pair',
            style: TextStyle(
              fontSize: AppSize.s18,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          const SizedBox(height: AppSize.s16),
          Container(
            padding: const EdgeInsets.all(AppSize.s20),
            decoration: BoxDecoration(
              color: ColorManager.white,
              borderRadius: BorderRadius.circular(AppSize.s12),
              border: Border.all(color: ColorManager.greyMedium, width: 1),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language Pair',
          style: TextStyle(
            fontSize: AppSize.s18,
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s16),
        Column(
          children: [
            // From Language
            GestureDetector(
              onTap: () => _showLanguageBottomSheet(true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  color: ColorManager.white,
                  borderRadius: BorderRadius.circular(AppSize.s12),
                  border: Border.all(color: ColorManager.greyMedium, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          size: AppSize.s16,
                          color: ColorManager.primary,
                        ),
                        const SizedBox(width: AppSize.s8),
                        Text(
                          'From',
                          style: TextStyle(
                            fontSize: AppSize.s12,
                            fontWeight: FontWeight.w500,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSize.s8),
                    Text(
                      selectedFromLanguage?.name ?? 'Select language',
                      style: TextStyle(
                        fontSize: AppSize.s14,
                        fontWeight: FontWeight.w600,
                        color:
                            selectedFromLanguage != null
                                ? ColorManager.textPrimary
                                : ColorManager.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSize.s12),
            // Arrow
            Center(
              child: Icon(
                Icons.arrow_downward,
                color: ColorManager.primary,
                size: AppSize.s20,
              ),
            ),
            const SizedBox(height: AppSize.s12),
            // To Language
            GestureDetector(
              onTap: () => _showLanguageBottomSheet(false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  color: ColorManager.white,
                  borderRadius: BorderRadius.circular(AppSize.s12),
                  border: Border.all(color: ColorManager.greyMedium, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          size: AppSize.s16,
                          color: ColorManager.primary,
                        ),
                        const SizedBox(width: AppSize.s8),
                        Text(
                          'To',
                          style: TextStyle(
                            fontSize: AppSize.s12,
                            fontWeight: FontWeight.w500,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSize.s8),
                    Text(
                      selectedToLanguage?.name ?? 'Select language',
                      style: TextStyle(
                        fontSize: AppSize.s14,
                        fontWeight: FontWeight.w600,
                        color:
                            selectedToLanguage != null
                                ? ColorManager.textPrimary
                                : ColorManager.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLanguageBottomSheet(bool isFromLanguage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: ColorManager.backgroundPrimary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSize.s20),
              topRight: Radius.circular(AppSize.s20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppSize.s12),
                width: AppSize.s40,
                height: AppSize.s4,
                decoration: BoxDecoration(
                  color: ColorManager.greyMedium,
                  borderRadius: BorderRadius.circular(AppSize.s2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSize.s20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select ${isFromLanguage ? 'From' : 'To'} Language',
                      style: TextStyle(
                        fontSize: AppSize.s22,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: ColorManager.textSecondary,
                        size: AppSize.s24,
                      ),
                    ),
                  ],
                ),
              ),
              // Language Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSize.s20),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSize.s12,
                          mainAxisSpacing: AppSize.s12,
                          childAspectRatio: 2.5,
                        ),
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final language = languages[index];
                      final isSelected =
                          isFromLanguage
                              ? selectedFromLanguage?.id == language.id
                              : selectedToLanguage?.id == language.id;

                      return GestureDetector(
                        onTap: () {
                          if (isFromLanguage) {
                            setState(() {
                              selectedFromLanguage = language;
                            });
                          } else {
                            setState(() {
                              selectedToLanguage = language;
                            });
                          }
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSize.s16,
                            vertical: AppSize.s12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? ColorManager.primary
                                    : ColorManager.white,
                            borderRadius: BorderRadius.circular(AppSize.s12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? ColorManager.primary
                                      : ColorManager.greyMedium,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ColorManager.black.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: AppSize.s8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.language,
                                color:
                                    isSelected
                                        ? ColorManager.white
                                        : ColorManager.textSecondary,
                                size: AppSize.s18,
                              ),
                              const SizedBox(width: AppSize.s8),
                              Expanded(
                                child: Text(
                                  language.name,
                                  style: TextStyle(
                                    fontSize: AppSize.s10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected
                                            ? ColorManager.white
                                            : ColorManager.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filters',
          style: TextStyle(
            fontSize: AppSize.s18,
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s16),

        // Specialization Filter
        _buildDropdownFilter(
          title: 'Specialization',
          value: selectedSpecialization,
          hint: 'Select specialization',
          items: specializations,
          onChanged: (value) {
            setState(() {
              selectedSpecialization = value;
            });
          },
        ),

        const SizedBox(height: AppSize.s16),

        // Urgency Filter
        _buildDropdownFilter(
          title: 'Urgency',
          value: selectedUrgency,
          hint: 'Select urgency level',
          items: urgencyLevels,
          onChanged: (value) {
            setState(() {
              selectedUrgency = value;
            });
          },
        ),

        // Status Filters
      ],
    );
  }

  Widget _buildDropdownFilter({
    required String title,
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppSize.s14,
            fontWeight: FontWeight.w600,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.s12),
          decoration: BoxDecoration(
            color: ColorManager.white,
            borderRadius: BorderRadius.circular(AppSize.s12),
            border: Border.all(color: ColorManager.greyMedium, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                hint,
                style: TextStyle(
                  color: ColorManager.textSecondary,
                  fontSize: AppSize.s14,
                ),
              ),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: ColorManager.textSecondary,
              ),
              items:
                  items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: TextStyle(
                          color: ColorManager.textPrimary,
                          fontSize: AppSize.s14,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Request Interpreter Button
        SizedBox(
          width: double.infinity,
          height: AppSize.s55,
          child: ElevatedButton(
            onPressed: () {
              // Handle request interpreter
              _showRequestDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primary,
              foregroundColor: ColorManager.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.s16),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_in_talk, size: AppSize.s20),
                SizedBox(width: AppSize.s8),
                Text(
                  'Request Interpreter',
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSize.s12),

        const SizedBox(height: AppSize.s16),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: AppSize.s18,
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s16),
        Container(
          padding: const EdgeInsets.all(AppSize.s20),
          decoration: BoxDecoration(
            color: ColorManager.white,
            borderRadius: BorderRadius.circular(AppSize.s16),
            border: Border.all(
              color: ColorManager.greyMedium.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: AppSize.s50,
                color: ColorManager.textSecondary,
              ),
              const SizedBox(height: AppSize.s12),
              Text(
                'No recent activity',
                style: TextStyle(
                  fontSize: AppSize.s16,
                  fontWeight: FontWeight.w600,
                  color: ColorManager.textSecondary,
                ),
              ),
              const SizedBox(height: AppSize.s8),
              Text(
                'Your recent interpreter requests will appear here',
                style: TextStyle(
                  fontSize: AppSize.s14,
                  color: ColorManager.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRequestDialog() {
    // Validate that both languages are selected
    if (selectedFromLanguage == null || selectedToLanguage == null) {
      (context).showCustomDialog(
        title: 'Missing Information',
        content:
            'Please select both "From" and "To" languages before requesting an interpreter.',
        confirmText: 'OK',

        icon: Icons.warning,
        iconColor: ColorManager.primary,
      );
      return;
    }

    // Show confirmation dialog
    (context).showCustomDialog(
      title: 'Request Interpreter',
      content:
          'Are you sure you want to request an interpreter for ${selectedFromLanguage?.name} to ${selectedToLanguage?.name}?',
      confirmText: 'Request',
      cancelText: 'Cancel',
      icon: Icons.phone_in_talk,
      iconColor: ColorManager.primary,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () async {
        Navigator.of(context).pop(); // Close dialog

        // Navigate to waiting screen with Lottie while creating & waiting
        Navigator.of(context).pushNamed(
          Routes.requestWaiting,
          arguments: {
            'fromLanguageId': selectedFromLanguage!.id.toString(),
            'toLanguageId': selectedToLanguage!.id.toString(),
            'specialization': selectedSpecialization,
            'urgency': selectedUrgency ?? 'Normal',
            'description': null,
          },
        );
      },
    );
  }
}
