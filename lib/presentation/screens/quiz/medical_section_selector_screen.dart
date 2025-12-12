import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_screen.dart';

class MedicalSectionSelectorScreen extends StatefulWidget {
  final Future<void> Function(String sectionId)? onSectionTap;

  const MedicalSectionSelectorScreen({super.key, this.onSectionTap});

  @override
  State<MedicalSectionSelectorScreen> createState() =>
      _MedicalSectionSelectorScreenState();
}

class _MedicalSectionSelectorScreenState
    extends State<MedicalSectionSelectorScreen> {
  final _supabase = SupabaseService();
  final List<_MedicalSection> _sections = const [
    _MedicalSection('neurology', 'Neurology', Icons.psychology),
    _MedicalSection('cardiology', 'Cardiology', Icons.favorite),
    _MedicalSection('respiratory', 'Respiratory', Icons.air),
    _MedicalSection('gastrointestinal', 'Gastrointestinal', Icons.medication),
    _MedicalSection('endocrinology', 'Endocrinology', Icons.water_drop),
    _MedicalSection('renal', 'Renal System', Icons.opacity),
    _MedicalSection('ob_gyn', 'OB/GYN', Icons.pregnant_woman),
    _MedicalSection('oncology', 'Oncology', Icons.healing),
    _MedicalSection('emergency', 'Emergency', Icons.emergency),
    _MedicalSection(
      'dermatology',
      'Dermatology',
      Icons.face_retouching_natural,
    ),
  ];

  Map<String, bool> _earnedBadges = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserBadges();
  }

  Future<void> _loadUserBadges() async {
    try {
      final user = _supabase.getCurrentUser();
      if (user != null) {
        final badges = await _supabase.getUserBadges(user.id);
        setState(() {
          _earnedBadges = {for (var b in badges) b['badge'] as String: true};
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Failed to load badges: $e');
    }
  }

  Future<void> _startSection(String sectionId) async {
    // Use custom callback if provided, otherwise use default navigation
    if (widget.onSectionTap != null) {
      await widget.onSectionTap!(sectionId);
      // Reload badges after quiz
      await _loadUserBadges();
      return;
    }

    // Default behavior: navigate to quiz and reload badges
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (_) => QuizScreen(quizType: 'medical', medicalSection: sectionId),
      ),
    );

    if (result != null && result['passed'] == true) {
      // Reload badges
      await _loadUserBadges();
    }
  }

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
        title: const Text('Medical Specializations'),
        centerTitle: true,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSize.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earn Badges',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score 80%+ on each section quiz to earn a badge',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: ColorManager.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                          itemCount: _sections.length,
                          itemBuilder: (context, index) {
                            final section = _sections[index];
                            final earned = _earnedBadges[section.id] == true;
                            return _SectionCard(
                              section: section,
                              earned: earned,
                              onTap: () => _startSection(section.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _MedicalSection {
  final String id;
  final String name;
  final IconData icon;

  const _MedicalSection(this.id, this.name, this.icon);
}

class _SectionCard extends StatelessWidget {
  final _MedicalSection section;
  final bool earned;
  final VoidCallback onTap;

  const _SectionCard({
    required this.section,
    required this.earned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? ColorManager.success : ColorManager.greyLight,
            width: earned ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        earned
                            ? ColorManager.success.withValues(alpha: 0.1)
                            : ColorManager.primary2.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    section.icon,
                    size: 32,
                    color:
                        earned ? ColorManager.success : ColorManager.primary2,
                  ),
                ),
                if (earned)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ColorManager.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              section.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (earned) ...[
              const SizedBox(height: 4),
              Text(
                'Earned',
                style: TextStyle(
                  fontSize: 12,
                  color: ColorManager.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
