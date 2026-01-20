import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        centerTitle: true,
        elevation: 0,
        title: Text(
          AppStrings.selectYourRole,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
            // Header Section

            // Content Section
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSize.s24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Join Organization Card (for doctors)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: AppSize.s20),
                          decoration: BoxDecoration(
                            color: ColorManager.backgroundCard,
                            borderRadius: BorderRadius.circular(AppSize.s20),
                            boxShadow: [
                              BoxShadow(
                                color: ColorManager.primary2.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: AppSize.s12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(Routes.doctorJoinOrganizationRoute);
                              },
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSize.s24),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSize.s16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorManager.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSize.s16,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.group_add,
                                        color: ColorManager.primary,
                                        size: AppSize.s30,
                                      ),
                                    ),
                                    const SizedBox(width: AppSize.s20),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Join Organization',
                                            style: TextStyle(
                                              fontSize: AppSize.s18,
                                              fontWeight: FontWeight.bold,
                                              color: ColorManager.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: AppSize.s8),
                                          Text(
                                            'Join as a doctor with an invite code',
                                            style: TextStyle(
                                              fontSize: AppSize.s14,
                                              color: ColorManager.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: ColorManager.primary,
                                      size: AppSize.s20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // I am an Interpreter Card
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: AppSize.s20),
                          decoration: BoxDecoration(
                            color: ColorManager.backgroundCard,
                            borderRadius: BorderRadius.circular(AppSize.s20),
                            boxShadow: [
                              BoxShadow(
                                color: ColorManager.primary2.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: AppSize.s12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Revert to original onboarding flow
                                Navigator.of(
                                  context,
                                ).pushNamed(Routes.interpreterTrackSelection);
                              },
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSize.s24),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSize.s16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorManager.primary2.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSize.s16,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.translate,
                                        color: ColorManager.primary2,
                                        size: AppSize.s30,
                                      ),
                                    ),
                                    const SizedBox(width: AppSize.s20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppStrings.iAmanInterpreter,
                                            style: TextStyle(
                                              fontSize: AppSize.s18,
                                              fontWeight: FontWeight.bold,
                                              color: ColorManager.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: AppSize.s8),
                                          Text(
                                            AppStrings
                                                .offerYourInterpretationServices,
                                            style: TextStyle(
                                              fontSize: AppSize.s14,
                                              color: ColorManager.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: ColorManager.primary2,
                                      size: AppSize.s20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Organization Card
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: AppSize.s20),
                          decoration: BoxDecoration(
                            color: ColorManager.backgroundCard,
                            borderRadius: BorderRadius.circular(AppSize.s20),
                            boxShadow: [
                              BoxShadow(
                                color: ColorManager.primary2.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: AppSize.s12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(Routes.organizationRegisterRoute);
                              },
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSize.s24),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSize.s16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSize.s16,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.business,
                                        color: Colors.orange,
                                        size: AppSize.s30,
                                      ),
                                    ),
                                    const SizedBox(width: AppSize.s20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Organization',
                                            style: TextStyle(
                                              fontSize: AppSize.s18,
                                              fontWeight: FontWeight.bold,
                                              color: ColorManager.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: AppSize.s8),
                                          Text(
                                            'Register your organization to manage doctors and calls',
                                            style: TextStyle(
                                              fontSize: AppSize.s14,
                                              color: ColorManager.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.orange,
                                      size: AppSize.s20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Info Section
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
