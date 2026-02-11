import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:record/record.dart';

/// Professional web voice sample recording screen for interpreter onboarding
class VoiceSampleWebScreen extends StatefulWidget {
  const VoiceSampleWebScreen({super.key});

  @override
  State<VoiceSampleWebScreen> createState() => _VoiceSampleWebScreenState();
}

class _VoiceSampleWebScreenState extends State<VoiceSampleWebScreen> {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasPermission = false;
  bool _permissionDenied = false;
  String? _audioPath;
  int _recordDuration = 0;
  Timer? _timer;

  final String _promptText =
      'Introduce yourself briefly and tell us why you want to become an interpreter with InterBridge.';

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    _checkPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _permissionDenied = !hasPermission;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _permissionDenied = true);
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // On web, record to a blob URL (path is ignored)
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );

        setState(() {
          _isRecording = true;
          _audioPath = null;
          _recordDuration = 0;
          _hasPermission = true;
          _permissionDenied = false;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      _timer?.cancel();

      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_audioPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(UrlSource(_audioPath!));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _deleteRecording() {
    _audioPlayer.stop();
    setState(() {
      _audioPath = null;
      _isPlaying = false;
      _recordDuration = 0;
    });
  }

  void _continue() {
    if (_audioPath == null) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    args['voiceSamplePath'] = _audioPath;
    Navigator.of(
      context,
    ).pushNamed(Routes.certificateUploadRoute, arguments: args);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Voice check',
      subtitle: 'Record a short voice sample to verify your speaking ability',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(5, 6),
          const SizedBox(height: 28),

          // Prompt card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Prompt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _promptText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_permissionDenied) ...[
            Container(
              padding: const EdgeInsets.all(16),
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
                      'Microphone access is required. Please allow microphone access in your browser settings.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recording area
          if (_audioPath == null)
            _buildRecordingArea()
          else
            _buildPlaybackArea(),

          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _audioPath != null ? _continue : null,
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
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
      ),
    );
  }

  Widget _buildRecordingArea() {
    return Column(
      children: [
        // Mic button
        Center(
          child: GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
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
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isRecording
              ? _formatDuration(_recordDuration)
              : 'Tap to start recording',
          style: TextStyle(
            fontSize: 14,
            fontWeight: _isRecording ? FontWeight.w600 : FontWeight.w400,
            color:
                _isRecording
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF64748B),
          ),
        ),
        if (_isRecording)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Tap to stop',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaybackArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Play/pause
          IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: const Color(0xFF0F172A),
              size: 40,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice sample recorded',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  _formatDuration(_recordDuration),
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
              Icons.delete_outline_rounded,
              color: Color(0xFFDC2626),
              size: 22,
            ),
            tooltip: 'Delete and re-record',
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCurrent
                      ? const Color(0xFF3B82F6)
                      : isActive
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
