import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_web_screen_stub.dart'
    if (dart.library.html) 'package:interbridge/presentation/screens/quiz/quiz_web_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web version of the interpreter quiz hub.
/// Shown post-signup so interpreters complete required quizzes.
/// - Volunteer: general quiz only
/// - Paid: general + all 10 medical quizzes
class InterpreterQuizHubWebScreen extends StatefulWidget {
  const InterpreterQuizHubWebScreen({super.key});

  @override
  State<InterpreterQuizHubWebScreen> createState() =>
      _InterpreterQuizHubWebScreenState();
}

class _InterpreterQuizHubWebScreenState
    extends State<InterpreterQuizHubWebScreen> {
  bool _isLoading = true;
  String _employmentType = 'volunteer';
  Set<String> _attemptedMedicalQuizzes = {};
  bool _hasAttemptedGeneralQuiz = false;

  final List<Map<String, dynamic>> _medicalSections = [
    {
      'id': 'neurology',
      'title': 'Neurology',
      'icon': FontAwesomeIcons.brain,
      'color': Colors.purple,
    },
    {
      'id': 'cardiology',
      'title': 'Cardiovascular',
      'icon': FontAwesomeIcons.heartPulse,
      'color': Colors.red,
    },
    {
      'id': 'emergency',
      'title': 'Emergency',
      'icon': FontAwesomeIcons.truckMedical,
      'color': Colors.blue,
    },
    {
      'id': 'oncology',
      'title': 'Oncology',
      'icon': FontAwesomeIcons.ribbon,
      'color': Colors.pink,
    },
    {
      'id': 'respiratory',
      'title': 'Respiratory',
      'icon': FontAwesomeIcons.lungs,
      'color': Colors.cyan,
    },
    {
      'id': 'gastrointestinal',
      'title': 'Gastrointestinal',
      'icon': FontAwesomeIcons.disease,
      'color': Colors.brown,
    },
    {
      'id': 'endocrinology',
      'title': 'Endocrinology',
      'icon': FontAwesomeIcons.vial,
      'color': Colors.teal,
    },
    {
      'id': 'renal',
      'title': 'Renal',
      'icon': FontAwesomeIcons.droplet,
      'color': Colors.lightBlue,
    },
    {
      'id': 'ob_gyn',
      'title': 'OB/GYN',
      'icon': FontAwesomeIcons.personBreastfeeding,
      'color': Colors.pinkAccent,
    },
    {
      'id': 'dermatology',
      'title': 'Dermatology',
      'icon': FontAwesomeIcons.handDots,
      'color': Colors.orangeAccent,
    },
  ];

  int get _totalMedicalQuizzes => _medicalSections.length;

  @override
  void initState() {
    super.initState();
    _quickAttemptCheck().then((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _quickAttemptCheck() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final client = Supabase.instance.client;
      final profileData =
          await client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();
      final attemptsData = await client
          .from('quiz_attempts')
          .select('quiz_type, medical_section')
          .eq('user_id', userId);

      if (!mounted) return;

      final employmentType = profileData?['employment_type'] ?? 'volunteer';
      bool hasGeneralAttempt = false;
      final attemptedMedical = <String>{};
      for (final attempt in (attemptsData as List)) {
        final quizType = attempt['quiz_type']?.toString();
        final section = attempt['medical_section']?.toString();
        if (quizType == 'general') {
          hasGeneralAttempt = true;
        } else if (quizType == 'medical' && section != null) {
          attemptedMedical.add(section);
        }
      }

      final bool isExperienced = employmentType == 'paid';
      final bool allComplete =
          isExperienced
              ? (hasGeneralAttempt && attemptedMedical.length >= 10)
              : hasGeneralAttempt;

      if (allComplete && mounted) {
        await client
            .from('interpreter_details')
            .update({'onboarding_status': 'under_review'})
            .eq('user_id', userId);
        await instance<AppPreferences>().setQuizOnboardingDone();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      debugPrint('Quick attempt check failed: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final profileData =
          await Supabase.instance.client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();

      final attemptsData = await Supabase.instance.client
          .from('quiz_attempts')
          .select('quiz_type, medical_section')
          .eq('user_id', userId);

      if (mounted) {
        final attemptedQuizzes = <String>{};
        bool attemptedGeneral = false;
        for (final attempt in (attemptsData as List)) {
          final quizType = attempt['quiz_type']?.toString();
          final section = attempt['medical_section']?.toString();
          if (quizType == 'general') {
            attemptedGeneral = true;
          } else if (quizType == 'medical' && section != null) {
            attemptedQuizzes.add(section);
          }
        }

        setState(() {
          _employmentType = profileData?['employment_type'] ?? 'volunteer';
          _attemptedMedicalQuizzes = attemptedQuizzes;
          _hasAttemptedGeneralQuiz = attemptedGeneral;
          _isLoading = false;
        });

        await _checkAndNavigateIfComplete();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndNavigateIfComplete() async {
    final bool isExperienced = _employmentType == 'paid';
    bool allQuizzesAttempted;

    if (isExperienced) {
      allQuizzesAttempted =
          _hasAttemptedGeneralQuiz &&
          _attemptedMedicalQuizzes.length >= _totalMedicalQuizzes;
    } else {
      allQuizzesAttempted = _hasAttemptedGeneralQuiz;
    }

    if (allQuizzesAttempted) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('interpreter_details')
            .update({'onboarding_status': 'under_review'})
            .eq('user_id', userId);
      }
      await instance<AppPreferences>().setQuizOnboardingDone();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

  Future<void> _takeQuiz(String quizType, {String? medicalSection}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => QuizWebScreen(
              quizType: quizType,
              medicalSection: medicalSection,
              isRequired: true,
            ),
      ),
    );

    if (result != null) {
      await _loadData();
    }
  }

  String _getHeaderMessage(bool isExperienced) {
    if (!isExperienced) {
      if (!_hasAttemptedGeneralQuiz) {
        return 'Complete the general interpreter quiz to qualify.';
      }
      return 'You have completed all required quizzes!';
    }

    final int remainingMedical =
        _totalMedicalQuizzes - _attemptedMedicalQuizzes.length;

    if (!_hasAttemptedGeneralQuiz && remainingMedical == _totalMedicalQuizzes) {
      return 'To ensure the highest standards of medical accuracy, please complete the mandatory General Interpreter Quiz and the 10 core medical specialization modules to unlock your full profile.';
    } else if (!_hasAttemptedGeneralQuiz) {
      return 'Complete the general quiz and $remainingMedical more medical quiz${remainingMedical > 1 ? 'zes' : ''} to qualify.';
    } else if (remainingMedical > 0) {
      return 'Great job! Complete $remainingMedical more medical specialization quiz${remainingMedical > 1 ? 'zes' : ''} to qualify.';
    }
    return 'You have completed all required quizzes!';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F172A)),
        ),
      );
    }

    final bool isExperienced = _employmentType == 'paid';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            children: [
              // Logo
              _buildLogo(),
              const SizedBox(height: 32),

              // Header card
              _buildHeader(isExperienced),
              const SizedBox(height: 24),

              // Progress
              _buildProgressCard(isExperienced),
              const SizedBox(height: 32),

              // General Quiz
              if (!_hasAttemptedGeneralQuiz) ...[
                _buildSectionTitle(
                  'Professional Standards & Medical Assessment',
                  'Mandatory for all interpreters',
                ),
                const SizedBox(height: 12),
                _buildQuizCard(
                  title: 'Start Assessment',
                  icon: Icons.school,
                  iconColor: Colors.blue,
                  isLocked: false,
                  onTap: () => _takeQuiz('general'),
                ),
              ],

              // Medical Quizzes
              if (isExperienced &&
                  _attemptedMedicalQuizzes.length < _totalMedicalQuizzes) ...[
                const SizedBox(height: 32),
                _buildSectionTitle(
                  'Advanced Clinical Specializations',
                  'Advanced Medical Interpreter Certification Modules | ${_attemptedMedicalQuizzes.length}/$_totalMedicalQuizzes completed',
                ),
                const SizedBox(height: 12),
                ...(() {
                  final remainingSections =
                      _medicalSections
                          .where(
                            (section) =>
                                !_attemptedMedicalQuizzes.contains(
                                  section['id'],
                                ),
                          )
                          .toList();

                  return remainingSections.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final section = entry.value;

                    // If General Quiz is not done, everything here is locked.
                    // Otherwise, only the very first remaining medical section is unlocked.
                    final bool isLocked = !_hasAttemptedGeneralQuiz || idx > 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildQuizCard(
                        title: section['title'] as String,
                        icon: section['icon'] as IconData,
                        iconColor:
                            section['color'] as Color? ??
                            const Color(0xFF3B82F6),
                        isLocked: isLocked,
                        onTap:
                            isLocked
                                ? null
                                : () => _takeQuiz(
                                  'medical',
                                  medicalSection: section['id'] as String,
                                ),
                      ),
                    );
                  });
                })(),
              ],

              const SizedBox(height: 24),
              _buildInfoNote(isExperienced),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              ImageAssets.appIcon,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'InterBridge',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isExperienced) {
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
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Professional Accreditation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getHeaderMessage(isExperienced),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isExperienced) {
    int totalRequired;
    int completed;

    if (isExperienced) {
      totalRequired = 1 + _totalMedicalQuizzes;
      completed =
          (_hasAttemptedGeneralQuiz ? 1 : 0) +
          _attemptedMedicalQuizzes.length.clamp(0, _totalMedicalQuizzes);
    } else {
      totalRequired = 1;
      completed = _hasAttemptedGeneralQuiz ? 1 : 0;
    }

    final progress = completed / totalRequired;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      progress >= 1
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed / $totalRequired completed',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1
                    ? const Color(0xFF10B981)
                    : const Color(0xFF3B82F6),
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildQuizCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isLocked,
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor:
          isLocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                isLocked
                    ? const Color(0xFFF1F5F9).withValues(alpha: 0.5)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      isLocked
                          ? const Color(0xFFE2E8F0)
                          : iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: FaIcon(
                    icon,
                    color: isLocked ? const Color(0xFF94A3B8) : iconColor,
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
                        color:
                            isLocked
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLocked ? 'Status (Locked 🔒)' : 'Status (Available ⭐)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                            isLocked
                                ? const Color(0xFF64748B)
                                : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color:
                              isLocked
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estimated: 15 mins',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isLocked
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.flag_outlined,
                          size: 14,
                          color:
                              isLocked
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Target: 85%',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isLocked
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLocked)
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoNote(bool isExperienced) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF0EA5E9), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isExperienced
                  ? 'After completing all required quizzes, your account will be reviewed by an administrator before you can start accepting jobs.'
                  : 'After passing the general quiz, your account will be reviewed by an administrator before you can start accepting jobs.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0C4A6E),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
