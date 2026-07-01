import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';

import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';

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
      'eyebrow': 'HEALTHCARE LANGUAGE ACCESS',
      'title': 'Trusted Communication for Better Care',
       'badge': 'HEALTHCARE FOCUSED',
      'image': ImageAssets.onbording1,
      'accent': ColorManager.primary,
       'bullets': [
        'Healthcare-Trained Interpreters',
        '50+ Languages & Dialects',
        'Trusted by Clinics & Healthcare Teams',
      ],
    },
    {
      'eyebrow': 'ON-DEMAND ACCESS',
      'title': 'Qualified Medical Interpreters',
      'badge': 'FAST & RELIABLE',
      'bullets': [
        'Language Support on Your Schedule',
        'Seamless Voice & Video calls',
        'Fast, Reliable Interpreter Connections',
      ],
      'image': ImageAssets.welcomehero,
      'accent': ColorManager.primary2,
    },
  
    {
      'eyebrow': 'TRUSTED COMMUNICATION',
      'title': 'Built for Quality, Security, and Trust',
      'badge': 'SECURE & COMPLIANT',
      'bullets': [
        'HIPAA-Compliant Workflows',
        'Interpreter Quality Assurance',
        'Secure & Confidential Communication',
      ],
      'image': ImageAssets.onbording3,
      'accent': ColorManager.primary2,
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
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Container(
          decoration: BoxDecoration(gradient: ColorManager.backgroundGradient),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -70,
                  child: _buildGlowCircle(
                    size: AppSize.s200,
                    color: ColorManager.primary2,
                  ),
                ),
                Positioned(
                  bottom: -110,
                  left: -60,
                  child: _buildGlowCircle(
                    size: AppSize.s220,
                    color: ColorManager.primary,
                  ),
                ),
                Positioned(
                  top: AppSize.s120,
                  left: -40,
                  child: _buildGlowCircle(
                    size: AppSize.s160,
                    color: ColorManager.primaryLight,
                  ),
                ),
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
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
                    _buildBottomSection(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(int index) {
    final data = _onboardingData[index];
    final Color accent = data['accent'] as Color;
    final List<String> bullets = List<String>.from(data['bullets'] as List);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSize.s20,
        AppSize.s10,
        AppSize.s20,
        AppSize.s10,
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSize.s24),
                boxShadow: [
                  BoxShadow(
                    color: ColorManager.primary2.withValues(alpha: 0.16),
                    blurRadius: AppSize.s24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSize.s24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        data['image'],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorManager.primary2Dark.withValues(alpha: 0.8),
                              ColorManager.primary2Dark.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSize.s6,
                      left: AppSize.s16,
                      child: _buildEyebrowTag(
                        data['eyebrow'],
                        accent,
                      ),
                    ),
                    Positioned(
                      top: AppSize.s40,
                      left: AppSize.s16,
                      right: AppSize.s16,
                      bottom: AppSize.s30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'],
                            style: TextStyle(
                              fontSize: AppSize.s20,
                              fontWeight: FontWeight.w700,
                              color: ColorManager.white,
                              height: 1.2,
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
          const SizedBox(height: AppSize.s16),
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSize.s20),
              decoration: BoxDecoration(
                color: ColorManager.backgroundCard,
                borderRadius: BorderRadius.circular(AppSize.s20),
                boxShadow: [
                  BoxShadow(
                    color: ColorManager.primary2.withValues(alpha: 0.08),
                    blurRadius: AppSize.s20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBadge(data['badge'], accent),
                  const SizedBox(height: AppSize.s12),
                  for (final bullet in bullets) _buildBullet(bullet, accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogo() {
    return Container(
      width: 45,
      height: 45,
     
      child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(ImageAssets.appIcon, fit: BoxFit.cover)),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSize.s20,
        AppSize.s8,
        AppSize.s12,
        AppSize.s8,
      ),
      child: Row(
        children: [
      _buildLogo(),
         const SizedBox(width: AppSize.s12),
          Text(
            AppStrings.interBridge,
            style: TextStyle(
              color: ColorManager.primary2,
              fontSize: AppSize.s18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _skipOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: ColorManager.primary2,
              backgroundColor: ColorManager.primary2.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.s20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSize.s12,
                vertical: AppSize.s6,
              ),
            ),
            child: const Text(
              AppStrings.skip,
              style: TextStyle(
                fontSize: AppSize.s14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSize.s20,
        AppSize.s10,
        AppSize.s20,
        AppSize.s24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentPage + 1} of ${_onboardingData.length}',
                style: TextStyle(
                  color: ColorManager.textSecondary,
                  fontSize: AppSize.s14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  _onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: AppSize.s4),
                    width: _currentPage == index ? AppSize.s24 : AppSize.s8,
                    height: AppSize.s8,
                    decoration: BoxDecoration(
                      color:
                          _currentPage == index
                              ? ColorManager.primary2
                              : ColorManager.greyMedium.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppSize.s4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s16),
          CustomButton(
            onTap: _nextPage,
            color: ColorManager.primary2,
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(AppSize.s14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentPage != _onboardingData.length - 1
                      ? AppStrings.next
                      : AppStrings.getStarted,
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.white,
                  ),
                ),
                const SizedBox(width: AppSize.s8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: ColorManager.white,
                  size: AppSize.s18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyebrowTag(String text, Color accent) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSize.s30),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSize.s10,
        ),
        decoration: BoxDecoration(
          color: ColorManager.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppSize.s20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: AppSize.s12,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSize.s12,
        vertical: AppSize.s6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSize.s20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            color: accent,
            size: AppSize.s16,
          ),
          const SizedBox(width: AppSize.s6),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: AppSize.s13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSize.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: AppSize.s2), // Adjusted alignment for the icon
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.green, // Made it green as requested
              size: AppSize.s20, // Adjusted size to look good next to the text
            ),
          ),
          const SizedBox(width: AppSize.s12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ColorManager.textPrimary,
                fontSize: AppSize.s15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}