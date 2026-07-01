import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/const/app_const.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';
import 'package:interbridge/presentation/screens/auth/web/interpreter_onboarding_wrapper.dart'; // <--- Import the new wrapper
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_state.dart';

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
  String? _hoveredLanguage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == null) {
        Navigator.of(context).pushReplacementNamed(Routes.interpreterPortalDashboardRoute);
        return;
      }
      _loadLanguages();
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
        context.read<SelectLanguageBloc>().add(InitializeLanguages(languageNames));
      }
    } catch (e) {
      if (mounted) {
        context.read<SelectLanguageBloc>().add(InitializeLanguages(AppConstant.allLanguages));
      }
    }
  }

  Future<void> _saveAndContinue(SelectLanguageState state, Map<String, dynamic> data) async {
    final selectedNames = state.selectedLanguages.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedNames.length < 2) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        CustomSnackBar.show(context, message: 'Error: You must be logged in to continue.', type: SnackBarType.error);
        return;
      }

      final languageIds = LanguageMappingUtility.convertNamesToIds(selectedNames);

      await Supabase.instance.client.from('interpreter_languages').delete().eq('user_id', userId);

      if (languageIds.isNotEmpty) {
        final insertData = languageIds.map((id) => {'user_id': userId, 'language_id': id}).toList();
        await Supabase.instance.client.from('interpreter_languages').insert(insertData);
      }

      await Supabase.instance.client
          .from('interpreter_details')
          .update({'onboarding_status': 'languages_selected'})
          .eq('user_id', userId);

      data['languages'] = selectedNames;
      if (!data.containsKey('role')) data['role'] = 'interpreter';

      if (mounted) {
        Navigator.of(context).pushNamed(Routes.languageFluencyScreen, arguments: data);
      }
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: 'Failed to save: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

    return BlocConsumer<SelectLanguageBloc, SelectLanguageState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.isFailure) {
          CustomSnackBar.show(context, message: state.errorMessage!, type: SnackBarType.error);
        }
      },
      builder: (context, state) {
        final bloc = context.read<SelectLanguageBloc>();
        final filteredLanguages = state.allLanguages.where((lang) {
          return lang.toLowerCase().contains(state.searchQuery.toLowerCase());
        }).toList();

        final sortedLanguages = [
          ...filteredLanguages.where((l) => l == 'English'),
          ...filteredLanguages.where((l) => l != 'English'),
        ];

        final selectedCount = state.selectedLanguages.values.where((v) => v).length;

        // Use the new Split-Screen Wrapper!
        return InterpreterOnboardingWrapper(
          currentStepIndex: 0, // Languages is Step 1 (Index 0)
          stepTitle: 'Which languages do you interpret?',
          stepSubtitle: 'Please select at least two languages to proceed. You will indicate your fluency level on the next screen.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              // 1. Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'Search languages...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: (value) => bloc.add(SearchLanguageChanged(value)),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Selection Counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Languages',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$selectedCount selected',
                      key: ValueKey(selectedCount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedCount >= 2 ? AuthWebPalette.primary : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Scrollable List
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: state.allLanguages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AuthWebPalette.primary, strokeWidth: 2),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: sortedLanguages.length,
                          itemBuilder: (_, index) {
                            final lang = sortedLanguages[index];
                            final isSelected = state.selectedLanguages[lang] ?? false;
                            return _buildPremiumLanguageItem(
                              lang: lang,
                              isSelected: isSelected,
                              onTap: () => bloc.add(ToggleLanguage(lang)),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 32),

              // 4. Continue Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (selectedCount >= 2 && !_isLoading) ? () => _saveAndContinue(state, data) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthWebPalette.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Continue to Fluency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumLanguageItem({required String lang, required bool isSelected, required VoidCallback onTap}) {
    final isHovered = _hoveredLanguage == lang;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredLanguage = lang),
      onExit: (_) => setState(() => _hoveredLanguage = null),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected 
                ? AuthWebPalette.primary.withValues(alpha: 0.05) 
                : isHovered 
                    ? const Color(0xFFF8FAFC) 
                    : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected 
                  ? AuthWebPalette.primary 
                  : isHovered 
                      ? const Color(0xFFCBD5E1) 
                      : Colors.transparent,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.language_rounded,
                size: 20,
                color: isSelected ? AuthWebPalette.primary : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  lang,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AuthWebPalette.primary : const Color(0xFF334155),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: AuthWebPalette.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}