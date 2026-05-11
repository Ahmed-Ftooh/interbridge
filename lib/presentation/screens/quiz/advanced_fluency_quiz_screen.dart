import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/core/io_helpers/read_file_bytes.dart'
    if (dart.library.io) 'package:interbridge/core/io_helpers/read_file_bytes_io.dart'
    as file_bytes;
import 'package:interbridge/core/web_helpers/inline_audio_player.dart'
    if (dart.library.html) 'package:interbridge/core/web_helpers/inline_audio_player_web.dart'
    as inline_audio;
import 'package:interbridge/core/web_helpers/fetch_blob_bytes.dart'
    if (dart.library.html) 'package:interbridge/core/web_helpers/fetch_blob_bytes_web.dart'
    as blob_helper;
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdvancedFluencyQuizScreen extends StatefulWidget {
  const AdvancedFluencyQuizScreen({super.key});

  @override
  State<AdvancedFluencyQuizScreen> createState() =>
      _AdvancedFluencyQuizScreenState();
}

class _AdvancedFluencyQuizScreenState extends State<AdvancedFluencyQuizScreen> {
  static const int _maxListeningPlays = 1;

  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _recordingPlayer;
  late final AudioPlayer _listeningPlayer;
  inline_audio.InlineAudioHandle? _webListeningHandle;

  bool _hasPermission = false;
  bool _isRecording = false;
  bool _isPlayingRecording = false;
  bool _isPlayingListeningAudio = false;
  bool _isSubmitting = false;
  bool _isLoadingQuestions = true;

  int _currentQuestionIndex = 0;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _activeListeningQuestionId;

  final Map<String, _RecordedAnswer> _recordings = {};
  final Map<String, int> _listeningStarts = {};

  late List<_FluencyQuestion> _questions;

  static const List<_FluencyQuestion> _baseQuestions = [
    _FluencyQuestion(
      id: 's1_q1',
      sectionTitle: 'Section 1 - Listening & Comprehension Check',
      questionTitle: 'Question 1',
      prompt: 'Describe the picture in detail.',
      guidePrompts: [
        'Describe the overall scene and what is happening',
        'What is the condition of the car and where is the driver?',
        'How are the medical personnel interacting with the injured driver?',
      ],
      suggestedSeconds: 90,
      imageAsset: ImageAssets.picture2,
    ),
    _FluencyQuestion(
      id: 's1_q2',
      sectionTitle: 'Section 1 - Listening & Comprehension Check',
      questionTitle: 'Question 2',
      prompt: 'Summarize what the speaker said in your own words.',
      guidePrompts: [
        'Listen to the provided audio first',
        'Give a clear summary',
      ],
      suggestedSeconds: 75,
      listeningAudioAsset: AudioAssets.test1,
    ),
    _FluencyQuestion(
      id: 's2_q1_native',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 1 (Native Language)',
      prompt:
          'You will hear a short audio recording. Please listen carefully and take notes.\n\nPlease interpret the message into your native language.',
      guidePrompts: ['Listen and take notes', 'Interpret to native language'],
      suggestedSeconds: 120,
      listeningAudioAsset: AudioAssets.audioTest1,
    ),
    _FluencyQuestion(
      id: 's2_q1_english',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 1 (English)',
      prompt:
          'Based on the previous recording and your notes, please repeat the message in English.',
      guidePrompts: ['Repeat in English'],
      suggestedSeconds: 120,
    ),
    _FluencyQuestion(
      id: 's2_q2_native',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 2 (Native Language)',
      prompt:
          'You will hear a short audio recording. Please listen carefully and take notes.\n\nPlease interpret the message into your native language.',
      guidePrompts: ['Listen and take notes', 'Interpret to native language'],
      suggestedSeconds: 120,
      listeningAudioAsset: AudioAssets.audioTest2,
    ),
    _FluencyQuestion(
      id: 's2_q2_english',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 2 (English)',
      prompt:
          'Based on the previous recording and your notes, please repeat the message in English.',
      guidePrompts: ['Repeat in English'],
      suggestedSeconds: 120,
    ),
    _FluencyQuestion(
      id: 's2_q3_native',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 3 (Native Language)',
      prompt:
          'You will hear a short audio recording. Please listen carefully and take notes.\n\nPlease interpret the message into your native language.',
      guidePrompts: ['Listen and take notes', 'Interpret to native language'],
      suggestedSeconds: 120,
      listeningAudioAsset: AudioAssets.audioTest3,
    ),
    _FluencyQuestion(
      id: 's2_q3_english',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 3 (English)',
      prompt:
          'Based on the previous recording and your notes, please repeat the message in English.',
      guidePrompts: ['Repeat in English'],
      suggestedSeconds: 120,
    ),
    _FluencyQuestion(
      id: 's2_q4_native',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 4 (Native Language)',
      prompt:
          'You will hear a short audio recording. Please listen carefully and take notes.\n\nPlease interpret the message into your native language.',
      guidePrompts: ['Listen and take notes', 'Interpret to native language'],
      suggestedSeconds: 120,
      listeningAudioAsset: AudioAssets.audioTest4,
    ),
    _FluencyQuestion(
      id: 's2_q4_english',
      sectionTitle: 'Section 2 - Interpretation Simulation',
      questionTitle: 'Task 4 (English)',
      prompt:
          'Based on the previous recording and your notes, please repeat the message in English.',
      guidePrompts: ['Repeat in English'],
      suggestedSeconds: 120,
    ),
  ];

