import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_screen.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_web_screen_stub.dart'
    if (dart.library.html) 'package:interbridge/presentation/screens/quiz/quiz_web_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web version of the interpreter quiz hub.
/// Shown post-signup so interpreters complete required quizzes.
/// - All interpreters: advanced fluency + general quiz
/// - Medical specializations live in the Badges tab after onboarding
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
  bool _hasAttemptedGeneralQuiz = false;
  bool _hasCompletedAdvancedFluencyQuiz = false;

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
        final attemptsData = await client
          .from('quiz_attempts')
          .select('quiz_type')
          .eq('user_id', userId)
          .eq('quiz_type', 'general');
      final fluencyData = await client
          .from('voice_samples')
          .select('id')
          .eq('user_id', userId)
          .eq('sentence_type', advancedFluencySentenceType);

      if (!mounted) return;

      final hasGeneralAttempt = (attemptsData as List).isNotEmpty;

      final hasAdvancedFluency =
          (fluencyData as List).length >= advancedFluencyQuestionCount;
      final bool allComplete =
          hasGeneralAttempt && hasAdvancedFluency;

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

        final detailsData = await Supabase.instance.client
          .from('interpreter_details')
          .select('employment_type')
          .eq('user_id', userId)
          .maybeSingle();
        final profileData = await Supabase.instance.client
          .from('users_profile')
          .select('employment_type')
          .eq('user_id', userId)
          .maybeSingle();

        final attemptsData = await Supabase.instance.client
          .from('quiz_attempts')
          .select('quiz_type')
          .eq('user_id', userId)
          .eq('quiz_type', 'general');
      final fluencyData = await Supabase.instance.client
          .from('voice_samples')
          .select('id')
          .eq('user_id', userId)
          .eq('sentence_type', advancedFluencySentenceType);

      if (mounted) {
        final attemptedGeneral = (attemptsData as List).isNotEmpty;

        setState(() {
            _employmentType =
              detailsData?['employment_type'] ??
              profileData?['employment_type'] ??
              'volunteer';
          _hasAttemptedGeneralQuiz = attemptedGeneral;
          _hasCompletedAdvancedFluencyQuiz =
              (fluencyData as List).length >= advancedFluencyQuestionCount;
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
    final bool allQuizzesAttempted =
      _hasAttemptedGeneralQuiz && _hasCompletedAdvancedFluencyQuiz;

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
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
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

  String _getHeaderMessage(bool isExperienced) {
    if (!_hasAttemptedGeneralQuiz && !_hasCompletedAdvancedFluencyQuiz) {
      return 'Complete the Interpreting Mock Test first, then the general interpreter quiz to qualify.';
    }
    if (!_hasAttemptedGeneralQuiz) {
      return 'Complete the general interpreter quiz to qualify.';
    }
    if (!_hasCompletedAdvancedFluencyQuiz) {
      return 'Complete the Interpreting Mock Test to qualify.';
    }
    return isExperienced
        ? 'You have completed all required quizzes! Medical badges are available in the Badges tab.'
        : 'You have completed all required quizzes!';
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
              const SizedBox(height: 16),
            

              // Advanced speaking must be completed first.
              if (!_hasCompletedAdvancedFluencyQuiz) ...[
                _buildSectionTitle(
                  'Interpreting Mock Test',
                  'Required for both general and specialist interpreters',
                ),
                const SizedBox(height: 12),
                _buildQuizCard(
                  title: advancedFluencyQuizTitle,
                  icon: FontAwesomeIcons.microphoneLines,
                  iconColor: const Color(0xFF0284C7),
                  isLocked: false,
                  onTap: _takeAdvancedFluencyQuiz,
                ),
              ],

              // General quiz unlocks after advanced speaking completion.
              if (!_hasAttemptedGeneralQuiz) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Professional Standards & Medical Assessment',
                  _hasCompletedAdvancedFluencyQuiz
                      ? 'Mandatory for all interpreters'
                      : 'Unlocks after Interpreting Mock Test',
                ),
                const SizedBox(height: 12),
                _buildQuizCard(
                  title: 'Start Assessment',
                  icon: Icons.school,
                  iconColor: Colors.blue,
                  isLocked: !_hasCompletedAdvancedFluencyQuiz,
                  onTap:
                      _hasCompletedAdvancedFluencyQuiz
                          ? () => _takeQuiz('general')
                          : null,
                ),
              ],


        
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
            child:const  Icon(
              Icons.verified_user_rounded,
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
      totalRequired = 2 ;
      completed =
          (_hasAttemptedGeneralQuiz ? 1 : 0) +
          (_hasCompletedAdvancedFluencyQuiz ? 1 : 0) ;
    } else {
      totalRequired = 2;
      completed =
          (_hasAttemptedGeneralQuiz ? 1 : 0) +
          (_hasCompletedAdvancedFluencyQuiz ? 1 : 0);
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

  // Widget _buildLearningOfferCard() {
  //   return Container(
  //     padding: const EdgeInsets.all(22),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: const Color(0xFFE2E8F0)),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Container(
  //               width: 48,
  //               height: 48,
  //               decoration: BoxDecoration(
  //                 color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: const Icon(
  //                 Icons.school_rounded,
  //                 color: Color(0xFF1D4ED8),
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             const Expanded(
  //               child: Text(
  //                 'Keep growing as an interpreter',
  //                 style: TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.w700,
  //                   color: Color(0xFF0F172A),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 10),
  //         const Text(
  //           'Sharpen your medical and professional interpreting skills with guided courses at InterBridge Ling Academy.',
  //           style: TextStyle(
  //             fontSize: 14,
  //             height: 1.5,
  //             color: Color(0xFF475569),
  //           ),
  //         ),
  //         const SizedBox(height: 14),
  //         FilledButton.icon(
  //           onPressed: _openInterbridgeLingAcademy,
  //           icon: const Icon(Icons.open_in_new, size: 18),
  //           label: const Text('Start learning at interbridge-ling.com'),
  //           style: FilledButton.styleFrom(
  //             backgroundColor: const Color(0xFF0F172A),
  //             foregroundColor: Colors.white,
  //             padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
    }