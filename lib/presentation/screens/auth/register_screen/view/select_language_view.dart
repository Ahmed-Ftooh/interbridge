import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/const/app_const.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import '../view_model/selectLanguageBloc/select_language_bloc.dart';
import '../view_model/selectLanguageBloc/select_language_event.dart';
import '../view_model/selectLanguageBloc/select_language_state.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    // Initialize BLoC state with languages from database
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLanguagesFromDatabase();
    });
  }

  Future<void> _loadLanguagesFromDatabase() async {
    try {
      final languages = await _supabaseService.getLanguages();
      final languageNames = languages.map((lang) => lang.name).toList();
      if (mounted) {
        context.read<SelectLanguageBloc>().add(
          InitializeLanguages(languageNames),
        );
      }
    } catch (e) {
      // Fallback to hardcoded list if database fetch fails
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
    // Accept the data map from arguments
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
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
        // Filter based on search
        final filteredLanguages =
            state.allLanguages.where((lang) {
              return lang.toLowerCase().contains(
                state.searchQuery.toLowerCase(),
              );
            }).toList();
        return Scaffold(
          backgroundColor: ColorManager.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: ColorManager.primary2,
            centerTitle: true,
            elevation: 0,
            title: Text(
              AppStrings.selectLanguage,
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
          body: Column(
            children: [
              // Search bar
              Container(
                margin: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  color: ColorManager.backgroundCard,
                  borderRadius: BorderRadius.circular(AppSize.s16),
                  boxShadow: [
                    BoxShadow(
                      color: ColorManager.primary2.withValues(alpha: 0.08),
                      blurRadius: AppSize.s8,
                      offset: const Offset(AppSize.s0, AppSize.s2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppStrings.searchLanguages,
                    prefixIcon: Icon(Icons.search, color: ColorManager.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSize.s16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: ColorManager.backgroundCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s16,
                      vertical: AppSize.s12,
                    ),
                  ),
                  onChanged: (value) => bloc.add(SearchLanguageChanged(value)),
                ),
              ),
              // Language list
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s16,
                    ),
                    itemCount: filteredLanguages.length,
                    itemBuilder: (_, index) {
                      // Sort languages: English always first, others in original order
                      final sortedLanguages = [
                        ...filteredLanguages.where((l) => l == 'English'),
                        ...filteredLanguages.where((l) => l != 'English'),
                      ];
                      final lang = sortedLanguages[index];
                      final isSelected = state.selectedLanguages[lang] ?? false;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: AppSize.s12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => bloc.add(ToggleLanguage(lang)),
                            borderRadius: BorderRadius.circular(AppSize.s16),
                            child: Container(
                              padding: const EdgeInsets.all(AppSize.s16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? ColorManager.primary.withValues(
                                          alpha: 0.08,
                                        )
                                        : ColorManager.backgroundCard,
                                borderRadius: BorderRadius.circular(
                                  AppSize.s16,
                                ),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? ColorManager.primary
                                          : ColorManager.greyMedium.withValues(
                                            alpha: 0.3,
                                          ),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ColorManager.black.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: AppSize.s8,
                                    offset: const Offset(
                                      AppSize.s0,
                                      AppSize.s2,
                                    ),
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
                                              : ColorManager.grey,
                                      borderRadius: BorderRadius.circular(
                                        AppSize.s8,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.language,
                                      color:
                                          isSelected
                                              ? ColorManager.white
                                              : ColorManager.grey,
                                      size: AppSize.s20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSize.s12),
                                  Expanded(
                                    child: Text(
                                      lang,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isSelected
                                                ? ColorManager.primary
                                                : ColorManager.textPrimary,
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color:
                                          isSelected
                                              ? ColorManager.primary
                                              : ColorManager.grey,
                                      size: AppSize.s24,
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
              ),
              // Continue button
              Container(
                padding: const EdgeInsets.all(AppSize.s16),
                child: CustomButton(
                  onTap: () {
                    final count =
                        state.selectedLanguages.values.where((v) => v).length;
                    if (count >= 2 && !_isLoading) {
                      _saveAndContinue(state, data);
                    } else if (count < 2) {
                      CustomSnackBar.show(
                        context,
                        message: AppStrings.pleaseSelectAtLeastTwoLanguages,
                        type: SnackBarType.error,
                      );
                    }
                  },
                  color:
                      (state.selectedLanguages.values.where((v) => v).length >=
                                  2 &&
                              !_isLoading)
                          ? ColorManager.primary2
                          : ColorManager.grey,
                  borderRadius: BorderRadius.circular(AppSize.s16),
                  child:
                      _isLoading
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: ColorManager.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_forward, size: AppSize.s20),
                              SizedBox(width: AppSize.s8),
                              Text(
                                AppStrings.continueText,
                                style: TextStyle(
                                  fontSize: AppSize.s16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
