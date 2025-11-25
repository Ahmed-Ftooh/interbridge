import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_event.dart'
    as fluency_event;
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_state.dart';
import 'package:interbridge/core/language_mapping_utility.dart';

class LanguageFluencyScreen extends StatefulWidget {
  const LanguageFluencyScreen({super.key});

  @override
  State<LanguageFluencyScreen> createState() => _LanguageFluencyScreenState();
}

class _LanguageFluencyScreenState extends State<LanguageFluencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _slideController.forward();
    // BLoC initialization will be handled in build
  }

  @override
  Widget build(BuildContext context) {
    // Accept the data map from arguments
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    // Handle both List<int> (language IDs) and List<String> (language names)
    final languagesData = data['languages'];
    List<String> selectedLanguages = [];
    if (languagesData is List && languagesData.isNotEmpty) {
      if (languagesData.first is int) {
        // Convert language IDs to language names
        selectedLanguages = LanguageMappingUtility.convertIdsToNames(
          languagesData.cast<int>(),
        );
      } else {
        // Already language names
        selectedLanguages = languagesData.map((e) => e.toString()).toList();
      }
    }
    // Initialize BLoC state only once
    if (BlocProvider.of<LanguageFluencyBloc>(
          context,
        ).state.selectedLanguages.isEmpty &&
        selectedLanguages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LanguageFluencyBloc>().add(
          fluency_event.InitializeLanguages(selectedLanguages),
        );
      });
    }
    return BlocConsumer<LanguageFluencyBloc, LanguageFluencyState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          CustomSnackBar.show(
            context,
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
        if (state.isComplete) {
          // Convert fluency map to use language IDs as keys
          final Map<String, String?> fluencyWithIds = {};
          for (final languageName in state.selectedLanguages) {
            final languageId = LanguageMappingUtility.getLanguageId(
              languageName,
            );
            if (languageId != 0 && state.fluencyMap.containsKey(languageName)) {
              fluencyWithIds[languageId.toString()] =
                  state.fluencyMap[languageName];
            }
          }

          // Add fluency info to the data map
          data['fluency'] = fluencyWithIds;

          // Convert skill names to IDs
          final List<int> skillIds = [];
          final skills = <Map<String, dynamic>>[
            {
              'name': 'Speak',
              'description': 'Conversation & Speaking',
              'icon': Icons.record_voice_over,
              'color': ColorManager.primary,
              'id': 1,
            },
            {
              'name': 'Write',
              'description': 'Writing & Text',
              'icon': Icons.edit,
              'color': ColorManager.primary,
              'id': 2,
            },
            {
              'name': 'Read',
              'description': 'Reading & Comprehension',
              'icon': Icons.menu_book,
              'color': ColorManager.primary,
              'id': 3,
            },
          ];

          // Collect all selected skills from all languages
          final Set<String> allSelectedSkills = {};
          for (final skillsSet in state.skillsMap.values) {
            allSelectedSkills.addAll(skillsSet);
          }

          // Convert skill names to IDs
          for (final skillName in allSelectedSkills) {
            final skill = skills.firstWhere(
              (skill) => skill['name'] == skillName,
              orElse: () => {'id': 0},
            );
            if (skill['id'] != 0) {
              skillIds.add(skill['id'] as int);
            }
          }

          // Convert language names to IDs
          final List<int> languageIds = [];
          for (final languageName in state.selectedLanguages) {
            // Map language names to their IDs based on the database
            final languageId = LanguageMappingUtility.getLanguageId(
              languageName,
            );
            if (languageId != 0) {
              languageIds.add(languageId);
            }
          }

          // Add skills and languages to data
          data['skills'] = skillIds;
          data['languages'] = languageIds; // Pass language IDs instead of names

          // Ensure role is preserved
          if (!data.containsKey('role')) {
            data['role'] = 'interpreter';
          }

          Navigator.of(context).pushNamed(
            Routes.interpreterFieldScreen,
            arguments: {'type': 'skills', ...data},
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<LanguageFluencyBloc>();
        final currentLang =
            state.selectedLanguages.isNotEmpty
                ? state.selectedLanguages[state.currentLanguageIndex]
                : '';
        final progress =
            state.selectedLanguages.isNotEmpty
                ? (state.currentLanguageIndex + 1) /
                    state.selectedLanguages.length
                : 0.0;
        return Scaffold(
          backgroundColor: ColorManager.backgroundPrimary,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: ColorManager.primary2,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              'Language Proficiency',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ColorManager.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_ios,
                color: ColorManager.white,
                size: AppSize.s24,
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Progress Header
                Container(
                  padding: const EdgeInsets.all(AppSize.s20),
                  child: Column(
                    children: [
                      // Progress indicator
                      Container(
                        width: double.infinity,
                        height: AppSize.s6,
                        decoration: BoxDecoration(
                          color: ColorManager.greyLight,
                          borderRadius: BorderRadius.circular(AppSize.s3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ColorManager.primary,
                              borderRadius: BorderRadius.circular(AppSize.s3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSize.s16),
                      Text(
                        'Language ${state.currentLanguageIndex + 1} of ${state.selectedLanguages.length}',
                        style: TextStyle(
                          fontSize: AppSize.s14,
                          color: ColorManager.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSize.s8),
                      Text(
                        currentLang,
                        style: TextStyle(
                          fontSize: AppSize.s24,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSize.s20,
                        ),
                        child:
                            state.isSelectingFluency
                                ? _buildFluencySelection(
                                  context,
                                  currentLang,
                                  state,
                                )
                                : _buildSkillsSelection(
                                  context,
                                  currentLang,
                                  state,
                                ),
                      ),
                    ),
                  ),
                ),
                // Navigation Buttons
                Container(
                  padding: const EdgeInsets.all(AppSize.s20),
                  child: Row(
                    children: [
                      if (state.currentLanguageIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                () =>
                                    bloc.add(fluency_event.PreviousLanguage()),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSize.s16,
                              ),
                              side: BorderSide(color: ColorManager.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSize.s12,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: ColorManager.primary,
                                ),
                                const SizedBox(width: AppSize.s8),
                                Text(
                                  'Previous',
                                  style: TextStyle(color: ColorManager.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (state.currentLanguageIndex > 0)
                        const SizedBox(width: AppSize.s12),
                      Expanded(
                        child: CustomButton(
                          onTap:
                              state.skillsMap[currentLang]?.isNotEmpty == true
                                  ? () => bloc.add(fluency_event.NextLanguage())
                                  : () {},
                          color: ColorManager.primary,
                          borderRadius: BorderRadius.circular(AppSize.s12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                state.currentLanguageIndex ==
                                        state.selectedLanguages.length - 1
                                    ? 'Finish'
                                    : 'Next',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(width: AppSize.s8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFluencySelection(
    BuildContext context,
    String language,
    LanguageFluencyState state,
  ) {
    final fluencyLevels = [
      {
        'level': AppStrings.beginner,
        'description': 'Basic vocabulary and simple conversations',
        'icon': Icons.trending_up,
        'color': ColorManager.greyMedium,
        'examples': ['Hello, how are you?', 'I like this', 'Thank you'],
      },
      {
        'level': AppStrings.intermediate,
        'description': 'Can handle everyday situations and basic work tasks',
        'icon': Icons.trending_up,
        'color': ColorManager.greyMedium,
        'examples': [
          'I can discuss daily topics',
          'I work in this field',
          'I understand most conversations',
        ],
      },
      {
        'level': AppStrings.upperIntermediate,
        'description': 'Good command of language, can discuss complex topics',
        'icon': Icons.trending_up,
        'color': ColorManager.greyMedium,
        'examples': [
          'I can explain complex ideas',
          'I can debate topics',
          'I understand nuances',
        ],
      },
      {
        'level': 'Native Or Fluent',
        'description': 'Native speaker level or advanced fluency',
        'icon': Icons.star,
        'color': ColorManager.greyMedium,
        'examples': [
          'Native speaker level',
          'Perfect understanding',
          'Cultural fluency',
          'Advanced interpretation',
        ],
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact header
        Container(
          padding: const EdgeInsets.all(AppSize.s16),
          decoration: BoxDecoration(
            color: ColorManager.white,
            borderRadius: BorderRadius.circular(AppSize.s12),
            border: Border.all(color: ColorManager.greyLight),
            boxShadow: [
              BoxShadow(
                color: ColorManager.black.withValues(alpha: 0.05),
                blurRadius: AppSize.s8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSize.s8),
                decoration: BoxDecoration(
                  color: ColorManager.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s8),
                ),
                child: Icon(
                  Icons.speed,
                  color: ColorManager.primary,
                  size: AppSize.s18,
                ),
              ),
              const SizedBox(width: AppSize.s12),
              Expanded(
                child: Text(
                  'Select your fluency level in $language',
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSize.s20),
        // Fluency levels as compact cards
        Expanded(
          child: ListView.builder(
            itemCount: fluencyLevels.length,
            itemBuilder: (context, index) {
              final level = fluencyLevels[index];
              final isSelected = state.fluencyMap[language] == level['level'];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSize.s8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        () => context.read<LanguageFluencyBloc>().add(
                          fluency_event.SelectFluency(level['level'] as String),
                        ),
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSize.s16),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? ColorManager.primary.withValues(alpha: 0.05)
                                : ColorManager.white,
                        borderRadius: BorderRadius.circular(AppSize.s12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? ColorManager.primary
                                  : ColorManager.greyLight,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ColorManager.black.withValues(alpha: 0.03),
                            blurRadius: AppSize.s4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSize.s8),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? ColorManager.primary
                                      : ColorManager.greyLight,
                              borderRadius: BorderRadius.circular(AppSize.s8),
                            ),
                            child: Icon(
                              level['icon'] as IconData,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : ColorManager.textSecondary,
                              size: AppSize.s16,
                            ),
                          ),
                          const SizedBox(width: AppSize.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        level['level'] as String,
                                        style: TextStyle(
                                          fontSize: AppSize.s14,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isSelected
                                                  ? ColorManager.primary
                                                  : ColorManager.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSize.s2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ColorManager.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: AppSize.s12,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSize.s2),
                                Text(
                                  level['description'] as String,
                                  style: TextStyle(
                                    fontSize: AppSize.s12,
                                    color: ColorManager.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsSelection(
    BuildContext context,
    String language,
    LanguageFluencyState state,
  ) {
    final skills = <Map<String, dynamic>>[
      {
        'name': 'Speak',
        'description': 'Conversation & Speaking',
        'icon': Icons.record_voice_over,
        'color': ColorManager.primary,
        'id': 1,
      },
      {
        'name': 'Write',
        'description': 'Writing & Text',
        'icon': Icons.edit,
        'color': ColorManager.primary,
        'id': 2,
      },
      {
        'name': 'Read',
        'description': 'Reading & Comprehension',
        'icon': Icons.menu_book,
        'color': ColorManager.primary,
        'id': 3,
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Container(
          padding: const EdgeInsets.all(AppSize.s20),
          decoration: BoxDecoration(
            color: ColorManager.white,
            borderRadius: BorderRadius.circular(AppSize.s16),
            border: Border.all(color: ColorManager.greyLight),
            boxShadow: [
              BoxShadow(
                color: ColorManager.black.withValues(alpha: 0.05),
                blurRadius: AppSize.s8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSize.s12),
                decoration: BoxDecoration(
                  color: ColorManager.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: ColorManager.success,
                  size: AppSize.s20,
                ),
              ),
              const SizedBox(width: AppSize.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language Skills',
                      style: TextStyle(
                        fontSize: AppSize.s18,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSize.s4),
                    Text(
                      'Select what you can do in $language',
                      style: TextStyle(
                        fontSize: AppSize.s14,
                        color: ColorManager.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSize.s24),
        // Skills as cards
        Expanded(
          child: ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];
              final isSelected =
                  state.skillsMap[language]?.contains(skill['name']) == true;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSize.s12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        () => context.read<LanguageFluencyBloc>().add(
                          fluency_event.ToggleSkill(skill['name']),
                        ),
                    borderRadius: BorderRadius.circular(AppSize.s16),
                    child: Container(
                      padding: const EdgeInsets.all(AppSize.s20),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? ColorManager.primary.withValues(alpha: 0.05)
                                : ColorManager.white,
                        borderRadius: BorderRadius.circular(AppSize.s16),
                        border: Border.all(
                          color:
                              isSelected
                                  ? ColorManager.primary
                                  : ColorManager.greyLight,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ColorManager.black.withValues(alpha: 0.03),
                            blurRadius: AppSize.s6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSize.s12),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? ColorManager.primary
                                      : ColorManager.greyLight,
                              borderRadius: BorderRadius.circular(AppSize.s12),
                            ),
                            child: Icon(
                              skill['icon'] as IconData,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : ColorManager.textSecondary,
                              size: AppSize.s20,
                            ),
                          ),
                          const SizedBox(width: AppSize.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        skill['name'] as String,
                                        style: TextStyle(
                                          fontSize: AppSize.s16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isSelected
                                                  ? ColorManager.primary
                                                  : ColorManager.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSize.s4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ColorManager.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: AppSize.s16,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSize.s4),
                                Text(
                                  skill['description'] as String,
                                  style: TextStyle(
                                    fontSize: AppSize.s14,
                                    color: ColorManager.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
