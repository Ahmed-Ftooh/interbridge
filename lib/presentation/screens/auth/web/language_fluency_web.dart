import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  bool _initialized = false;

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
        if (state.isComplete) {
          _onComplete(state, data);
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

        return AuthWebWrapper(
          title:
              state.isSelectingFluency
                  ? 'Fluency in $currentLang'
                  : 'Skills in $currentLang',
          subtitle:
              state.isSelectingFluency
                  ? 'How well do you know this language?'
                  : 'Select what you can do in this language',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              _buildStepIndicator(3, 6),
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

  void _onComplete(LanguageFluencyState state, Map<String, dynamic> data) {
    final Map<String, String?> fluencyWithIds = {};
    for (final languageName in state.selectedLanguages) {
      final languageId = LanguageMappingUtility.getLanguageId(languageName);
      if (languageId != 0 && state.fluencyMap.containsKey(languageName)) {
        fluencyWithIds[languageId.toString()] = state.fluencyMap[languageName];
      }
    }
    data['fluency'] = fluencyWithIds;

    final List<int> skillIds = [];
    final Set<String> allSelectedSkills = {};
    for (final skillsSet in state.skillsMap.values) {
      allSelectedSkills.addAll(skillsSet);
    }
    for (final skillName in allSelectedSkills) {
      final skill = _skills.firstWhere(
        (s) => s['name'] == skillName,
        orElse: () => {'id': 0},
      );
      if (skill['id'] != 0) {
        skillIds.add(skill['id'] as int);
      }
    }

    final List<int> languageIds = [];
    for (final languageName in state.selectedLanguages) {
      final languageId = LanguageMappingUtility.getLanguageId(languageName);
      if (languageId != 0) {
        languageIds.add(languageId);
      }
    }

    data['skills'] = skillIds;
    data['languages'] = languageIds;

    final originalArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final nextArgs = {...originalArgs, ...data};
    Navigator.of(
      context,
    ).pushNamed(Routes.interpreterFieldScreen, arguments: nextArgs);
  }
}