  _FluencyQuestion get _currentQuestion => _questions[_currentQuestionIndex];

  _RecordedAnswer? get _currentAnswer => _recordings[_currentQuestion.id];

  @override
  void initState() {
    super.initState();
    _questions = List.of(_baseQuestions);
    _audioRecorder = AudioRecorder();
    _recordingPlayer = AudioPlayer();
    _listeningPlayer = AudioPlayer();

    _recordingPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlayingRecording = false);
      }
    });

    _listeningPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingListeningAudio = false;
          if (_activeListeningQuestionId != null) {
            _listeningStarts[_activeListeningQuestionId!] = _maxListeningPlays;
          }
        });
      }
    });

    _checkMicrophonePermission();
    _initializeQuestions();
  }

  Future<void> _initializeQuestions() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final supabaseService = instance<SupabaseService>();
      final interpreterLanguages = await supabaseService.getInterpreterLanguages(userId);

      bool isArabic = false;
      bool isSpanish = false;

      for (var lang in interpreterLanguages) {
        // Arabic language IDs (4 to 12)
        if (lang.languageId >= 4 && lang.languageId <= 12) {
          isArabic = true;
        }
        // Spanish language ID (100)
        if (lang.languageId == 100) {
          isSpanish = true;
        }
      }

      if (isArabic) {
        _addLanguageSpecificQuestions('Arabic', AudioAssets.arPtAudio1, AudioAssets.arPtAudio2, AudioAssets.arPtAudio3, AudioAssets.arPtAudio4);
      } else if (isSpanish) {
        _addLanguageSpecificQuestions('Spanish', AudioAssets.spPtAudio1, AudioAssets.spPtAudio2, AudioAssets.spPtAudio3, AudioAssets.spPtAudio4);
      }
    } catch (e) {
      // Ignored for now, base questions will be used
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQuestions = false;
        });
      }
    }
  }

  void _addLanguageSpecificQuestions(String languagePrefix, String audio1, String audio2, String audio3, String audio4) {
    _questions.addAll([
      _FluencyQuestion(
        id: 's3_q1_english',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 1 (English)',
        prompt:
            'You will hear a short audio recording in $languagePrefix. Please listen carefully and take notes.\n\nPlease interpret the message into English.',
        guidePrompts: ['Listen and take notes', 'Interpret to English'],
        suggestedSeconds: 120,
        listeningAudioAsset: audio1,
      ),
      _FluencyQuestion(
        id: 's3_q1_native',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 1 ($languagePrefix)',
        prompt:
            'Based on the previous recording and your notes, please repeat the message in $languagePrefix.',
        guidePrompts: ['Repeat in $languagePrefix'],
        suggestedSeconds: 120,
      ),
      _FluencyQuestion(
        id: 's3_q2_english',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 2 (English)',
        prompt:
            'You will hear a short audio recording in $languagePrefix. Please listen carefully and take notes.\n\nPlease interpret the message into English.',
        guidePrompts: ['Listen and take notes', 'Interpret to English'],
        suggestedSeconds: 120,
        listeningAudioAsset: audio2,
      ),
      _FluencyQuestion(
        id: 's3_q2_native',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 2 ($languagePrefix)',
        prompt:
            'Based on the previous recording and your notes, please repeat the message in $languagePrefix.',
        guidePrompts: ['Repeat in $languagePrefix'],
        suggestedSeconds: 120,
      ),
      _FluencyQuestion(
        id: 's3_q3_english',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 3 (English)',
        prompt:
            'You will hear a short audio recording in $languagePrefix. Please listen carefully and take notes.\n\nPlease interpret the message into English.',
        guidePrompts: ['Listen and take notes', 'Interpret to English'],
        suggestedSeconds: 120,
        listeningAudioAsset: audio3,
      ),
      _FluencyQuestion(
        id: 's3_q3_native',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 3 ($languagePrefix)',
        prompt:
            'Based on the previous recording and your notes, please repeat the message in $languagePrefix.',
        guidePrompts: ['Repeat in $languagePrefix'],
        suggestedSeconds: 120,
      ),
      _FluencyQuestion(
        id: 's3_q4_english',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 4 (English)',
        prompt:
            'You will hear a short audio recording in $languagePrefix. Please listen carefully and take notes.\n\nPlease interpret the message into English.',
        guidePrompts: ['Listen and take notes', 'Interpret to English'],
        suggestedSeconds: 120,
        listeningAudioAsset: audio4,
      ),
      _FluencyQuestion(
        id: 's3_q4_native',
        sectionTitle: 'Section 3 - $languagePrefix Interpretation Simulation',
        questionTitle: 'Task 4 ($languagePrefix)',
        prompt:
            'Based on the previous recording and your notes, please repeat the message in $languagePrefix.',
        guidePrompts: ['Repeat in $languagePrefix'],
        suggestedSeconds: 120,
      ),
    ]);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _recordingPlayer.dispose();
    _listeningPlayer.dispose();
    inline_audio.disposeInlineAudio(_webListeningHandle);
    super.dispose();
  }

  int _listensUsedForQuestion(String questionId) =>
      _listeningStarts[questionId] ?? 0;

  int _listensRemainingForQuestion(String questionId) {
    final remaining = _maxListeningPlays - _listensUsedForQuestion(questionId);
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _pauseListeningAudio() async {
    try {
      if (kIsWeb) {
        await inline_audio.pauseInlineAudio(_webListeningHandle);
      } else {
        await _listeningPlayer.pause();
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isPlayingListeningAudio = false);
    }
  }

  Future<void> _stopListeningAudio() async {
    try {
      if (kIsWeb) {
        await inline_audio.stopInlineAudio(_webListeningHandle);
        inline_audio.disposeInlineAudio(_webListeningHandle);
        _webListeningHandle = null;
      } else {
        await _listeningPlayer.stop();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isPlayingListeningAudio = false;
        _activeListeningQuestionId = null;
      });
    }
  }

  Future<void> _checkMicrophonePermission() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (mounted) {
        setState(() => _hasPermission = hasPermission);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasPermission = false);
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isSubmitting) {
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _hasPermission = false);
      }
      _showMessage('Microphone permission is required to record your answer.');
      return;
    }

    setState(() => _hasPermission = true);

    try {
      await _recordingPlayer.stop();
      await _pauseListeningAudio();

      if (kIsWeb) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/advanced_fluency_${_currentQuestion.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
      }

      _recordingTimer?.cancel();
      setState(() {
        _isRecording = true;
        _isPlayingRecording = false;
        _isPlayingListeningAudio = false;
        _recordingSeconds = 0;
        _recordings.remove(_currentQuestion.id);
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() => _recordingSeconds++);
      });
    } catch (e) {
      _showMessage('Unable to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      if (path == null || path.isEmpty) {
        setState(() {
          _isRecording = false;
          _recordingSeconds = 0;
        });
        _showMessage('Recording was not saved. Please try again.');
        return;
      }

      Uint8List? audioBytes;
      if (kIsWeb && path.startsWith('blob:')) {
        audioBytes = await blob_helper.fetchBlobBytes(path);
      }

      setState(() {
        _isRecording = false;
        _recordings[_currentQuestion.id] = _RecordedAnswer(
          path: path,
          bytes: audioBytes,
          durationSeconds: _recordingSeconds,
        );
      });
    } catch (e) {
      _showMessage('Unable to stop recording: $e');
    }
  }

  Future<void> _toggleRecordingPlayback() async {
    final answer = _currentAnswer;
    if (answer == null) {
      return;
    }

    try {
      if (_isPlayingRecording) {
        await _recordingPlayer.pause();
        setState(() => _isPlayingRecording = false);
        return;
      }

      final source =
          kIsWeb ? UrlSource(answer.path) : DeviceFileSource(answer.path);
      await _recordingPlayer.play(source);
      setState(() => _isPlayingRecording = true);
    } catch (e) {
      _showMessage('Unable to play recording: $e');
    }
  }

  Future<void> _toggleListeningAudio({
    required String audioAsset,
    required String questionId,
  }) async {
    try {
      if (_isPlayingListeningAudio) {
        await _pauseListeningAudio();
        return;
      }

      final usedStarts = _listensUsedForQuestion(questionId);
      if (usedStarts >= _maxListeningPlays) {
        _showMessage(
          'Listening is locked for this question. You have used your only attempt.',
        );
        return;
      }

      bool isExisting = _activeListeningQuestionId == questionId;

      if (!isExisting) {
        await _stopListeningAudio();

        if (kIsWeb) {
          _webListeningHandle = inline_audio.createInlineAudio(
            assetPath: audioAsset,
            onEnded: () {
              if (mounted) {
                setState(() {
                  _isPlayingListeningAudio = false;
                  _listeningStarts[questionId] = _maxListeningPlays;
                });
              }
            },
          );

          if (_webListeningHandle == null) {
            throw Exception('Unable to initialize web audio player');
          }
        } else {
          await _listeningPlayer.setSource(AssetSource(audioAsset));
        }

        _activeListeningQuestionId = questionId;
      }

      if (kIsWeb) {
        await inline_audio.playInlineAudio(_webListeningHandle);
      } else {
        await _listeningPlayer.resume();
      }

      if (!mounted) return;

      setState(() {
        _isPlayingListeningAudio = true;
      });
    } catch (e) {
      _showMessage('Unable to play the listening audio: $e');
    }
  }

  Future<void> _nextQuestion() async {
    if (_isSubmitting) {
      return;
    }

    if (!_recordings.containsKey(_currentQuestion.id)) {
      _showMessage('Please record your answer before continuing.');
      return;
    }

    await _recordingPlayer.stop();
    await _stopListeningAudio();

    if (_currentQuestionIndex == _questions.length - 1) {
      await _submitTest();
      return;
    }

    setState(() {
      _isPlayingRecording = false;
      _isPlayingListeningAudio = false;
      _currentQuestionIndex++;
      _recordingSeconds = _currentAnswer?.durationSeconds ?? 0;
    });
  }

  Future<void> _previousQuestion() async {
    if (_currentQuestionIndex == 0 || _isSubmitting) {
      return;
    }

    await _recordingPlayer.stop();
    await _stopListeningAudio();

    setState(() {
      _isPlayingRecording = false;
      _isPlayingListeningAudio = false;
      _currentQuestionIndex--;
      _recordingSeconds = _currentAnswer?.durationSeconds ?? 0;
    });
  }

  Future<void> _submitTest() async {
    if (_recordings.length < _questions.length) {
      final remaining = _questions.length - _recordings.length;
      _showMessage(
        'Please record all answers before submitting. ($remaining left)',
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showMessage('You must be logged in to submit the test.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;

      await client
          .from('voice_samples')
          .delete()
          .eq('user_id', userId)
          .eq('sentence_type', advancedFluencySentenceType);

      for (final question in _questions) {
        final answer = _recordings[question.id];
        if (answer == null) {
          throw Exception('Missing recording for ${question.questionTitle}');
        }

        Uint8List? bytes = answer.bytes;
        if ((bytes == null || bytes.isEmpty) && !kIsWeb) {
          bytes = await file_bytes.readFileBytes(answer.path);
        }

        if (bytes == null || bytes.isEmpty) {
          throw Exception('Could not read recording bytes for ${question.id}');
        }

        final extension = kIsWeb ? 'webm' : 'm4a';
        final storagePath =
            '$userId/advanced_fluency/${question.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

        await client.storage
            .from('voice_samples')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrl = client.storage
            .from('voice_samples')
            .getPublicUrl(storagePath);

        await client.from('voice_samples').insert({
          'user_id': userId,
          'url': publicUrl,
          'prompt':
              '${question.sectionTitle} - ${question.questionTitle}\n${question.prompt}',
          'sentence_type': advancedFluencySentenceType,
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speaking test submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage('Failed to submit speaking test: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  Widget _buildProgressHeader({
    required _FluencyQuestion question,
    required double progress,
    required bool wide,
  }) {
    return Container(
      padding: EdgeInsets.all(wide ? 20 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Suggested: ${question.suggestedSeconds}s',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.sectionTitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7DD3FC),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF38BDF8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_FluencyQuestion question) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.prompt,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF334155),
              height: 1.55,
            ),
          ),
          if (question.guidePrompts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children:
                    question.guidePrompts
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF475569),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListeningCard(_FluencyQuestion question) {
    final audioAsset = question.listeningAudioAsset;
    if (audioAsset == null) {
      return const SizedBox.shrink();
    }

    final listensUsed = _listensUsedForQuestion(question.id);
    final listensRemaining = _listensRemainingForQuestion(question.id);
    final isLocked = listensRemaining == 0 && !_isPlayingListeningAudio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed:
                    _isSubmitting || isLocked
                        ? null
                        : () => _toggleListeningAudio(
                          audioAsset: audioAsset,
                          questionId: question.id,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isLocked
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  _isPlayingListeningAudio
                      ? Icons.pause_rounded
                      : (isLocked
                          ? Icons.lock_outline
                          : Icons.play_arrow_rounded),
                ),
                label: Text(
                  _isPlayingListeningAudio
                      ? 'Pause Audio'
                      : (isLocked ? 'Audio Locked' : 'Start Listening'),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4A6E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$listensUsed/$_maxListeningPlays listens used',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0C4A6E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Audio: ${audioAsset.split('/').last}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF0C4A6E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            listensRemaining > 0
                ? 'You can listen $listensRemaining more ${listensRemaining == 1 ? 'time' : 'times'} for this question.'
                : 'Listening limit reached for this question.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard({
    required _FluencyQuestion question,
    required bool hasRecording,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              hasRecording ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!_hasPermission)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Text(
                'Microphone access is required. Please grant permission, then try recording again.',
                style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
              ),
            ),
          Tooltip(
            message: _isRecording ? 'Stop Recording' : 'Start Recording',
            child: GestureDetector(
              onTap:
                  _isSubmitting
                      ? null
                      : (_isRecording ? _stopRecording : _startRecording),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _isRecording
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0F172A),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A))
                          .withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isRecording
                ? 'Recording... ${_formatDuration(_recordingSeconds)}'
                : hasRecording
                ? 'Answer recorded (${_formatDuration(_currentAnswer!.durationSeconds)})'
                : 'Tap to start recording',
            style: TextStyle(
              fontSize: 13,
              fontWeight: _isRecording ? FontWeight.bold : FontWeight.w500,
              color:
                  _isRecording
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF475569),
            ),
          ),
          if (hasRecording && !_isRecording) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _toggleRecordingPlayback,
                  icon: Icon(
                    _isPlayingRecording
                        ? Icons.pause_circle
                        : Icons.play_circle,
                  ),
                  label: Text(
                    _isPlayingRecording ? 'Pause Playback' : 'Play Recording',
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _isSubmitting
                          ? null
                          : () {
                            setState(() {
                              _recordings.remove(question.id);
                              _isPlayingRecording = false;
                            });
                          },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        OutlinedButton(
          onPressed:
              _currentQuestionIndex == 0 || _isSubmitting
                  ? null
                  : _previousQuestion,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isRecording || _isSubmitting ? null : _nextQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      _currentQuestionIndex == _questions.length - 1
                          ? 'Submit Test'
                          : 'Next Question',
                    ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuestions) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final question = _currentQuestion;
    final hasRecording = _currentAnswer != null;
    final isWideWeb = kIsWeb && MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      backgroundColor:
          isWideWeb ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          advancedFluencyQuizTitle,
          style: TextStyle(
            fontSize: isWideWeb ? 18 : 15,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child:
            isWideWeb
                ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        children: [
                          _buildProgressHeader(
                            question: question,
                            progress: progress,
                            wide: true,
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    children: [
                                      _buildQuestionCard(question),
                                      if (question.imageAsset != null) ...[
                                        const SizedBox(height: 14),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.asset(
                                            question.imageAsset!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) {
                                              return Container(
                                                height: 260,
                                                alignment: Alignment.center,
                                                color: const Color(0xFFE2E8F0),
                                                child: const Text(
                                                  'Image could not be loaded',
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                      if (question.listeningAudioAsset !=
                                          null) ...[
                                        const SizedBox(height: 14),
                                        _buildListeningCard(question),
                                      ],
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                SizedBox(
                                  width: 390,
                                  child: Column(
                                    children: [
                                      _buildRecordingCard(
                                        question: question,
                                        hasRecording: hasRecording,
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: _buildActionRow(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildProgressHeader(
                        question: question,
                        progress: progress,
                        wide: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildQuestionCard(question),
                          if (question.imageAsset != null) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                question.imageAsset!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    height: 180,
                                    alignment: Alignment.center,
                                    color: const Color(0xFFE2E8F0),
                                    child: const Text(
                                      'Image could not be loaded',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (question.listeningAudioAsset != null) ...[
                            const SizedBox(height: 14),
                            _buildListeningCard(question),
                          ],
                          const SizedBox(height: 14),
                          _buildRecordingCard(
                            question: question,
                            hasRecording: hasRecording,
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: _buildActionRow(),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _FluencyQuestion {
  final String id;
  final String sectionTitle;
  final String questionTitle;
  final String prompt;
  final List<String> guidePrompts;
  final int suggestedSeconds;
  final String? imageAsset;
  final String? listeningAudioAsset;

  const _FluencyQuestion({
    required this.id,
    required this.sectionTitle,
    required this.questionTitle,
    required this.prompt,
    required this.guidePrompts,
    required this.suggestedSeconds,
    this.imageAsset,
    this.listeningAudioAsset,
  });
}

class _RecordedAnswer {
  final String path;
  final Uint8List? bytes;
  final int durationSeconds;

  const _RecordedAnswer({
    required this.path,
    required this.bytes,
    required this.durationSeconds,
  });
}
