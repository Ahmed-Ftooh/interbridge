import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceSampleScreen extends StatefulWidget {
  const VoiceSampleScreen({super.key});

  @override
  State<VoiceSampleScreen> createState() => _VoiceSampleScreenState();
}

class _VoiceSampleScreenState extends State<VoiceSampleScreen> {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _playerEnglish;
  late final AudioPlayer _playerNative;

  // --- English sample state ---
  bool _isRecordingEn = false;
  bool _isPlayingEn = false;
  String? _audioPathEn;
  int _recordDurationEn = 0;
  Timer? _timerEn;

  // --- Native-language sample state ---
  bool _isRecordingNat = false;
  bool _isPlayingNat = false;
  String? _audioPathNat;
  int _recordDurationNat = 0;
  Timer? _timerNat;

  bool get _isAnyRecording => _isRecordingEn || _isRecordingNat;
  bool get _canContinue => _audioPathEn != null && _audioPathNat != null;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _playerEnglish = AudioPlayer();
    _playerNative = AudioPlayer();

    _playerEnglish.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingEn = false);
    });
    _playerNative.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingNat = false);
    });
  }

  @override
  void dispose() {
    _timerEn?.cancel();
    _timerNat?.cancel();
    _audioRecorder.dispose();
    _playerEnglish.dispose();
    _playerNative.dispose();
    super.dispose();
  }

  // ─── Recording helpers ────────────────────────────────────────
  Future<void> _startRecording({required bool isNative}) async {
    if (_isAnyRecording) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final tag = isNative ? 'native' : 'english';
        final path =
            '${directory.path}/voice_${tag}_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          if (isNative) {
            _isRecordingNat = true;
            _audioPathNat = null;
            _recordDurationNat = 0;
          } else {
            _isRecordingEn = true;
            _audioPathEn = null;
            _recordDurationEn = 0;
          }
        });

        final timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            if (isNative) {
              _recordDurationNat++;
            } else {
              _recordDurationEn++;
            }
          });
        });
        if (isNative) {
          _timerNat = timer;
        } else {
          _timerEn = timer;
        }
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording({required bool isNative}) async {
    try {
      final path = await _audioRecorder.stop();
      if (isNative) {
        _timerNat?.cancel();
      } else {
        _timerEn?.cancel();
      }

      setState(() {
        if (isNative) {
          _isRecordingNat = false;
          _audioPathNat = path;
        } else {
          _isRecordingEn = false;
          _audioPathEn = path;
        }
      });
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _togglePlayback({required bool isNative}) async {
    final path = isNative ? _audioPathNat : _audioPathEn;
    if (path == null) return;

    final player = isNative ? _playerNative : _playerEnglish;
    final isPlaying = isNative ? _isPlayingNat : _isPlayingEn;

    try {
      if (isPlaying) {
        await player.pause();
        setState(() {
          if (isNative) {
            _isPlayingNat = false;
          } else {
            _isPlayingEn = false;
          }
        });
      } else {
        await player.play(DeviceFileSource(path));
        setState(() {
          if (isNative) {
            _isPlayingNat = true;
          } else {
            _isPlayingEn = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _deleteRecording({required bool isNative}) {
    final player = isNative ? _playerNative : _playerEnglish;
    player.stop();
    setState(() {
      if (isNative) {
        _audioPathNat = null;
        _isPlayingNat = false;
        _recordDurationNat = 0;
      } else {
        _audioPathEn = null;
        _isPlayingEn = false;
        _recordDurationEn = 0;
      }
    });
  }

  // ─── Navigation ───────────────────────────────────────────────
  void _continue() {
    if (!_canContinue) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    args['voiceSamplePath'] = _audioPathEn;
    args['voiceSampleNativePath'] = _audioPathNat;

    Navigator.of(
      context,
    ).pushNamed(Routes.certificateUploadRoute, arguments: args);
  }

  // ─── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Voice Check'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSize.s24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSampleSection(
                        isNative: false,
                        title: 'English introduction',
                        icon: Icons.record_voice_over_rounded,
                        prompt:
                            'Introduce yourself in English. Tell us about your education and medical interpreting experience.',
                        audioPath: _audioPathEn,
                        isRecording: _isRecordingEn,
                        isPlaying: _isPlayingEn,
                        duration: _recordDurationEn,
                      ),
                      const SizedBox(height: 24),
                      _buildSampleSection(
                        isNative: true,
                        title: 'Native language introduction',
                        icon: Icons.translate_rounded,
                        prompt:
                            'Introduce yourself in your native language. Tell us about your education and medical interpreting experience.',
                        audioPath: _audioPathNat,
                        isRecording: _isRecordingNat,
                        isPlaying: _isPlayingNat,
                        duration: _recordDurationNat,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primary2,
                    padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSize.s16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Reusable section widget ──────────────────────────────────
  Widget _buildSampleSection({
    required bool isNative,
    required String title,
    required IconData icon,
    required String prompt,
    required String? audioPath,
    required bool isRecording,
    required bool isPlaying,
    required int duration,
  }) {
    final theme = Theme.of(context);
    final otherRecording = isNative ? _isRecordingEn : _isRecordingNat;

    return Container(
      padding: const EdgeInsets.all(AppSize.s20),
      decoration: BoxDecoration(
        color: ColorManager.primary2.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSize.s20),
        border: Border.all(
          color:
              audioPath != null
                  ? Colors.green.withValues(alpha: 0.4)
                  : ColorManager.primary2.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(icon, color: ColorManager.primary2, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ColorManager.primary2,
                  ),
                ),
              ),
              if (audioPath != null)
                const Icon(Icons.check_circle, color: Colors.green, size: 22),
            ],
          ),
          const SizedBox(height: 12),

          // Prompt text (show when not yet recorded)
          if (audioPath == null && !isRecording)
            Text(
              prompt,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 16),

          // Recording / playback
          if (audioPath != null)
            _buildPlaybackCard(isNative: isNative, isPlaying: isPlaying)
          else ...[
            // Duration while recording
            if (isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _formatDuration(duration),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: ColorManager.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Mic button
            GestureDetector(
              onTap:
                  otherRecording
                      ? null
                      : (isRecording
                          ? () => _stopRecording(isNative: isNative)
                          : () => _startRecording(isNative: isNative)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      otherRecording
                          ? ColorManager.greyMedium
                          : (isRecording
                              ? ColorManager.error
                              : ColorManager.primary2),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? ColorManager.error
                              : ColorManager.primary2)
                          .withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRecording
                  ? 'Tap to stop'
                  : (otherRecording
                      ? 'Finish the other recording first'
                      : 'Tap to start recording'),
              style: TextStyle(fontSize: 12, color: ColorManager.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaybackCard({required bool isNative, required bool isPlaying}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          IconButton(
            onPressed: () => _togglePlayback(isNative: isNative),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: ColorManager.primary2,
              size: 36,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isNative ? 'Native sample recorded' : 'English sample recorded',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _deleteRecording(isNative: isNative),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.delete_outline,
              color: ColorManager.error,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
