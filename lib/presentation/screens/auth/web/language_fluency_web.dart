import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/auth/web/interpreter_onboarding_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_event.dart'
    as fluency_event;
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_state.dart';

/// Professional web language fluency & skills screen for interpreter onboarding
class LanguageFluencyWebScreen extends StatefulWidget {
  const LanguageFluencyWebScreen({super.key});

  @override
  State<LanguageFluencyWebScreen> createState() =>
      _LanguageFluencyWebScreenState();
}

class _LanguageFluencyWebScreenState extends State<LanguageFluencyWebScreen> {
  @override
void initState() {
  super.initState();
  
  // Add this block to catch browser refreshes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) {
      // The user refreshed the page and lost their session arguments.
      // Send them to the dashboard gate, which will re-fetch their progress
      // from Supabase and route them back here with the correct args!
      Navigator.of(context).pushReplacementNamed(Routes.interpreterPortalDashboardRoute);
    }
  });
}
  bool _initialized = false;
  bool _isSaving = false;

  static const _fluencyLevels = [
    {
      'level': 'Beginner',
      'description': 'Basic vocabulary and simple conversations',
      'icon': Icons.signal_cellular_alt_1_bar,
    },
    {
      'level': 'Intermediate',
      'description': 'Handle everyday situations and work tasks',
      'icon': Icons.signal_cellular_alt_2_bar,
    },
    {
      'level': 'Upper Intermediate',
      'description': 'Discuss complex topics with good command',
      'icon': Icons.signal_cellular_alt,
    },
    {
      'level': 'Native Or Fluent',
      'description': 'Native speaker or advanced fluency',
      'icon': Icons.star_rounded,
    },
  ];

  static const _skills = [
    {
      'name': 'Speak',
      'description': 'Conversation & Speaking',
      'icon': Icons.record_voice_over,
      'id': 1,
    },
    {
      'name': 'Write',
      'description': 'Writing & Text',
      'icon': Icons.edit_note,
      'id': 2,
    },
    {
      'name': 'Read',
      'description': 'Reading & Comprehension',
      'icon': Icons.menu_book,
      'id': 3,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final fullScreenResume = data['authContinuationFullScreen'] == true;

    final languagesData = data['languages'];
    List<String> selectedLanguages = [];
    if (languagesData is List && languagesData.isNotEmpty) {
      if (languagesData.first is int) {
        selectedLanguages = LanguageMappingUtility.convertIdsToNames(
          languagesData.cast<int>(),
        );
      } else {
        selectedLanguages = languagesData.map((e) => e.toString()).toList();
      }
    }

    final bloc = context.read<LanguageFluencyBloc>();
    if (!_initialized && selectedLanguages.isNotEmpty) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bloc.add(fluency_event.InitializeLanguages(selectedLanguages));
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
        if (state.isComplete && !_isSaving) {
          _saveAndComplete(state, data);
        }
      },
      builder: (context, state) {
        final currentLang =
            state.selectedLanguages.isNotEmpty &&
                    state.currentLanguageIndex < state.selectedLanguages.length
                ? state.selectedLanguages[state.currentLanguageIndex]
                : '';
        final langCount = state.selectedLanguages.length;
        final langIndex = state.currentLanguageIndex;

        return InterpreterOnboardingWrapper(
         currentStepIndex: 1,
         stepTitle: "Select your Fluency in $currentLang",
         stepSubtitle: "Indicate your proficiency level for each selected language.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              _buildStepIndicator(3, 9),
              const SizedBox(height: 16),

              // Language progress
              if (langCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text(
                        'Language ${langIndex + 1} of $langCount',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (langIndex + 1) / langCount,
                            minHeight: 4,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Content
              if (state.isSelectingFluency)
                _buildFluencyContent(currentLang, state)
              else
                _buildSkillsContent(currentLang, state),

              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                children: [
                  if (langIndex > 0) ...[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed:
                              () => bloc.add(fluency_event.PreviousLanguage()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Previous'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            state.skillsMap[currentLang]?.isNotEmpty == true
                                ? () => bloc.add(fluency_event.NextLanguage())
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                        ),
                        child: Text(
                          langIndex == langCount - 1 ? 'Continue' : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: const Text('Back'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFluencyContent(String language, LanguageFluencyState state) {
    return Column(
      children:
          _fluencyLevels.map((level) {
            final isSelected = state.fluencyMap[language] == level['level'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      () => context.read<LanguageFluencyBloc>().add(
                        fluency_event.SelectFluency(level['level'] as String),
                      ),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFFF0F7FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          level['icon'] as IconData,
                          size: 20,
                          color:
                              isSelected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                level['level'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected
                                          ? const Color(0xFF1E40AF)
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                level['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color:
                              isSelected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSkillsContent(String language, LanguageFluencyState state) {
    return Column(
      children:
          _skills.map((skill) {
            final isSelected =
                state.skillsMap[language]?.contains(skill['name']) == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      () => context.read<LanguageFluencyBloc>().add(
                        fluency_event.ToggleSkill(skill['name'] as String),
                      ),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFFF0F7FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            skill['icon'] as IconData,
                            size: 20,
                            color:
                                isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skill['name'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected
                                          ? const Color(0xFF1E40AF)
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                skill['description'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: isSelected,
                          onChanged:
                              (_) => context.read<LanguageFluencyBloc>().add(
                                fluency_event.ToggleSkill(
                                  skill['name'] as String,
                                ),
                              ),
                          activeColor: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCurrent
                      ? const Color(0xFF3B82F6)
                      : isActive
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  int _getFluencyId(String level) {
    switch (level) {
      case 'Beginner':
        return 1;
      case 'Intermediate':
        return 3;
      case 'Upper Intermediate':
        return 4;
      case 'Native Or Fluent':
        return 7;
      default:
        return 1;
    }
  }

  Future<void> _saveAndComplete(
    LanguageFluencyState state,
    Map<String, dynamic> data,
  ) async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        CustomSnackBar.show(
          context,
          message: 'Error: You must be logged in',
          type: SnackBarType.error,
        );
        return;
      }

      final List<Map<String, dynamic>> skillsInserts = [];

      // Clear skills to prevent duplicates, but we update languages
      await Supabase.instance.client
          .from('interpreter_language_skills')
          .delete()
          .eq('user_id', userId);

      for (final languageName in state.selectedLanguages) {
        final languageId = LanguageMappingUtility.getLanguageId(languageName);
        if (languageId == 0) continue;

        // Update fluency level
        final fluencyName = state.fluencyMap[languageName];
        if (fluencyName != null) {
          final fluencyId = _getFluencyId(fluencyName);
          await Supabase.instance.client
              .from('interpreter_languages')
              .update({'fluency_id': fluencyId})
              .eq('user_id', userId)
              .eq('language_id', languageId);
        }

        // Gather skills
        if (state.skillsMap.containsKey(languageName)) {
          for (final skillName in state.skillsMap[languageName]!) {
            final skill = _skills.firstWhere(
              (s) => s['name'] == skillName,
              orElse: () => {'id': 0},
            );
            final skillId = skill['id'] as int;
            if (skillId != 0) {
              skillsInserts.add({
                'user_id': userId,
                'language_id': languageId,
                'skill_id': skillId,
              });
            }
          }
        }
      }

      if (skillsInserts.isNotEmpty) {
        await Supabase.instance.client
            .from('interpreter_language_skills')
            .insert(skillsInserts);
      }

      await Supabase.instance.client
          .from('interpreter_details')
          .update({'onboarding_status': 'fluency_selected'})
          .eq('user_id', userId);

      if (mounted) {
        final originalArgs =
            ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>? ??
            {};
        final nextArgs = {
          ...originalArgs,
          ...data,
        }; // Kept for backwards compatibility
        Navigator.of(
          context,
        ).pushNamed(Routes.interpreterFieldScreen, arguments: nextArgs);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to save details: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
