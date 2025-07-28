import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/simple_fade_animation.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';

class InterpreterHomeView extends StatefulWidget {
  const InterpreterHomeView({super.key});

  @override
  State<InterpreterHomeView> createState() => _InterpreterHomeViewState();
}

class _InterpreterHomeViewState extends State<InterpreterHomeView> {
  bool isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                SimpleFadeAnimation(
                  child: Container(
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: ColorManager.primary2,
                      borderRadius: BorderRadius.circular(AppSize.s12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: AppSize.s24,
                          backgroundColor: ColorManager.white,
                          child: Icon(
                            Icons.person,
                            color: ColorManager.primary2,
                            size: AppSize.s24,
                          ),
                        ),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: TextStyle(
                                  color: ColorManager.white,
                                  fontSize: AppSize.s18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSize.s4),
                              Row(
                                children: [
                                  Container(
                                    width: AppSize.s8,
                                    height: AppSize.s8,
                                    decoration: BoxDecoration(
                                      color:
                                          isOnline ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSize.s4),
                                  Text(
                                    isOnline
                                        ? AppStrings.online
                                        : AppStrings.offline,
                                    style: TextStyle(
                                      color: ColorManager.white,
                                      fontSize: AppSize.s12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isOnline,
                          onChanged: (value) {
                            setState(() {
                              isOnline = value;
                            });
                          },
                          activeColor: ColorManager.white,
                          activeTrackColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSize.s24),

                // Earnings Section
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: ColorManager.backgroundCard,
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: ColorManager.greyMedium.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.earnings,
                              style: TextStyle(
                                fontSize: AppSize.s16,
                                fontWeight: FontWeight.bold,
                                color: ColorManager.textPrimary,
                              ),
                            ),
                            Text(
                              AppStrings.thisMonth,
                              style: TextStyle(
                                fontSize: AppSize.s12,
                                color: ColorManager.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSize.s12),
                        Row(
                          children: [
                            Text(
                              AppStrings.currency,
                              style: TextStyle(
                                fontSize: AppSize.s24,
                                fontWeight: FontWeight.bold,
                                color: ColorManager.primary2,
                              ),
                            ),
                            Text(
                              '1,250',
                              style: TextStyle(
                                fontSize: AppSize.s24,
                                fontWeight: FontWeight.bold,
                                color: ColorManager.primary2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSize.s8),
                        Text(
                          '${AppStrings.currency}2,500 ${AppStrings.totalEarnings}',
                          style: TextStyle(
                            fontSize: AppSize.s12,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSize.s24),

                // Quick Actions
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    AppStrings.quickActions,
                    style: TextStyle(
                      fontSize: AppSize.s18,
                      fontWeight: FontWeight.bold,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSize.s16),
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.phone,
                          title: AppStrings.voiceCall,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: AppSize.s12),
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.videocam,
                          title: AppStrings.videoCall,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSize.s12),
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 600),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.chat,
                          title: AppStrings.textChat,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: AppSize.s12),
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.description,
                          title: AppStrings.documentTranslation,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSize.s24),

                // Available Jobs
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 700),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.availableJobs,
                        style: TextStyle(
                          fontSize: AppSize.s18,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: ColorManager.primary2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSize.s16),
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 800),
                  child: _buildJobCard(
                    title: 'Medical Interpretation',
                    description: 'Urgent medical consultation needed',
                    language: 'English - Arabic',
                    rate: '25',
                    duration: '1 hour',
                    isUrgent: true,
                  ),
                ),
                const SizedBox(height: AppSize.s12),
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 900),
                  child: _buildJobCard(
                    title: 'Legal Document Translation',
                    description: 'Contract translation required',
                    language: 'English - Spanish',
                    rate: '30',
                    duration: '2 hours',
                    isUrgent: false,
                  ),
                ),
                const SizedBox(height: AppSize.s24),

                // Recent Activity
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 1000),
                  child: Text(
                    AppStrings.recentActivity,
                    style: TextStyle(
                      fontSize: AppSize.s18,
                      fontWeight: FontWeight.bold,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSize.s16),
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 1100),
                  child: _buildActivityCard(
                    title: 'Session Completed',
                    description: 'Medical consultation - 45 minutes',
                    time: '2 hours ago',
                    amount: '18.75',
                  ),
                ),
                const SizedBox(height: AppSize.s12),
                SimpleFadeAnimation(
                  delay: const Duration(milliseconds: 1200),
                  child: _buildActivityCard(
                    title: 'New Review',
                    description: '5-star rating received',
                    time: '1 day ago',
                    amount: null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(
          color: ColorManager.greyMedium.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSize.s12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSize.s8),
            ),
            child: Icon(icon, color: color, size: AppSize.s24),
          ),
          const SizedBox(height: AppSize.s8),
          Text(
            title,
            style: TextStyle(
              fontSize: AppSize.s12,
              fontWeight: FontWeight.w600,
              color: ColorManager.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard({
    required String title,
    required String description,
    required String language,
    required String rate,
    required String duration,
    required bool isUrgent,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(
          color: ColorManager.greyMedium.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSize.s8,
                    vertical: AppSize.s4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSize.s4),
                  ),
                  child: const Text(
                    AppStrings.urgent,
                    style: TextStyle(
                      fontSize: AppSize.s10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSize.s8),
          Text(
            description,
            style: TextStyle(
              fontSize: AppSize.s14,
              color: ColorManager.textSecondary,
            ),
          ),
          const SizedBox(height: AppSize.s12),
          Row(
            children: [
              Icon(
                Icons.language,
                size: AppSize.s16,
                color: ColorManager.primary2,
              ),
              const SizedBox(width: AppSize.s4),
              Text(
                language,
                style: TextStyle(
                  fontSize: AppSize.s12,
                  color: ColorManager.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${AppStrings.currency}$rate${AppStrings.perHour}',
                style: TextStyle(
                  fontSize: AppSize.s14,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.primary2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: AppSize.s16,
                color: ColorManager.textSecondary,
              ),
              const SizedBox(width: AppSize.s4),
              Text(
                duration,
                style: TextStyle(
                  fontSize: AppSize.s12,
                  color: ColorManager.textSecondary,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  CustomButton(
                    onTap: () {},
                    color: ColorManager.primary2,
                    text: AppStrings.acceptJob,
                    textStyle: const TextStyle(fontSize: AppSize.s12),
                    borderRadius: BorderRadius.circular(AppSize.s6),
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(width: AppSize.s8),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSize.s12,
                        vertical: AppSize.s6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSize.s6),
                      ),
                    ),
                    child: const Text(
                      AppStrings.declineJob,
                      style: TextStyle(fontSize: AppSize.s12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard({
    required String title,
    required String description,
    required String time,
    String? amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(
          color: ColorManager.greyMedium.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSize.s8),
            decoration: BoxDecoration(
              color: ColorManager.primary2.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSize.s8),
            ),
            child: Icon(
              Icons.check_circle,
              color: ColorManager.primary2,
              size: AppSize.s20,
            ),
          ),
          const SizedBox(width: AppSize.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppSize.s14,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSize.s4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    color: ColorManager.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSize.s4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: AppSize.s10,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (amount != null)
            Text(
              '${AppStrings.currency}$amount',
              style: TextStyle(
                fontSize: AppSize.s14,
                fontWeight: FontWeight.bold,
                color: ColorManager.primary2,
              ),
            ),
        ],
      ),
    );
  }
}
