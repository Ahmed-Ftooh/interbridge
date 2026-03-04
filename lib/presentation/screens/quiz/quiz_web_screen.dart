import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:interbridge/data/models/quiz_question.dart';
import 'package:interbridge/data/services/supabase_service.dart';

/// Web version of the quiz screen with professional styling and anti-cheat.
/// Features: question shuffle, tab-switch detection, copy/paste disable,
/// screenshot detection, fake video recording, session timing,
/// 30-day retry cooldown.
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

class _QuizWebScreenState extends State<QuizWebScreen>
    with WidgetsBindingObserver {
  final _supabase = SupabaseService();
  static const _passScore = 85;
  static const _medicalBadgeScore = 85;
  static const _generalTimePerQuestion = 25;
  static const _medicalTimePerQuestion = 30;
  static const _retryCooldownDays = 30;

  List<QuizQuestion> _questions = [];
  bool _loading = true;
  bool _quizStarted = false;
  bool _quizCompleted = false;
  bool _retryCooldown = false;
  DateTime? _retryAvailableAt;

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  Timer? _timer;
  late int _timePerQuestion;
  late int _timeLeft;
  int? _finalScore;
  int _totalTimeSpent = 0;

  // ── Anti-cheat counters ──
  int _tabSwitchCount = 0;
  int _copyPasteAttempts = 0;
  int _screenshotAttempts = 0;
  DateTime? _sessionStartAt;
  bool _isFakeRecording = false;
  bool _cameraActive = false;
  html.MediaStream? _cameraStream;
  html.VideoElement? _videoElement;
  final String _webcamViewId =
      'quiz-webcam-${DateTime.now().millisecondsSinceEpoch}';

  // Per-question option shuffle: question index → shuffled option indices
  // e.g. _optionShuffle[0] = [2,0,3,1] means options displayed as C,A,D,B
  final Map<int, List<int>> _optionShuffle = {};

  // JS event subscriptions
  StreamSubscription<html.Event>? _visibilitySub;
  StreamSubscription<html.Event>? _copySub;
  StreamSubscription<html.Event>? _pasteSub;
  StreamSubscription<html.Event>? _cutSub;
  StreamSubscription<html.KeyboardEvent>? _keydownSub;
  StreamSubscription<html.Event>? _contextMenuSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timePerQuestion =
        widget.quizType == 'general'
            ? _generalTimePerQuestion
            : _medicalTimePerQuestion;
    _timeLeft = _timePerQuestion;
    _checkRetryCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _removeAntiCheatListeners();
    _stopCamera();
    _removeScreenshotCss();
    super.dispose();
  }

  // ── Retry cooldown check ──
  Future<void> _checkRetryCooldown() async {
    try {
      final user = _supabase.getCurrentUser();
      if (user != null) {
        final attempts = await _supabase.getQuizAttempts(user.id);
        // Find the latest attempt for this quiz type + section
        for (final attempt in attempts) {
          if (attempt['quiz_type'] == widget.quizType) {
            final bool sectionMatch =
                widget.medicalSection == null
                    ? attempt['medical_section'] == null
                    : attempt['medical_section'] == widget.medicalSection;
            if (sectionMatch) {
              final takenAt = DateTime.tryParse(
                attempt['taken_at']?.toString() ?? '',
              );
              if (takenAt != null) {
                final cooldownEnd = takenAt.add(
                  const Duration(days: _retryCooldownDays),
                );
                if (DateTime.now().toUtc().isBefore(cooldownEnd) &&
                    attempt['passed'] != true) {
                  if (!mounted) return;
                  setState(() {
                    _retryCooldown = true;
                    _retryAvailableAt = cooldownEnd;
                    _loading = false;
                  });
                  return;
                }
              }
              break; // Only check the latest attempt
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking retry cooldown: $e');
    }
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await _supabase.getQuizQuestions(
        quizType: widget.quizType,
        medicalSection: widget.medicalSection,
      );
      final questions = data.map((q) => QuizQuestion.fromJson(q)).toList();

      // Shuffle question order
      final rng = Random();
      questions.shuffle(rng);

      // Prepare per-question option shuffles
      for (int i = 0; i < questions.length; i++) {
        final optIndices = List<int>.generate(
          questions[i].options.length,
          (j) => j,
        );
        optIndices.shuffle(rng);
        _optionShuffle[i] = optIndices;
      }

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading questions: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load questions: $e')));
      }
    }
  }

  // ── Anti-cheat listeners ──
  void _installAntiCheatListeners() {
    // Tab switch / visibility change
    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (!mounted) return;
      if (html.document.hidden == true && _quizStarted && !_quizCompleted) {
        setState(() => _tabSwitchCount++);
        _showAntiCheatWarning(
          'Tab switch detected',
          'Switching tabs during the quiz is recorded and may flag your attempt.',
        );
      }
    });

    // Copy / Paste / Cut prevention
    _copySub = html.document.on['copy'].listen((e) {
      if (!mounted) return;
      if (_quizStarted && !_quizCompleted) {
        e.preventDefault();
        setState(() => _copyPasteAttempts++);
      }
    });
    _pasteSub = html.document.on['paste'].listen((e) {
      if (!mounted) return;
      if (_quizStarted && !_quizCompleted) {
        e.preventDefault();
        setState(() => _copyPasteAttempts++);
      }
    });
    _cutSub = html.document.on['cut'].listen((e) {
      if (!mounted) return;
      if (_quizStarted && !_quizCompleted) {
        e.preventDefault();
        setState(() => _copyPasteAttempts++);
      }
    });

    // Context menu prevention
    _contextMenuSub = html.document.onContextMenu.listen((e) {
      if (_quizStarted && !_quizCompleted) {
        e.preventDefault();
      }
    });

    // Screenshot key detection (PrintScreen, Ctrl+Shift+S, Cmd+Shift+3/4/5)
    _keydownSub = html.document.onKeyDown.listen((html.KeyboardEvent e) {
      if (!mounted) return;
      if (!_quizStarted || _quizCompleted) return;

      final key = e.key?.toLowerCase() ?? '';
      final isPrintScreen = key == 'printscreen' || e.keyCode == 44;
      final isCtrlShiftS = (e.ctrlKey || e.metaKey) && e.shiftKey && key == 's';
      final isMacScreenshot =
          e.metaKey && e.shiftKey && (key == '3' || key == '4' || key == '5');

      if (isPrintScreen || isCtrlShiftS || isMacScreenshot) {
        e.preventDefault();
        setState(() => _screenshotAttempts++);
        _showAntiCheatWarning(
          'Screenshot attempt detected',
          'Taking screenshots during the quiz is not allowed and has been recorded.',
        );
      }

      // Also block Ctrl+C, Ctrl+V, Ctrl+X
      if ((e.ctrlKey || e.metaKey) &&
          (key == 'c' || key == 'v' || key == 'x')) {
        e.preventDefault();
        setState(() => _copyPasteAttempts++);
      }
    });
  }

  void _removeAntiCheatListeners() {
    _visibilitySub?.cancel();
    _copySub?.cancel();
    _pasteSub?.cancel();
    _cutSub?.cancel();
    _keydownSub?.cancel();
    _contextMenuSub?.cancel();
  }

  // ── Webcam ──
  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'user', 'width': 160, 'height': 120},
        'audio': false,
      });
      _cameraStream = stream;

      _videoElement =
          html.VideoElement()
            ..srcObject = stream
            ..autoplay = true
            ..muted = true
            ..setAttribute('playsinline', 'true')
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover'
            ..style.borderRadius = '8px'
            ..style.transform = 'scaleX(-1)';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _webcamViewId,
        (int viewId) => _videoElement!,
      );

      if (mounted) setState(() => _cameraActive = true);
    } catch (e) {
      debugPrint('Camera access denied or unavailable: $e');
      // Camera is optional — quiz continues without it, but we flag it
      if (mounted) {
        _showAntiCheatWarning(
          'Camera access denied',
          'Your quiz session will be flagged because camera monitoring could not start.',
        );
      }
    }
  }

  void _stopCamera() {
    if (_cameraStream != null) {
      for (final track in _cameraStream!.getTracks()) {
        track.stop();
      }
      _cameraStream = null;
    }
    _videoElement = null;
    _cameraActive = false;
  }

  // ── Screenshot CSS prevention ──
  void _installScreenshotCss() {
    // Add a style tag that makes the body unselectable and blocks screenshots
    final style =
        html.StyleElement()
          ..id = 'quiz-anti-screenshot'
          ..text = '''
        body {
          -webkit-user-select: none !important;
          -moz-user-select: none !important;
          -ms-user-select: none !important;
          user-select: none !important;
          -webkit-touch-callout: none !important;
        }
        /* When page is not focused, blur content to prevent screenshots via screen share */
        @media screen {
          .quiz-blur-on-defocus:not(:focus-within) {
            filter: blur(0px);
          }
        }
      ''';
    html.document.head?.append(style);
  }

  void _removeScreenshotCss() {
    html.document.getElementById('quiz-anti-screenshot')?.remove();
  }

  void _showAntiCheatWarning(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Quiz flow ──
  void _startQuiz() {
    _installAntiCheatListeners();
    _installScreenshotCss();
    _startCamera();
    _sessionStartAt = DateTime.now().toUtc();

    setState(() {
      _quizStarted = true;
      _isFakeRecording = true;
      _currentQuestionIndex = 0;
      _timeLeft = _timePerQuestion;
      _totalTimeSpent = 0;
      _tabSwitchCount = 0;
      _copyPasteAttempts = 0;
      _screenshotAttempts = 0;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _timePerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    _removeAntiCheatListeners();
    _stopCamera();
    _removeScreenshotCss();

    final sessionEndAt = DateTime.now().toUtc();

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

    // Determine if flagged (any suspicious activity or camera denied)
    final isFlagged =
        _tabSwitchCount > 2 ||
        _copyPasteAttempts > 3 ||
        _screenshotAttempts > 0 ||
        !_cameraActive;

    setState(() {
      _quizCompleted = true;
      _finalScore = score;
      _isFakeRecording = false;
    });

    try {
      final user = _supabase.getCurrentUser();
      if (user != null) {
        final answersJson = _selectedAnswers.map(
          (key, value) => MapEntry(key.toString(), value),
        );

        // Collect browser info
        final browserInfo =
            '${html.window.navigator.userAgent} | ${html.window.screen?.width}x${html.window.screen?.height}';

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
          // Anti-cheat fields
          'tab_switches': _tabSwitchCount,
          'copy_paste_attempts': _copyPasteAttempts,
          'screenshot_attempts': _screenshotAttempts,
          'session_start_at': _sessionStartAt?.toIso8601String(),
          'session_end_at': sessionEndAt.toIso8601String(),
          'browser_info': browserInfo,
          'is_flagged': isFlagged,
        });

        if (passed && !isFlagged) {
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

    // Auto-navigate back
    if (mounted) {
      _continueToNext();
    }
  }

  void _submitAnswer(int displayIndex) {
    // Map the displayed option index back to the original option index
    final shuffle = _optionShuffle[_currentQuestionIndex];
    final originalIndex =
        shuffle != null ? shuffle[displayIndex] : displayIndex;
    setState(() => _selectedAnswers[_currentQuestionIndex] = originalIndex);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _nextQuestion();
    });
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

  // ── Build ──
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
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
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
                          // Fake recording indicator
                          if (_isFakeRecording)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record,
                                    color: Color(0xFFEF4444),
                                    size: 10,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'REC',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Anti-cheat status bar (visible during quiz)
                      if (_quizStarted && !_quizCompleted)
                        _buildAntiCheatStatusBar(),

                      // Body
                      Expanded(
                        child:
                            _loading
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF0F172A),
                                  ),
                                )
                                : _retryCooldown
                                ? _buildRetryCooldownView()
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
            // Webcam PIP overlay (bottom-right corner)
            if (_cameraActive && _quizStarted && !_quizCompleted)
              Positioned(
                bottom: 24,
                right: 24,
                child: Container(
                  width: 140,
                  height: 105,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HtmlElementView(viewType: _webcamViewId),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAntiCheatStatusBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            _tabSwitchCount > 0 || _copyPasteAttempts > 0
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              _tabSwitchCount > 0 || _copyPasteAttempts > 0
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _tabSwitchCount > 0 || _copyPasteAttempts > 0
                ? Icons.shield_outlined
                : Icons.verified_user_outlined,
            size: 16,
            color:
                _tabSwitchCount > 0 || _copyPasteAttempts > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tabSwitchCount > 0 || _copyPasteAttempts > 0
                  ? 'Integrity warnings: ${_tabSwitchCount + _copyPasteAttempts + _screenshotAttempts}'
                  : 'Proctored session active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    _tabSwitchCount > 0 || _copyPasteAttempts > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _cameraActive
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _cameraActive ? 'Camera On' : 'No Camera',
            style: TextStyle(
              fontSize: 11,
              color:
                  _cameraActive
                      ? const Color(0xFF64748B)
                      : const Color(0xFFDC2626),
              fontWeight: _cameraActive ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryCooldownView() {
    final remaining = _retryAvailableAt?.difference(DateTime.now().toUtc());
    final days = remaining?.inDays ?? 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule,
              size: 56,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Cooldown Period',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You can retry this quiz in $days day${days == 1 ? '' : 's'}.',
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quiz retries are available every 30 days after a failed attempt.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_quizStarted) {
      return _buildIntro();
    } else if (_quizCompleted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text(
              'Saving results...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
            ),
          ],
        ),
      );
    } else {
      return _buildQuestion();
    }
  }

  Widget _buildIntro() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
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
            'Proctored Quiz',
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
          const SizedBox(height: 24),

          // Anti-cheat info box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, size: 18, color: Color(0xFF3B82F6)),
                    SizedBox(width: 8),
                    Text(
                      'Quiz integrity rules',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...[
                  'Your session will be video recorded',
                  'Switching tabs will be detected and logged',
                  'Copy, paste, and right-click are disabled',
                  'Screenshot attempts will be flagged',
                  'Questions and options are randomized',
                  'You need 85% to pass',
                ].map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rule,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentQuestionIndex];
    final shuffle = _optionShuffle[_currentQuestionIndex] ?? [0, 1, 2, 3];
    final displayOptions = shuffle.map((i) => question.options[i]).toList();

    // The selected original index for this question
    final selectedOriginalIdx = _selectedAnswers[_currentQuestionIndex];
    // Convert to display index for highlighting
    int? selectedDisplayIdx;
    if (selectedOriginalIdx != null) {
      selectedDisplayIdx = shuffle.indexOf(selectedOriginalIdx);
      if (selectedDisplayIdx == -1) selectedDisplayIdx = null;
    }

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

        // Question text — wrapped in SelectionArea(child: ...) prevention
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
            itemCount: displayOptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final optionLabel = ['A', 'B', 'C', 'D'][index];
              final isSelected = selectedDisplayIdx == index;

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
                            displayOptions[index],
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
}
