import 'package:flutter/material.dart';
import 'package:interbridge/data/models/interpreter_level.dart';
import 'package:interbridge/data/models/interpreter_track.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class InterpreterTrackSelectionScreen extends StatefulWidget {
  const InterpreterTrackSelectionScreen({super.key});

  @override
  State<InterpreterTrackSelectionScreen> createState() =>
      _InterpreterTrackSelectionScreenState();
}

class _InterpreterTrackSelectionScreenState
    extends State<InterpreterTrackSelectionScreen> {
  InterpreterLevel? _selectedLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSize.s10),
              Text(
                'Choose your path',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: AppSize.s12),
              Text(
                'Select the interpreter track that best fits your experience.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: ColorManager.textSecondary,
                ),
              ),
              const SizedBox(height: AppSize.s24),

              // Track Selection
              Text(
                'Your Track',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: AppSize.s12),
              _TrackCard(
                title: 'Entry-Level Beginner',
                subtitle: 'Start with Basic medical calls',
                description:
                    'Ideal for newcomers to interpreting. Support humanitarian Cases and build experience.',
                icon: Icons.volunteer_activism_rounded,
                color: ColorManager.primary2,
                isSelected: _selectedLevel == InterpreterLevel.volunteer,
                onTap:
                    () => setState(
                      () => _selectedLevel = InterpreterLevel.volunteer,
                    ),
              ),
              const SizedBox(height: AppSize.s16),
              _TrackCard(
                title: 'Experienced Medical Interpreter',
                subtitle: 'Advanced medical Specialized Calls',
                description:
                    'For experienced interpreters. Complete medical sections and qualify for paid shifts.',
                icon: Icons.medical_services_rounded,
                color: ColorManager.success,
                isSelected: _selectedLevel == InterpreterLevel.paid,
                onTap:
                    () =>
                        setState(() => _selectedLevel = InterpreterLevel.paid),
              ),
              const SizedBox(height: AppSize.s32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primary2,
                    padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSize.s16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSize.s24),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canContinue => _selectedLevel != null;

  void _continue() {
    final track =
        _selectedLevel == InterpreterLevel.volunteer
            ? InterpreterTrack.volunteer
            : InterpreterTrack.paid;

    final args = <String, dynamic>{
      'role': 'interpreter',
      'interpreterLevel': _selectedLevel!.name,
      'interpreterTrack': track.name,
      'requiresMedicalDocs': _selectedLevel == InterpreterLevel.paid,
    };
    Navigator.of(context).pushNamed(Routes.selectLanguage, arguments: args);
  }
}

class _TrackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrackCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(AppSize.s24),
        border: Border.all(
          color: isSelected ? color : ColorManager.greyLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSize.s24),
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSize.s12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSize.s16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: AppSize.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: color,
                              size: 24,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSize.s12),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorManager.textSecondary,
                          height: 1.4,
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
    );
  }
}
