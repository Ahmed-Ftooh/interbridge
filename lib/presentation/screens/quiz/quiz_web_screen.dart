import 'dart:async';
import 'package:flutter/material.dart';
import 'package:interbridge/data/models/quiz_question.dart';
import 'package:interbridge/data/services/supabase_service.dart';

/// Web version of the quiz screen with professional styling.
/// Handles both general and medical quizzes with timer, scoring, and badges.
class QuizWebScreen extends StatefulWidget {
  final String quizType; // 'general' or 'medical'
  final String? medicalSection;
  final bool isRequired;

  const QuizWebScreen({
    super.key,
    required this.quizType,
    this.medicalSection,
    this.isRequired = true,
  });

  @override
  State<QuizWebScreen> createState() => _QuizWebScreenState();
}

class _QuizWebScreenState extends State<QuizWebScreen> {
  final _supabase = SupabaseService();
  static const _passScore = 85;
  static const _medicalBadgeScore = 85;
  static const _generalTimePerQuestion = 25;
  static const _medicalTimePerQuestion = 30;

  List<QuizQuestion> _questions = [];
  bool _loading = true;
  bool _quizStarted = false;
  bool _quizCompleted = false;

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  Timer? _timer;
  late int _timePerQuestion;
  late int _timeLeft;
  int? _finalScore;
  int _totalTimeSpent = 0;

