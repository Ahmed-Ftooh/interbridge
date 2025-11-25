import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import '../view_model/selectFieldBloc/select_field_bloc.dart';
import '../view_model/selectFieldBloc/select_field_event.dart';
import '../view_model/selectFieldBloc/select_field_state.dart';

class InterpreterFieldScreen extends StatefulWidget {
  const InterpreterFieldScreen({super.key});

  @override
  State<InterpreterFieldScreen> createState() => _InterpreterFieldScreenState();
}

class _InterpreterFieldScreenState extends State<InterpreterFieldScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _customFieldController = TextEditingController();

  final List<Map<String, dynamic>> fieldData = [
    {
      'title': AppStrings.medicalInterpretation,
      'subtitle': AppStrings.healthcareAndMedicalTerminology,
      'icon': Icons.medical_services,
      'color': ColorManager.error,
      'id': 1,
    },
    {
      'title': AppStrings.legalInterpretation,
      'subtitle': AppStrings.legalProceedingsAndDocuments,
      'icon': Icons.gavel,
      'color': ColorManager.primary2,
      'id': 2,
    },
    {
      'title': AppStrings.educationalInterpretation,
      'subtitle': AppStrings.academicAndEducationalSettings,
      'icon': Icons.school,
      'color': ColorManager.success,
      'id': 3,
    },
    {
      'title': AppStrings.mentalHealth,
      'subtitle': AppStrings.psychologicalAndCounselingSessions,
      'icon': Icons.psychology,
      'color': ColorManager.darkPrimary,
      'id': 4,
    },
    {
      'title': AppStrings.documentation,
      'subtitle': AppStrings.officialDocumentsAndForms,
      'icon': Icons.description,
      'color': ColorManager.warning,
      'id': 5,
    },
    {
      'title': AppStrings.emergencyResponse,
      'subtitle': AppStrings.emergencyResponseSubtitle,
      'icon': Icons.business,
      'color': ColorManager.info,
      'id': 6,
    },
    {
      'title': AppStrings.socialServices,
      'subtitle': AppStrings.communityAndSocialWelfareServices,
      'icon': Icons.people,
      'color': ColorManager.primary,
      'id': 7,
    },
    {
      'title': AppStrings.noneOfTheAbove,
      'subtitle': '',
      'icon': Icons.not_interested,
      'color': ColorManager.greyDark,
      'id': 8,
    },
  ];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SelectFieldBloc>().add(
        InitializeFields(fieldData.map((e) => e['title'] as String).toList()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SelectFieldBloc, SelectFieldState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          CustomSnackBar.show(
            context,
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
        if (state.isSuccess) {
          // Get the data from the current route arguments
          final Map<String, dynamic> data =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>? ??
              {};

          // Convert field names to IDs
          final List<int> specializationIds = [];
          for (final fieldName in state.selectedFields) {
            final field = fieldData.firstWhere(
              (field) => field['title'] == fieldName,
              orElse: () => {'id': 0},
            );
            if (field['id'] != 0) {
              specializationIds.add(field['id'] as int);
            }
          }

          // Add the selected fields to the data
          data['specializations'] = specializationIds;

          // Ensure role is preserved
          if (!data.containsKey('role')) {
            data['role'] = 'interpreter';
          }

          Navigator.pushNamed(
            context,
            Routes.voiceCheckScreen,
            arguments: data,
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<SelectFieldBloc>();
        return Scaffold(
          backgroundColor: ColorManager.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: ColorManager.primary2,
            centerTitle: true,
            elevation: 0,
            title: Text(
              AppStrings.interpretersSpecialization,
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
              // Fields list
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppSize.s20,
                      left: AppSize.s16,
                      right: AppSize.s16,
                    ),
                    itemCount: fieldData.length,
                    itemBuilder: (context, index) {
                      final field = fieldData[index];
                      final isSelected = state.selectedFields.contains(
                        field['title'],
                      );
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: AppSize.s12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap:
                                () => bloc.add(
                                  ToggleField(field['title'] as String),
                                ),
                            borderRadius: BorderRadius.circular(AppSize.s16),
                            child: Container(
                              padding: const EdgeInsets.all(AppSize.s16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? field['color'].withValues(alpha: 0.08)
                                        : ColorManager.backgroundCard,
                                borderRadius: BorderRadius.circular(
                                  AppSize.s16,
                                ),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? field['color']
                                          : ColorManager.greyMedium.withValues(
                                            alpha: 0.3,
                                          ),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ColorManager.primary2.withValues(
                                      alpha: 0.08,
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
                                    padding: const EdgeInsets.all(AppSize.s12),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? field['color']
                                              : field['color'].withValues(
                                                alpha: 0.1,
                                              ),
                                      borderRadius: BorderRadius.circular(
                                        AppSize.s12,
                                      ),
                                    ),
                                    child: Icon(
                                      field['icon'],
                                      color:
                                          isSelected
                                              ? ColorManager.white
                                              : field['color'],
                                      size: AppSize.s24,
                                    ),
                                  ),
                                  const SizedBox(width: AppSize.s16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          field['title'],
                                          style: TextStyle(
                                            fontSize: AppSize.s16,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected
                                                    ? field['color']
                                                    : ColorManager.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSize.s4),
                                        Text(
                                          field['subtitle'],
                                          style: TextStyle(
                                            fontSize: AppSize.s14,
                                            color: ColorManager.textSecondary,
                                          ),
                                        ),
                                      ],
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
                                              ? field['color']
                                              : ColorManager.greyMedium,
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
              // Submit button
              Container(
                padding: const EdgeInsets.all(AppSize.s16),
                child: CustomButton(
                  onTap: () => bloc.add(SubmitFields()),
                  color: ColorManager.primary2,
                  borderRadius: BorderRadius.circular(AppSize.s16),
                  child: const Row(
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
    _customFieldController.dispose();
    super.dispose();
  }
}
