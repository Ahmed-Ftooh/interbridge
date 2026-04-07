import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Professional web specialization selection screen for interpreter onboarding
class SelectFieldWebScreen extends StatefulWidget {
  const SelectFieldWebScreen({super.key});

  @override
  State<SelectFieldWebScreen> createState() => _SelectFieldWebScreenState();
}

class _SelectFieldWebScreenState extends State<SelectFieldWebScreen> {
  bool _isSaving = false;

  final List<Map<String, dynamic>> fieldData = [
    {
      'title': AppStrings.medicalInterpretation,
      'subtitle': AppStrings.healthcareAndMedicalTerminology,
      'icon': Icons.local_hospital_rounded,
      'id': 1,
    },
    {
      'title': AppStrings.socialServices,
      'subtitle': AppStrings.communityAndSocialWelfareServices,
      'icon': Icons.people_rounded,
      'id': 2,
    },
    {
      'title': AppStrings.documentation,
      'subtitle': AppStrings.officialDocumentsAndForms,
      'icon': Icons.description_rounded,
      'id': 3,
    },
    {
      'title': AppStrings.emergencyResponse,
      'subtitle': AppStrings.emergencyResponseSubtitle,
      'icon': Icons.emergency_rounded,
      'id': 4,
    },
  ];

  Future<void> _saveAndContinue(
    SelectFieldState state,
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

      final List<int> specializationIds = [];
      for (final fieldName in state.selectedFields) {
        final field = fieldData.firstWhere(
          (f) => f['title'] == fieldName,
          orElse: () => {'id': 0},
        );
        if (field['id'] != 0) {
          specializationIds.add(field['id'] as int);
        }
      }

      await Supabase.instance.client
          .from('interpreter_specializations')
          .delete()
          .eq('user_id', userId);

      if (specializationIds.isNotEmpty) {
        final inserts =
            specializationIds
                .map((id) => {'user_id': userId, 'specialization_id': id})
                .toList();
        await Supabase.instance.client
            .from('interpreter_specializations')
            .insert(inserts);
      }

      await Supabase.instance.client
          .from('interpreter_details')
          .update({'onboarding_status': 'specialization_selected'})
          .eq('user_id', userId);

      if (mounted) {
        final originalArgs =
            ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>? ??
            {};
        final nextArgs = {...originalArgs, ...data};
        if (!nextArgs.containsKey('role')) nextArgs['role'] = 'interpreter';

        Navigator.pushNamed(
          context,
          Routes.voiceSampleRoute,
          arguments: nextArgs,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to save specializations: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SelectFieldBloc>().add(
        InitializeFields(fieldData.map((e) => e['title'] as String).toList()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final fullScreenResume = data['authContinuationFullScreen'] == true;

    return BlocConsumer<SelectFieldBloc, SelectFieldState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          CustomSnackBar.show(
            context,
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
        if (state.isSuccess && !_isSaving) {
          _saveAndContinue(state, data);
        }
      },
      builder: (context, state) {
        final bloc = context.read<SelectFieldBloc>();

        return AuthWebWrapper(
          fullScreen: fullScreenResume,
          title: 'Specializations',
          subtitle: 'Select the areas you specialize in',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(4, 9),
              const SizedBox(height: 24),

              ...fieldData.map((field) {
                final isSelected = state.selectedFields.contains(
                  field['title'],
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap:
                          () => bloc.add(ToggleField(field['title'] as String)),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFFF0F7FF)
                                  : Colors.white,
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                field['icon'] as IconData,
                                size: 22,
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
                                    field['title'] as String,
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
                                    field['subtitle'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: isSelected,
                              onChanged:
                                  (_) => bloc.add(
                                    ToggleField(field['title'] as String),
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
              }),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      state.selectedFields.isNotEmpty
                          ? () => bloc.add(SubmitFields())
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
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
}