  @override
  void initState() {
    super.initState();
    _timePerQuestion =
        widget.quizType == 'general'
            ? _generalTimePerQuestion
            : _medicalTimePerQuestion;
    _timeLeft = _timePerQuestion;
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await _supabase.getQuizQuestions(
        quizType: widget.quizType,
        medicalSection: widget.medicalSection,
      );
      setState(() {
        _questions = data.map((q) => QuizQuestion.fromJson(q)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load questions: $e')));
      }
    }
  }

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
      _currentQuestionIndex = 0;
      _timeLeft = _timePerQuestion;
      _totalTimeSpent = 0;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _timePerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
          _totalTimeSpent++;
        });
      } else {
        _nextQuestion(autoSubmit: true);
      }
    });
  }

  void _nextQuestion({bool autoSubmit = false}) {
    _timer?.cancel();

    if (autoSubmit && !_selectedAnswers.containsKey(_currentQuestionIndex)) {
      _selectedAnswers[_currentQuestionIndex] = -1; // skipped / timeout
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();

    int correctCount = 0;
    _selectedAnswers.forEach((index, answer) {
      if (answer == _questions[index].correctIndex) {
        correctCount++;
      }
    });

    final score = ((correctCount / _questions.length) * 100).round();
    final passed =
        widget.quizType == 'medical'
            ? score >= _medicalBadgeScore
            : score >= _passScore;

    setState(() {
      _quizCompleted = true;
      _finalScore = score;
    });

    try {
      final user = _supabase.getCurrentUser();
      if (user != null) {
        final answersJson = _selectedAnswers.map(
          (key, value) => MapEntry(key.toString(), value),
        );

        await _supabase.submitQuizAttempt({
          'user_id': user.id,
          'quiz_type': widget.quizType,
          if (widget.medicalSection != null)
            'medical_section': widget.medicalSection,
          'total_questions': _questions.length,
          'correct_answers': correctCount,
          'score_percentage': score.toDouble(),
          'time_taken_seconds': _totalTimeSpent,
          'passed': passed,
          'answers': answersJson,
        });

        if (passed) {
          final badgeType =
              widget.quizType == 'general'
                  ? 'general'
                  : widget.medicalSection ?? 'general_medical';
          await _supabase.awardBadge(
            userId: user.id,
            badge: badgeType,
            score: score,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to submit quiz attempt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save quiz results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _submitAnswer(int optionIndex) {
    setState(() => _selectedAnswers[_currentQuestionIndex] = optionIndex);
    Future.delayed(const Duration(milliseconds: 300), () => _nextQuestion());
  }

  void _continueToNext() {
    final isMedical = widget.quizType == 'medical';
    final threshold = isMedical ? _medicalBadgeScore : _passScore;
    final passed = _finalScore! >= threshold;

    Navigator.of(context).pop({
      'passed': passed,
      'score': _finalScore,
      'quizType': widget.quizType,
      'medicalSection': widget.medicalSection,
    });
  }

  Future<bool> _confirmExit() async {
    if (!_quizStarted || _quizCompleted) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Leave Quiz?',
              style: TextStyle(color: Color(0xFF0F172A)),
            ),
            content: const Text(
              'If you leave now, your progress will be lost and this will count as an attempt.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Stay',
                  style: TextStyle(color: Color(0xFF3B82F6)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final sectionName =
        widget.medicalSection?.replaceAll('_', ' ').toUpperCase() ?? '';
    final title =
        widget.quizType == 'general'
            ? 'General Interpreter Quiz'
            : 'Medical Quiz — $sectionName';

    return PopScope(
      canPop: !_quizStarted || _quizCompleted,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _quizStarted && !_quizCompleted) {
          final shouldPop = await _confirmExit();
          if (shouldPop && mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    children: [
                      if (!_quizStarted || _quizCompleted)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () async {
                            if (_quizStarted && !_quizCompleted) {
                              final shouldPop = await _confirmExit();
                              if (shouldPop && mounted) {
                                Navigator.of(context).pop();
                              }
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // balance the back button
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Body
                  Expanded(
                    child:
                        _loading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF0F172A),
                              ),
                            )
                            : _questions.isEmpty
                            ? const Center(
                              child: Text(
                                'No questions available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            )
                            : _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_quizStarted) {
      return _buildIntro();
    } else if (_quizCompleted) {
      return _buildResult();
    } else {
      return _buildQuestion();
    }
  }

  Widget _buildIntro() {
    final isMedical = widget.quizType == 'medical';
    final threshold = isMedical ? _medicalBadgeScore : _passScore;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.timer_outlined,
            size: 56,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Timed Quiz',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.medicalSection != null)
          Text(
            widget.medicalSection!.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          '${_questions.length} questions  •  $_timePerQuestion seconds each',
          style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Text(
          isMedical
              ? 'Score $threshold%+ to earn badge'
              : 'Score $threshold%+ to pass',
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: 280,
          height: 52,
          child: ElevatedButton(
            onPressed: _startQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start Quiz',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question counter + timer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1} / ${_questions.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _timeLeft < 10
                        ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                        : const Color(0xFF3B82F6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color:
                        _timeLeft < 10
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_timeLeft}s',
                    style: TextStyle(
                      color:
                          _timeLeft < 10
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3B82F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 32),

        // Question text
        Text(
          question.questionText,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Options
        Expanded(
          child: ListView.separated(
            itemCount: question.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final optionLabel = ['A', 'B', 'C', 'D'][index];
              final isSelected =
                  _selectedAnswers[_currentQuestionIndex] == index;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => _submitAnswer(index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.06)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isSelected
                                    ? const Color(0xFF3B82F6)
                                    : Colors.transparent,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF94A3B8),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              optionLabel,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            question.options[index],
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final isMedical = widget.quizType == 'medical';
    final threshold = isMedical ? _medicalBadgeScore : _passScore;
    final passed = _finalScore! >= threshold;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color:
                passed
                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            passed ? Icons.check_circle_outline : Icons.info_outline,
            size: 72,
            color: passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          passed
              ? isMedical
                  ? 'Badge Earned!'
                  : 'Congratulations!'
              : 'Section Complete',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You scored $_finalScore%',
          style: TextStyle(
            fontSize: 24,
            color: passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          passed
              ? isMedical
                  ? 'You earned the ${widget.medicalSection?.replaceAll('_', ' ')} badge!'
                  : 'You passed the quiz!'
              : isMedical
              ? 'You needed $threshold% to earn this badge. Moving to next section.'
              : 'You needed $threshold% to pass.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 44),
        SizedBox(
          width: 280,
          height: 52,
          child: ElevatedButton(
            onPressed: _continueToNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
