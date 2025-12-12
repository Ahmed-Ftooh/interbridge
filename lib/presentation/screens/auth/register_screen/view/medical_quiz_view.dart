import 'dart:async';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class MedicalQuizScreen extends StatefulWidget {
  const MedicalQuizScreen({super.key});

  @override
  State<MedicalQuizScreen> createState() => _MedicalQuizScreenState();
}

class _MedicalQuizScreenState extends State<MedicalQuizScreen> {
  static const _passScore = 70;
  static const _timePerQuestion = 30; // 30 seconds per question

  final List<_MedicalQuizQuestion> _questions = const [
    _MedicalQuizQuestion(
      prompt:
          'During a remote call a nurse asks you to translate a medication dosage. What is your priority?',
      options: [
        'Translate verbatim without confirming context',
        'Clarify measurement units before relaying the dosage',
        'Skip the dosage and focus on patient comfort',
        'Ask the patient to look up the dosage later',
      ],
      correctIndex: 1,
      rationale:
          'Confirming measurement units avoids dosing errors and is required by the medical interpreter code of conduct.',
    ),
    _MedicalQuizQuestion(
      prompt:
          'A patient discloses new symptoms directly to you in Arabic while the doctor steps away. What should you do first?',
      options: [
        'Wait to mention it until the session ends',
        'Document it for yourself only',
        'Immediately interpret the message once the provider returns',
        'Offer medical advice to the patient',
      ],
      correctIndex: 2,
      rationale:
          'Interpreters must relay medically relevant information faithfully as soon as the provider is present again.',
    ),
    _MedicalQuizQuestion(
      prompt:
          'The provider uses a complex acronym the patient clearly does not understand. What is the correct protocol?',
      options: [
        'Explain the acronym yourself',
        'Ask the provider to restate or explain before interpreting',
        'Ignore it to keep the call short',
        'Translate only part of the sentence',
      ],
      correctIndex: 1,
      rationale:
          'Interpreters request clarification from the provider, then relay the clarified message without adding their own medical advice.',
    ),
  ];

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  Timer? _timer;
  int _timeLeft = _timePerQuestion;
  bool _quizStarted = false;
  bool _quizCompleted = false;
  int? _finalScore;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
      _currentQuestionIndex = 0;
      _timeLeft = _timePerQuestion;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _timePerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _nextQuestion(autoSubmit: true);
      }
    });
  }

  void _nextQuestion({bool autoSubmit = false}) {
    _timer?.cancel();

    if (autoSubmit && !_selectedAnswers.containsKey(_currentQuestionIndex)) {
      // Mark as incorrect/unanswered if time ran out
      _selectedAnswers[_currentQuestionIndex] = -1;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    int correctCount = 0;
    _selectedAnswers.forEach((index, answer) {
      if (answer == _questions[index].correctIndex) {
        correctCount++;
      }
    });

    final score = ((correctCount / _questions.length) * 100).round();

    setState(() {
      _quizCompleted = true;
      _finalScore = score;
    });
  }

  void _submitAnswer(int optionIndex) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });
    // Optional: Add a small delay before moving to next question to show selection
    Future.delayed(const Duration(milliseconds: 300), () {
      _nextQuestion();
    });
  }

  void _continue() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    args['medicalQuizPassed'] = true;
    args['medicalQuizScore'] = _finalScore;

    Navigator.of(context).pushNamed(Routes.registerRoute, arguments: args);
  }

  void _retry() {
    setState(() {
      _quizCompleted = false;
      _selectedAnswers.clear();
      _currentQuestionIndex = 0;
      _finalScore = null;
      _quizStarted = false;
    });
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
        title: const Text('Medical Competency'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSize.s24),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!_quizStarted) {
      return _buildIntro(theme);
    } else if (_quizCompleted) {
      return _buildResult(theme);
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
          'Timed Medical Quiz',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'You have $_timePerQuestion seconds per question. You need 70% to pass.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: ColorManager.textSecondary,
          ),
        ),
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
          question.prompt,
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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ColorManager.greyMedium),
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

  Widget _buildResult(ThemeData theme) {
    final passed = _finalScore! >= _passScore;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: (passed ? ColorManager.success : ColorManager.error)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            passed ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 80,
            color: passed ? ColorManager.success : ColorManager.error,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          passed ? 'Congratulations!' : 'Test Failed',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          passed
              ? 'You scored $_finalScore%. You are ready to proceed.'
              : 'You scored $_finalScore%. You need 70% to pass.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: ColorManager.textSecondary,
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: passed ? _continue : _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  passed ? ColorManager.primary2 : ColorManager.greyDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              passed ? 'Continue Registration' : 'Try Again',
              style: const TextStyle(
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
}

class _MedicalQuizQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String rationale;

  const _MedicalQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.rationale,
  });
}
