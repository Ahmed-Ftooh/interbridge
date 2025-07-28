import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class RequesterHomeView extends StatefulWidget {
  const RequesterHomeView({super.key});

  @override
  State<RequesterHomeView> createState() => _RequesterHomeViewState();
}

class _RequesterHomeViewState extends State<RequesterHomeView> {
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
                // Simple header
                Container(
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
                            Text(
                              'How can we help you today?',
                              style: TextStyle(
                                color: ColorManager.white.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: AppSize.s14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSize.s24),

                // Quick Actions
                Text(
                  AppStrings.quickActions,
                  style: TextStyle(
                    fontSize: AppSize.s18,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSize.s16),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.emergency,
                        title: AppStrings.emergencyRequest,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: AppSize.s12),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.schedule,
                        title: AppStrings.scheduledRequest,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSize.s12),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.description,
                        title: AppStrings.documentTranslation,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: AppSize.s12),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.search,
                        title: AppStrings.findInterpreter,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSize.s24),

                // Active Requests
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.activeRequests,
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
                const SizedBox(height: AppSize.s16),
                _buildRequestCard(
                  title: 'Medical Consultation',
                  description: 'Urgent medical consultation needed',
                  language: 'English - Arabic',
                  status: 'In Progress',
                  time: '2 hours ago',
                  isUrgent: true,
                ),
                const SizedBox(height: AppSize.s12),
                _buildRequestCard(
                  title: 'Legal Document Translation',
                  description: 'Contract translation required',
                  language: 'English - Spanish',
                  status: 'Waiting for Interpreter',
                  time: '1 day ago',
                  isUrgent: false,
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

  Widget _buildRequestCard({
    required String title,
    required String description,
    required String language,
    required String status,
    required String time,
    required bool isUrgent,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'in progress':
        statusColor = Colors.blue;
        break;
      case 'waiting for interpreter':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.s8,
                  vertical: AppSize.s4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: AppSize.s10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
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
                time,
                style: TextStyle(
                  fontSize: AppSize.s12,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
