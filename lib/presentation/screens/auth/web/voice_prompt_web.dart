import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:record/record.dart';

import 'package:interbridge/core/web_helpers/fetch_blob_bytes.dart'
    if (dart.library.html) 'package:interbridge/core/web_helpers/fetch_blob_bytes_web.dart'
    as blob_helper;

/// Random voice prompt verification screen for interpreter onboarding.
/// Displays random prompts from the database and asks the user to read them aloud.
class VoicePromptWebScreen extends StatefulWidget {
  const VoicePromptWebScreen({super.key});

  @override
  State<VoicePromptWebScreen> createState() => _VoicePromptWebScreenState();
}

class _VoicePromptWebScreenState extends State<VoicePromptWebScreen> {
  final _supabase = SupabaseService();
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;

  bool _loadingPrompts = true;
  bool _permissionDenied = false;
  String? _loadError;

  List<Map<String, dynamic>> _prompts = [];
  int _currentPromptIndex = 0;

  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Store recordings for each prompt
  final Map<int, Uint8List?> _recordings = {};
  final Map<int, String?> _recordingPaths = {};
  final Map<int, int> _recordingDurations = {};

  bool get _allRecorded =>
      _prompts.isNotEmpty &&
      _recordings.length == _prompts.length &&
      _recordings.values.every((b) => b != null);

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _loadPrompts();
    _checkPermission();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (mounted) {
        setState(() {
          _permissionDenied = !hasPermission;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  Future<void> _loadPrompts() async {
    if (!mounted) return;
    setState(() {
      _loadingPrompts = true;
      _loadError = null;
    });
    try {
      final prompts = await _supabase.getRandomVoicePrompts(count: 3);
      if (mounted) {
        setState(() {
          _prompts = prompts;
          _loadingPrompts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading voice prompts: $e');
      if (mounted) {
        setState(() {
          _loadingPrompts = false;
          _loadError = e.toString();
        });
      }
    }
  }

  // ─── Recording ─────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );
        setState(() {
          _permissionDenied = false;
          _isRecording = true;
          _recordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordDuration++);
        });
      } else {
        setState(() => _permissionDenied = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();

      Uint8List? bytes;
      if (path != null && path.startsWith('blob:')) {
        bytes = await blob_helper.fetchBlobBytes(path);
      }

      setState(() {
        _isRecording = false;
        // Store for current prompt
        _recordings[_currentPromptIndex] = bytes;
        _recordingPaths[_currentPromptIndex] = path;
        _recordingDurations[_currentPromptIndex] = _recordDuration;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _togglePlayback() async {
    final path = _recordingPaths[_currentPromptIndex];
    if (path == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(UrlSource(path));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _deleteRecording() {
    _audioPlayer.stop();
    setState(() {
      _recordings.remove(_currentPromptIndex);
      _recordingPaths.remove(_currentPromptIndex);
      _recordingDurations.remove(_currentPromptIndex);
      _isPlaying = false;
      _recordDuration = 0;
    });
  }

  void _nextPrompt() {
    if (_currentPromptIndex < _prompts.length - 1) {
      _audioPlayer.stop();
      setState(() {
        _currentPromptIndex++;
        _isPlaying = false;
        _recordDuration = _recordingDurations[_currentPromptIndex] ?? 0;
      });
    }
  }

  void _prevPrompt() {
    if (_currentPromptIndex > 0) {
      _audioPlayer.stop();
      setState(() {
        _currentPromptIndex--;
        _isPlaying = false;
        _recordDuration = _recordingDurations[_currentPromptIndex] ?? 0;
      });
    }
  }

  void _continue() {
    if (!_allRecorded) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    // Pack all voice prompt recordings into args
    final promptRecordings = <Map<String, dynamic>>[];
    for (int i = 0; i < _prompts.length; i++) {
      promptRecordings.add({
        'prompt_id': _prompts[i]['id'],
        'prompt_text': _prompts[i]['prompt_text'],
        'bytes': _recordings[i],
        'path': _recordingPaths[i],
        'duration': _recordingDurations[i] ?? 0,
      });
    }
    args['voicePromptRecordings'] = promptRecordings;

    Navigator.of(context).pushNamed(Routes.phoneOtpRoute, arguments: args);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final fullScreenResume = args['authContinuationFullScreen'] == true;

    return AuthWebWrapper(
      fullScreen: fullScreenResume,
      title: 'Voice verification',
      subtitle:
          'Read aloud the prompts below so we can verify your language skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(6, 9),
          const SizedBox(height: 24),

          if (_loadingPrompts)
            const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              ),
            )
          else if (_prompts.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _loadError != null
                          ? 'Failed to load prompts'
                          : 'No prompts available. Please try again later.',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _loadPrompts,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (_permissionDenied)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Microphone access is required. Please allow it in your browser.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Prompt counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prompt ${_currentPromptIndex + 1} of ${_prompts.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: List.generate(
                    _prompts.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _recordings.containsKey(i)
                                ? const Color(0xFF22C55E)
                                : i == _currentPromptIndex
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prompt card
            _buildPromptCard(),

            const SizedBox(height: 16),

            // Navigation
            Row(
              children: [
                if (_currentPromptIndex > 0)
                  TextButton.icon(
                    onPressed: _prevPrompt,
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Previous'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                const Spacer(),
                if (_currentPromptIndex < _prompts.length - 1)
                  TextButton.icon(
                    onPressed:
                        _recordings.containsKey(_currentPromptIndex)
                            ? _nextPrompt
                            : null,
                    icon: const Text('Next'),
                    label: const Icon(Icons.arrow_forward_ios, size: 14),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Continue / Skip
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _allRecorded ? _continue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                ),
                child: Text(
                  _allRecorded
                      ? 'Continue'
                      : 'Record all ${_prompts.length} prompts to continue',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
                child: const Text('Back'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
    final prompt = _prompts[_currentPromptIndex];
    final promptText = prompt['prompt_text'] as String? ?? '';
    final category = prompt['category'] as String? ?? '';
    final hasRecording = _recordings.containsKey(_currentPromptIndex);
    final duration =
        _recordingDurations[_currentPromptIndex] ?? _recordDuration;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category.isNotEmpty
                  ? category[0].toUpperCase() + category.substring(1)
                  : 'Prompt',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prompt text
          Text(
            'Read aloud:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$promptText"',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Recording area
          if (hasRecording && !_isRecording) ...[
            // Playback card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: const Color(0xFF22C55E),
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recording saved',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _deleteRecording,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    tooltip: 'Re-record',
                  ),
                ],
              ),
            ),
          ] else ...[
            // Record button
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isRecording
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF0F172A),
                        boxShadow:
                            _isRecording
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording
                        ? _formatDuration(_recordDuration)
                        : 'Tap to record',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _isRecording
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B),
                      fontWeight:
                          _isRecording ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        final isActive = step == current;
        final isDone = step < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color:
                  isActive
                      ? const Color(0xFF0F172A)
                      : isDone
                      ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
            ),
          ),
        );
      }),
    );
  }
}
