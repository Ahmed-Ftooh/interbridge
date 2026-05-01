import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_screen.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_web_screen_stub.dart'
    if (dart.library.html) 'package:interbridge/presentation/screens/quiz/quiz_web_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// View displaying all medical specialization badges and quizzes.
/// Shows available specializations that the interpreter can take quizzes for.
class InterpreterBadgesView extends StatefulWidget {
  const InterpreterBadgesView({super.key});

  @override
  State<InterpreterBadgesView> createState() => _InterpreterBadgesViewState();
}

class _InterpreterBadgesViewState extends State<InterpreterBadgesView> {
  bool _isLoading = true;
  Set<String> _completedBadges = {};
  Set<String> _attemptedMedicalSections = {};

  // All medical sections with Font Awesome icons
  final List<Map<String, dynamic>> _medicalSections = [
    {'id': 'neurology', 'title': 'Neurology', 'icon': FontAwesomeIcons.brain},
    {
      'id': 'cardiology',
      'title': 'Cardiology',
      'icon': FontAwesomeIcons.heartPulse,
    },
    {
      'id': 'emergency',
      'title': 'Emergency Medicine',
      'icon': FontAwesomeIcons.truckMedical,
    },
    {'id': 'oncology', 'title': 'Oncology', 'icon': FontAwesomeIcons.ribbon},
    {
      'id': 'respiratory',
      'title': 'Respiratory',
      'icon': FontAwesomeIcons.lungs,
    },
    {
      'id': 'gastrointestinal',
      'title': 'Gastrointestinal',
      'icon': FontAwesomeIcons.disease,
    },
    {
      'id': 'endocrinology',
      'title': 'Endocrinology',
      'icon': FontAwesomeIcons.vial,
    },
    {'id': 'renal', 'title': 'Renal', 'icon': FontAwesomeIcons.droplet},
    {
      'id': 'ob_gyn',
      'title': 'OB/GYN',
      'icon': FontAwesomeIcons.personBreastfeeding,
    },
    {
      'id': 'dermatology',
      'title': 'Dermatology',
      'icon': FontAwesomeIcons.handDots,
    },
    {'id': 'ear_and_eye', 'title': 'Ear and Eye', 'icon': FontAwesomeIcons.eye},
  ];

  @override
  void initState() {
    super.initState();
    _loadBadgesAndAttempts();
  }

  Future<void> _loadBadgesAndAttempts() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Get completed badges
      final badgesData = await Supabase.instance.client
          .from('interpreter_badges')
          .select('badge')
          .eq('user_id', userId);

      // Get quiz attempts for medical sections
      final attemptsData = await Supabase.instance.client
          .from('quiz_attempts')
          .select('medical_section')
          .eq('user_id', userId)
          .eq('quiz_type', 'medical');

      if (mounted) {
        final completedBadges =
            (badgesData as List)
                .map((b) => b['badge']?.toString() ?? '')
                .where((b) => b.isNotEmpty && b != 'general')
                .toSet();

        final attemptedSections =
            (attemptsData as List)
                .map((a) => a['medical_section']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toSet();

        setState(() {
          _completedBadges = completedBadges;
          _attemptedMedicalSections = attemptedSections;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading badges and attempts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takeQuiz(String medicalSection) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => kIsWeb
                ? QuizWebScreen(
                    quizType: 'medical',
                    medicalSection: medicalSection,
                    isRequired: false,
                  )
                : QuizScreen(
                    quizType: 'medical',
                    medicalSection: medicalSection,
                    isRequired: false,
                  ),
      ),
    );

    if (result != null) {
      await _loadBadgesAndAttempts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: null, 
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  children: [
                    _buildWebHeader(),
                    const SizedBox(height: 32),
                    ..._medicalSections.map((section) {
                      final sectionId = section['id'] as String;
                      final title = section['title'] as String;
                      final icon = section['icon'] as IconData;
                      final isCompleted = _completedBadges.contains(sectionId);
                      final isAttempted = _attemptedMedicalSections.contains(sectionId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWebQuizCard(
                          title: title,
                          icon: icon,
                          isCompleted: isCompleted,
                          isAttempted: isAttempted,
                          onTap: isCompleted ? null : () => _takeQuiz(sectionId),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25), // 0.1
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Specialty Certification Badges',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Earn badges to recive more Calls',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebQuizCard({
    required String title,
    required IconData icon,
    required bool isCompleted,
    required bool isAttempted,
    VoidCallback? onTap,
  }) {
    final bool isInteractive = !isCompleted;
    
    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFFF1F5F9).withAlpha(128) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A).withAlpha(12), // 0.05
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: FaIcon(
                    icon,
                    color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCompleted
                          ? 'Status (Passed 🏆)'
                          : isAttempted 
                              ? 'Status (Attempted)' 
                              : 'Status (Available ⭐)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isCompleted
                            ? const Color(0xFF059669)
                            : isAttempted 
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isCompleted ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estimated: 15 mins',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.flag_outlined,
                          size: 14,
                          color: isCompleted ? const Color(0xFFCBD5E1) : const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Target: 85%',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isCompleted)
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8))
              else
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(
                     color: const Color(0xFF059669).withAlpha(25), // 0.1
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: const Text(
                     'Earned', 
                     style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)
                   ),
                 ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Medical Specializations'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadBadgesAndAttempts,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSize.s16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSize.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ColorManager.primary2.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.medical_services_outlined,
                                size: 48,
                                color: ColorManager.primary2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Medical Specializations',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: ColorManager.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Earn badges by completing specialization quizzes',
                              style: TextStyle(
                                fontSize: 14,
                                color: ColorManager.textSecondary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._medicalSections.map((section) {
                        final sectionId = section['id'] as String;
                        final title = section['title'] as String;
                        final icon = section['icon'] as IconData;
                        final isCompleted =
                            _completedBadges.contains(sectionId);
                        final isAttempted =
                            _attemptedMedicalSections.contains(sectionId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildQuizCard(
                            title: title,
                            subtitle: isCompleted 
                                ? 'Badge Earned' 
                                : isAttempted 
                                    ? 'Attempted - Available to retake soon'
                                    : '30 seconds per question',
                            icon: icon,
                            isPassed: isCompleted,
                            onTap: isCompleted ? null : () => _takeQuiz(sectionId),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildQuizCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPassed,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPassed ? Colors.green.withAlpha(10) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isPassed
                    ? Colors.green.withAlpha(100)
                    : ColorManager.greyMedium.withAlpha(50),
            width: isPassed ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    isPassed
                        ? Colors.green.withAlpha(30)
                        : ColorManager.primary2.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  color: isPassed ? Colors.green : ColorManager.primary2,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isPassed
                              ? Colors.green.shade700
                              : ColorManager.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isPassed)
              Icon(Icons.chevron_right, color: ColorManager.textSecondary)
            else
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
