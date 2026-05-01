import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/const/app_const.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_state.dart';

/// Professional web language selection screen for interpreter onboarding
class LanguageSelectionWebScreen extends StatefulWidget {
  const LanguageSelectionWebScreen({super.key});

  @override
  State<LanguageSelectionWebScreen> createState() =>
      _LanguageSelectionWebScreenState();
}

class _LanguageSelectionWebScreenState
    extends State<LanguageSelectionWebScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLanguages();


  
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

    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    try {
      final languages = await _supabaseService.getLanguages();
      final languageNames = languages.map((lang) => lang.name).toList();
      if (mounted) {
        context.read<SelectLanguageBloc>().add(
          InitializeLanguages(languageNames),
        );
      }
    } catch (e) {
      if (mounted) {
        context.read<SelectLanguageBloc>().add(
          InitializeLanguages(AppConstant.allLanguages),
        );
      }
    }
  }

  Future<void> _saveAndContinue(
    SelectLanguageState state,
    Map<String, dynamic> data,
  ) async {
    final selectedNames =
        state.selectedLanguages.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();

    if (selectedNames.length < 2) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        CustomSnackBar.show(
          context,
          message: 'Error: You must be logged in to continue.',
          type: SnackBarType.error,
        );
        return;
      }

      final languageIds = LanguageMappingUtility.convertNamesToIds(
        selectedNames,
      );

      // Clear old selections
      await Supabase.instance.client
          .from('interpreter_languages')
          .delete()
          .eq('user_id', userId);

      // Insert new selections
      if (languageIds.isNotEmpty) {
        final insertData =
            languageIds
                .map((id) => {'user_id': userId, 'language_id': id})
                .toList();

        await Supabase.instance.client
            .from('interpreter_languages')
            .insert(insertData);
      }

      // Update onboarding status
      await Supabase.instance.client
          .from('interpreter_details')
          .update({'onboarding_status': 'languages_selected'})
          .eq('user_id', userId);

      data['languages'] = selectedNames;
      if (!data.containsKey('role')) {
        data['role'] = 'interpreter';
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamed(Routes.languageFluencyScreen, arguments: data);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to save: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final fullScreenResume = data['authContinuationFullScreen'] == true;

    return BlocConsumer<SelectLanguageBloc, SelectLanguageState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.isFailure) {
          CustomSnackBar.show(
            context,
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<SelectLanguageBloc>();
        final filteredLanguages =
            state.allLanguages.where((lang) {
              return lang.toLowerCase().contains(
                state.searchQuery.toLowerCase(),
              );
            }).toList();

        // Sort: English first
        final sortedLanguages = [
          ...filteredLanguages.where((l) => l == 'English'),
          ...filteredLanguages.where((l) => l != 'English'),
        ];

        final selectedCount =
            state.selectedLanguages.values.where((v) => v).length;

        return AuthWebWrapper(
          fullScreen: fullScreenResume,
          title: 'Select your languages',
          subtitle: 'Choose at least 2 languages you can interpret',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              _buildStepIndicator(2, 9),
              const SizedBox(height: 24),

              // Search
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search languages...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) => bloc.add(SearchLanguageChanged(value)),
                ),
              ),
              const SizedBox(height: 8),

              // Selected count badge
              if (selectedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$selectedCount language${selectedCount > 1 ? 's' : ''} selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          selectedCount >= 2
                              ? const Color(0xFF059669)
                              : const Color(0xFF64748B),
                    ),
                  ),
                ),

              // Language list (constrained height for scrolling)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child:
                    state.allLanguages.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: sortedLanguages.length,
                          itemBuilder: (_, index) {
                            final lang = sortedLanguages[index];
                            final isSelected =
                                state.selectedLanguages[lang] ?? false;
                            return _buildLanguageItem(
                              lang: lang,
                              isSelected: isSelected,
                              onTap: () => bloc.add(ToggleLanguage(lang)),
                            );
                          },
                        ),
              ),
              const SizedBox(height: 24),

              // Continue
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (selectedCount >= 2 && !_isLoading)
                          ? () => _saveAndContinue(state, data)
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
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
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

  Widget _buildLanguageItem({
    required String lang,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
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
                  Icons.translate,
                  size: 18,
                  color:
                      isSelected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isSelected
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFF374151),
                    ),
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
  }
}
