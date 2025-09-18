import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';

import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': AppStrings.onbordingTitle1,
      'subtitle': AppStrings.onbordingSubtit1e1,
      'image': ImageAssets.onbording1,
    },
    {
      'title': AppStrings.onbordingTitle2,
      'subtitle': AppStrings.onbordingSubtit1e2,
      'image': ImageAssets.onbording2,
    },
    {
      'title': AppStrings.onbordingTitle3,
      'subtitle': AppStrings.onbordingSubtit1e3,
      'image': ImageAssets.onbording3,
    },
  ];
  final AppPreferences _appPreferences = instance<AppPreferences>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _appPreferences.setOnbordingViewed();
      Navigator.pushReplacementNamed(context, Routes.loginRoute);
    }
  }

  void _skipOnboarding() {
    Navigator.pushReplacementNamed(context, Routes.loginRoute);
    _appPreferences.setOnbordingViewed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.backgroundPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: ColorManager.backgroundPrimary,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSize.s16),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    AppStrings.skip,
                    style: TextStyle(
                      color: ColorManager.primary2,
                      fontSize: AppSize.s16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(index);
                },
              ),
            ),

            // Bottom Section
            Container(
              padding: const EdgeInsets.all(AppSize.s24),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSize.s4,
                        ),
                        width: _currentPage == index ? AppSize.s24 : AppSize.s8,
                        height: AppSize.s8,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index
                                  ? ColorManager.primary2
                                  : ColorManager.greyMedium.withValues(
                                    alpha: 0.3,
                                  ),
                          borderRadius: BorderRadius.circular(AppSize.s4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSize.s32),

                  // Get Started Button
                  CustomButton(
                    onTap: _nextPage,
                    color: ColorManager.primary2,
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rocket_launch,
                          color: ColorManager.white,
                          size: AppSize.s20,
                        ),
                        const SizedBox(width: AppSize.s8),
                        Text(
                          _currentPage != 2
                              ? AppStrings.next
                              : AppStrings.getStarted,
                          style: TextStyle(
                            fontSize: AppSize.s16,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(int index) {
    final data = _onboardingData[index];

    return Padding(
      padding: const EdgeInsets.all(AppSize.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSize.s20),
                boxShadow: [
                  BoxShadow(
                    color: ColorManager.primary2.withValues(alpha: 0.1),
                    blurRadius: AppSize.s20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSize.s20),
                child: Image.asset(data['image'], fit: BoxFit.cover),
              ),
            ),
          ),

          const SizedBox(height: AppSize.s40),

          // Content
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  data['title'],
                  style: TextStyle(
                    fontSize: AppSize.s24,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSize.s16),
                Text(
                  data['subtitle'],
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    color: ColorManager.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
