import 'dart:async';
import 'package:flutter/material.dart';
import 'package:interbridge/data/models/quiz_question.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class QuizScreen extends StatefulWidget {
  final String quizType; // 'general' or 'medical'
  final String? medicalSection; // Required if quizType is 'medical'
  final bool isRequired; // Part of onboarding vs optional certification

  const QuizScreen({
    super.key,
    required this.quizType,
    this.medicalSection,
    this.isRequired = true,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _supabase = SupabaseService();
  static const _passScore = 85;
  static const _medicalBadgeScore = 85;
  static const _generalTimePerQuestion = 15;
  static const _medicalTimePerQuestion = 25;

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
  String _friendlyQuizSaveError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('jwt') ||
        message.contains('token') ||
        message.contains('auth')) {
      return 'Your session expired. Please sign in again.';
    }
    return 'Could not save quiz results right now. Please try again.';
  }
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
      debugPrint(
        'Loading quiz questions: type=${widget.quizType}, section=${widget.medicalSection}',
      );
      final data = await _supabase.getQuizQuestions(
        quizType: widget.quizType,
        medicalSection: widget.medicalSection,
      );
      debugPrint('Loaded ${data.length} questions');
      setState(() {
        _questions = data.map((q) => QuizQuestion.fromJson(q)).toList();
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading questions: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load questions: $e')));
      }
    }
  }

  void _startQuiz() {
    // Required onboarding quizzes must be retakable immediately so users
    // can continue registration after a failed attempt.
    // Mobile screen already allows direct retake by design.
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

    // If time ran out, mark as skipped (don't count against score)
    if (autoSubmit && !_selectedAnswers.containsKey(_currentQuestionIndex)) {
      _selectedAnswers[_currentQuestionIndex] = -1; // -1 = skipped/timeout
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    if (_quizCompleted) return;

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

    // Submit to backend
    try {
      final user = _supabase.getCurrentUser();
      if (user == null) {
        throw Exception('Not authenticated');
      }

      debugPrint('Submitting quiz attempt for user: ${user.id}');

      // Convert answers map to have string keys for JSON compatibility
      final answersJson = _selectedAnswers.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      // Save quiz attempt
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
      debugPrint('Quiz attempt saved successfully');

      // Award badge if passed
      if (passed) {
        final badgeType =
            widget.quizType == 'general'
                ? 'general'
                : widget.medicalSection ?? 'general_medical';
        try {
          await _supabase.awardBadge(
            userId: user.id,
            badge: badgeType,
            score: score,
          );
          debugPrint('Badge awarded: $badgeType with score $score');
        } catch (badgeError) {
          debugPrint('Quiz saved but badge award failed: $badgeError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quiz saved, but badge sync is pending.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to submit quiz attempt: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyQuizSaveError(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    // Auto-navigate back without showing a result screen
    if (mounted) {
      _continueToNext();
    }
  }

  void _submitAnswer(int optionIndex) {
    if (_quizCompleted) return;
    if (_selectedAnswers.containsKey(_currentQuestionIndex)) return;

    setState(() => _selectedAnswers[_currentQuestionIndex] = optionIndex);
    Future.delayed(const Duration(milliseconds: 300), () => _nextQuestion());
  }

  void _continueToNext() {
    final isMedical = widget.quizType == 'medical';
    final threshold = isMedical ? _medicalBadgeScore : _passScore;
    final passed = _finalScore! >= threshold;

    Navigator.of(context).pop(<String, dynamic>{
      'passed': passed,
      'score': _finalScore,
      'quizType': widget.quizType,
      'medicalSection': widget.medicalSection,
    });
  }

  /// Show confirmation dialog when user tries to leave during an active quiz
  Future<bool> _confirmExit() async {
    if (!_quizStarted || _quizCompleted) {
      return true; // Allow exit before quiz starts or after completion
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Quiz?'),
            content: const Text(
              'If you leave now, your progress will be lost and this will count as an attempt. Are you sure you want to exit?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionName =
        widget.medicalSection?.replaceAll('_', ' ').toUpperCase() ?? '';
    final title =
        widget.quizType == 'general'
            ? 'General Interpreter Quiz'
            : 'Medical Quiz - $sectionName';

    return PopScope(
      canPop: !_quizStarted,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _quizStarted && !_quizCompleted) {
          final shouldPop = await _confirmExit();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: ColorManager.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () async {
              if (_quizCompleted) return;
              if (_quizStarted) {
                final shouldPop = await _confirmExit();
                if (shouldPop && mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(title),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s24),
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _questions.isEmpty
                    ? Center(
                      child: Text(
                        'No questions available',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                    : _buildBody(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!_quizStarted) {
      return _buildIntro(theme);
    } else if (_quizCompleted) {
      // Quiz finished — _finishQuiz already auto-navigates.
      // Show a brief loading indicator while navigation completes.
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ColorManager.primary2),
            const SizedBox(height: 16),
            Text(
              'Saving results...',
              style: TextStyle(color: ColorManager.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    } else {
      return _buildQuestion(theme);
    }
  }

  Widget _buildIntro(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: ColorManager.primary2.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.timer_outlined,
            size: 60,
            color: ColorManager.primary2,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Timed Quiz',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.medicalSection != null)
          Text(
            widget.medicalSection!.replaceAll('_', ' ').toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: ColorManager.primary2,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          '${_questions.length} questions • $_timePerQuestion seconds each',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: ColorManager.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primary2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Start Quiz',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(ThemeData theme) {
    final question = _questions[_currentQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${_questions.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: ColorManager.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _timeLeft < 10
                        ? ColorManager.error.withValues(alpha: 0.1)
                        : ColorManager.primary2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color:
                        _timeLeft < 10
                            ? ColorManager.error
                            : ColorManager.primary2,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_timeLeft}s',
                    style: TextStyle(
                      color:
                          _timeLeft < 10
                              ? ColorManager.error
                              : ColorManager.primary2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          backgroundColor: ColorManager.greyLight,
          valueColor: AlwaysStoppedAnimation<Color>(ColorManager.primary2),
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 32),
        Text(
          question.questionText,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: question.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final optionLabel = ['A', 'B', 'C', 'D'][index];
              return InkWell(
                onTap: () => _submitAnswer(index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: ColorManager.greyMedium),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ColorManager.primary2,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            optionLabel,
                            style: TextStyle(
                              color: ColorManager.primary2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          question.options[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
