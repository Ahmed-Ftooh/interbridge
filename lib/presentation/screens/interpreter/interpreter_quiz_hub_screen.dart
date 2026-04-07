import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_screen.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen shown to new interpreters after signup to complete required quizzes.
/// - Entry-level (volunteer): Only general quiz required
/// - Experienced (paid): General quiz + 3 medical quizzes required
class InterpreterQuizHubScreen extends StatefulWidget {
  const InterpreterQuizHubScreen({super.key});

  @override
  State<InterpreterQuizHubScreen> createState() =>
      _InterpreterQuizHubScreenState();
}

class _InterpreterQuizHubScreenState extends State<InterpreterQuizHubScreen> {
  bool _isLoading = true;
  String _employmentType = 'volunteer'; // 'volunteer' or 'paid'
  Set<String> _attemptedQuizzes = {}; // Track all attempted medical quizzes
  bool _hasAttemptedGeneralQuiz = false; // Track if general quiz was attempted
  bool _hasCompletedAdvancedFluencyQuiz = false;

  // All medical sections with Font Awesome icons for accurate medical representations
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
  ];

  // Total number of medical quizzes (all must be completed)
  int get _totalMedicalQuizzes => _medicalSections.length;

  @override
  void initState() {
    super.initState();
    // First check badges (same as splash) to immediately redirect if complete
    // This prevents any flash of quiz screen for users who already completed quizzes
    _quickBadgeCheck().then((_) {
      // Only load full data if not redirected
      if (mounted) {
        _loadData();
      }
    });
  }

  /// Quick check of badges to redirect immediately if quizzes are complete
  /// This mirrors the splash screen logic to prevent any UI flash
  Future<void> _quickBadgeCheck() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final client = Supabase.instance.client;

      // Fetch badges and employment type separately to avoid type casting issues
      final profileData =
          await client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();

      final badgesData = await client
          .from('interpreter_badges')
          .select('badge')
          .eq('user_id', userId);
      final fluencyData = await client
          .from('voice_samples')
          .select('id')
          .eq('user_id', userId)
          .eq('sentence_type', advancedFluencySentenceType);

      if (!mounted) return;

      final employmentType = profileData?['employment_type'] ?? 'volunteer';
      final badges =
          (badgesData as List)
              .map((b) => b['badge']?.toString() ?? '')
              .where((b) => b.isNotEmpty)
              .toSet();

      final hasGeneral = badges.contains('general');
      final medicalCount = badges.where((b) => b != 'general').length;
      final hasAdvancedFluency =
          (fluencyData as List).length >= advancedFluencyQuestionCount;
      final bool isExperienced = employmentType == 'paid';
      final bool allComplete =
          isExperienced
              ? (hasGeneral && medicalCount >= 10 && hasAdvancedFluency)
              : (hasGeneral && hasAdvancedFluency);

      if (allComplete && mounted) {
        // Mark quiz onboarding as done so we don't check again on next login
        await instance<AppPreferences>().setQuizOnboardingDone();
        if (!mounted) return;
        // Immediately navigate to main without showing any quiz UI
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      debugPrint('Quick badge check failed: $e');
      // Continue to load data normally, don't fail silently
    }
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Get employment type
      final profileData =
          await Supabase.instance.client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();

      // Get all quiz attempts to prevent retaking (one attempt per quiz)
      final attemptsData = await Supabase.instance.client
          .from('quiz_attempts')
          .select('quiz_type, medical_section')
          .eq('user_id', userId);
      final fluencyData = await Supabase.instance.client
          .from('voice_samples')
          .select('id')
          .eq('user_id', userId)
          .eq('sentence_type', advancedFluencySentenceType);

      if (mounted) {
        // Build set of attempted quizzes
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
          _attemptedQuizzes = attemptedQuizzes;
          _hasAttemptedGeneralQuiz = attemptedGeneral;
          _hasCompletedAdvancedFluencyQuiz =
              (fluencyData as List).length >= advancedFluencyQuestionCount;
          _isLoading = false;
        });

        // Check if all quizzes are completed
        _checkAndNavigateIfComplete();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkAndNavigateIfComplete() {
    final bool isExperienced = _employmentType == 'paid';

    bool allQuizzesAttempted;
    if (isExperienced) {
      // Experienced: must ATTEMPT general + complete advanced fluency + ALL medical quizzes
      allQuizzesAttempted =
          _hasAttemptedGeneralQuiz &&
          _hasCompletedAdvancedFluencyQuiz &&
          _attemptedQuizzes.length >= _totalMedicalQuizzes;
    } else {
      // Entry-level: must ATTEMPT general quiz + complete advanced fluency test
      allQuizzesAttempted =
          _hasAttemptedGeneralQuiz && _hasCompletedAdvancedFluencyQuiz;
    }

    if (allQuizzesAttempted) {
      // Mark quiz onboarding as done so we don't check again on next login
      instance<AppPreferences>().setQuizOnboardingDone();
      // Navigate to main screen with pending verification status
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

  String _getHeaderMessage(bool isExperienced) {
    if (!isExperienced) {
      if (!_hasAttemptedGeneralQuiz && !_hasCompletedAdvancedFluencyQuiz) {
        return 'Complete the advanced speaking fluency test first, then the general quiz to qualify.';
      }
      if (!_hasAttemptedGeneralQuiz) {
        return 'Complete the general interpreter quiz to qualify.';
      }
      if (!_hasCompletedAdvancedFluencyQuiz) {
        return 'Complete the advanced speaking fluency test to qualify.';
      }
      return 'You have completed all required quizzes!';
    }

    // Experienced track
    final int remainingMedical =
        _totalMedicalQuizzes - _attemptedQuizzes.length;

    if (!_hasAttemptedGeneralQuiz &&
        !_hasCompletedAdvancedFluencyQuiz &&
        remainingMedical == _totalMedicalQuizzes) {
      return 'Complete the advanced speaking fluency test first, then the general quiz, then all $_totalMedicalQuizzes medical specialization quizzes to qualify.';
    } else if (!_hasAttemptedGeneralQuiz) {
      return 'Complete the general quiz and $remainingMedical more medical quiz${remainingMedical > 1 ? 'zes' : ''} to qualify.';
    } else if (!_hasCompletedAdvancedFluencyQuiz) {
      return 'Great job. Complete the advanced speaking fluency test to qualify.';
    } else if (remainingMedical > 0) {
      return 'Great job! Complete $remainingMedical more medical specialization quiz${remainingMedical > 1 ? 'zes' : ''} to qualify.';
    }
    return 'You have completed all required quizzes!';
  }

  Future<void> _takeQuiz(String quizType, {String? medicalSection}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => QuizScreen(
              quizType: quizType,
              medicalSection: medicalSection,
              isRequired: true,
            ),
      ),
    );

    // Always reload data to refresh badge status
    if (result != null) {
      await _loadData();
    }
  }

  Future<void> _takeAdvancedFluencyQuiz() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdvancedFluencyQuizScreen()),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _openInterbridgeLingAcademy() async {
    final uri = Uri.parse('https://interbridge-ling.com');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open InterBridge Ling Academy right now.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open InterBridge Ling Academy right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isExperienced = _employmentType == 'paid';

    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Complete Your Qualification',
          style: TextStyle(color: ColorManager.textPrimary),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(AppSize.s20),
            children: [
              // Header
              _buildHeader(isExperienced),
              const SizedBox(height: 24),

              // Progress Card
              _buildProgressCard(isExperienced),
              const SizedBox(height: 16),
              _buildLearningOfferCard(),
              const SizedBox(height: 24),

              if (!_hasCompletedAdvancedFluencyQuiz) ...[
                _buildSectionTitle(
                  'Advanced Speaking',
                  'Required for both general and specialist interpreters',
                ),
                const SizedBox(height: 12),
                _buildQuizCard(
                  title: advancedFluencyQuizTitle,
                  subtitle:
                      '$advancedFluencyQuestionCount recorded answers across 5 sections',
                  icon: Icons.record_voice_over,
                  isPassed: false,
                  onTap: _takeAdvancedFluencyQuiz,
                ),
              ],

              // General quiz unlocks only after advanced fluency is completed.
              if (_hasCompletedAdvancedFluencyQuiz &&
                  !_hasAttemptedGeneralQuiz) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'General Quiz',
                  'Required for all interpreters',
                ),
                const SizedBox(height: 12),
                _buildQuizCard(
                  title: 'General Interpreter Quiz',
                  subtitle: '25 seconds per question',
                  icon: Icons.school,
                  isPassed: false,
                  onTap: () => _takeQuiz('general'),
                ),
              ],

              // Medical Quizzes Section (only for experienced, show until all quizzes attempted)
              if (isExperienced &&
                  _hasCompletedAdvancedFluencyQuiz &&
                  _hasAttemptedGeneralQuiz &&
                  _attemptedQuizzes.length < _totalMedicalQuizzes) ...[
                const SizedBox(height: 32),
                _buildSectionTitle(
                  'Medical Specializations',
                  'Complete all $_totalMedicalQuizzes quizzes (${_attemptedQuizzes.length}/$_totalMedicalQuizzes done)',
                ),
                const SizedBox(height: 12),
                // Only show sections that haven't been ATTEMPTED yet
                ..._medicalSections
                    .where(
                      (section) => !_attemptedQuizzes.contains(section['id']),
                    )
                    .map((section) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildQuizCard(
                          title: section['title'] as String,
                          subtitle: '30 seconds per question',
                          icon: section['icon'] as IconData,
                          isPassed: false,
                          onTap:
                              () => _takeQuiz(
                                'medical',
                                medicalSection: section['id'] as String,
                              ),
                        ),
                      );
                    }),
              ],

              const SizedBox(height: 24),
              // Info note
              _buildInfoNote(isExperienced),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isExperienced) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorManager.primary2.withAlpha(20),
            ColorManager.primary2.withAlpha(5),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorManager.primary2.withAlpha(30)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorManager.primary2.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_outlined,
              size: 48,
              color: ColorManager.primary2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Qualification Quizzes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getHeaderMessage(isExperienced),
            style: TextStyle(
              fontSize: 14,
              color: ColorManager.textSecondary,
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
      totalRequired =
          2 + _totalMedicalQuizzes; // general + advanced + all medical
      completed =
          (_hasAttemptedGeneralQuiz ? 1 : 0) +
          (_hasCompletedAdvancedFluencyQuiz ? 1 : 0) +
          _attemptedQuizzes.length.clamp(0, _totalMedicalQuizzes);
    } else {
      totalRequired = 2; // general + advanced fluency
      completed =
          (_hasAttemptedGeneralQuiz ? 1 : 0) +
          (_hasCompletedAdvancedFluencyQuiz ? 1 : 0);
    }

    final progress = completed / totalRequired;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ColorManager.textPrimary,
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
                          ? Colors.green.withAlpha(30)
                          : Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed / $totalRequired completed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color:
                        progress >= 1
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
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
              backgroundColor: ColorManager.greyLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1 ? Colors.green : ColorManager.primary2,
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningOfferCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorManager.primary2.withAlpha(15),
            ColorManager.primary2.withAlpha(5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorManager.primary2.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ColorManager.primary2.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school_rounded, color: ColorManager.primary2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep growing as an interpreter',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Sharpen your medical and professional interpreting skills with guided courses at InterBridge Ling Academy.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: ColorManager.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openInterbridgeLingAcademy,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Start learning at interbridge-ling.com'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: ColorManager.textSecondary),
        ),
      ],
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
              child: FaIcon(
                icon,
                color: isPassed ? Colors.green : ColorManager.primary2,
                size: 28,
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

  Widget _buildInfoNote(bool isExperienced) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isExperienced
                  ? 'After completing all required quizzes, your account will be reviewed by an administrator before you can start accepting jobs.'
                  : 'After completing the general quiz and advanced speaking test, your account will be reviewed by an administrator before you can start accepting jobs.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
