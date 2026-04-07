import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:interbridge/core/web_helpers/fetch_blob_bytes.dart'
    if (dart.library.html) 'package:interbridge/core/web_helpers/fetch_blob_bytes_web.dart'
    as blob_helper;

/// Professional web voice sample recording screen for interpreter onboarding.
/// Records two samples: English introduction and native-language introduction.
class VoiceSampleWebScreen extends StatefulWidget {
  const VoiceSampleWebScreen({super.key});

  @override
  State<VoiceSampleWebScreen> createState() => _VoiceSampleWebScreenState();
}

class _VoiceSampleWebScreenState extends State<VoiceSampleWebScreen> {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _playerEnglish;
  late final AudioPlayer _playerNative;

  bool _permissionDenied = false;

  // --- English sample state ---
  bool _isRecordingEn = false;
  bool _isPlayingEn = false;
  String? _audioPathEn;
  Uint8List? _audioBytesEn;
  int _recordDurationEn = 0;
  Timer? _timerEn;

  // --- Native-language sample state ---
  bool _isRecordingNat = false;
  bool _isPlayingNat = false;
  String? _audioPathNat;
  Uint8List? _audioBytesNat;
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

    _checkPermission();
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

  // ─── Recording helpers ────────────────────────────────────────
  Future<void> _startRecording({required bool isNative}) async {
    if (_isAnyRecording) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );

        setState(() {
          _permissionDenied = false;
          if (isNative) {
            _isRecordingNat = true;
            _audioPathNat = null;
            _audioBytesNat = null;
            _recordDurationNat = 0;
          } else {
            _isRecordingEn = true;
            _audioPathEn = null;
            _audioBytesEn = null;
            _recordDurationEn = 0;
          }
        });

        final timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              if (isNative) {
                _recordDurationNat++;
              } else {
                _recordDurationEn++;
              }
            });
          }
        });
        if (isNative) {
          _timerNat = timer;
        } else {
          _timerEn = timer;
        }
      } else {
        setState(() => _permissionDenied = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
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

      Uint8List? bytes;
      if (path != null && path.startsWith('blob:')) {
        bytes = await blob_helper.fetchBlobBytes(path);
      }

      setState(() {
        if (isNative) {
          _isRecordingNat = false;
          _audioPathNat = path;
          _audioBytesNat = bytes;
        } else {
          _isRecordingEn = false;
          _audioPathEn = path;
          _audioBytesEn = bytes;
        }
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
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
        await player.play(UrlSource(path));
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
        _audioBytesNat = null;
        _isPlayingNat = false;
        _recordDurationNat = 0;
      } else {
        _audioPathEn = null;
        _audioBytesEn = null;
        _isPlayingEn = false;
        _recordDurationEn = 0;
      }
    });
  }

  // ─── Navigation ───────────────────────────────────────────────
  Future<void> _continue() async {
    if (!_canContinue) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      if (userId == null) throw Exception("User not logged in");

      // Upload English sample
      final englishPath =
          '$userId/voice_english_${DateTime.now().millisecondsSinceEpoch}.webm';
      if (_audioBytesEn != null) {
        await Supabase.instance.client.storage
            .from('voice_samples')
            .uploadBinary(englishPath, _audioBytesEn!);
        final url = Supabase.instance.client.storage
            .from('voice_samples')
            .getPublicUrl(englishPath);
        await Supabase.instance.client.from('voice_samples').insert({
          'user_id': userId,
          'url': url,
          'prompt': 'English introduction',
          'sentence_type': 'english',
        });
      }

      // Upload Native sample
      final nativePath =
          '$userId/voice_native_${DateTime.now().millisecondsSinceEpoch}.webm';
      if (_audioBytesNat != null) {
        await Supabase.instance.client.storage
            .from('voice_samples')
            .uploadBinary(nativePath, _audioBytesNat!);
        final url = Supabase.instance.client.storage
            .from('voice_samples')
            .getPublicUrl(nativePath);
        await Supabase.instance.client.from('voice_samples').insert({
          'user_id': userId,
          'url': url,
          'prompt': 'Native language introduction',
          'sentence_type': 'native',
        });
      }

      await Supabase.instance.client
          .from('interpreter_details')
          .update({'onboarding_status': 'voice_sample_uploaded'})
          .eq('user_id', userId);

      if (mounted) {
        final args =
            ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>? ??
            {};
        // no longer need to pass bytes or blobs
        args.remove('voiceSampleBytes');
        args.remove('voiceSampleNativeBytes');

        Navigator.of(context).pushNamed(Routes.phoneOtpRoute, arguments: args);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to upload voice samples: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      // no-op
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final fullScreenResume = args['authContinuationFullScreen'] == true;

    return AuthWebWrapper(
      fullScreen: fullScreenResume,
      title: 'Voice check',
      subtitle:
          'Record two short voice samples — one in English and one in your native language',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(5, 9),
          const SizedBox(height: 28),

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

          // ── English section ──
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
          const SizedBox(height: 20),

          // ── Native language section ──
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
          const SizedBox(height: 32),

          // Continue
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _canContinue ? _continue : null,
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
    final otherRecording = isNative ? _isRecordingEn : _isRecordingNat;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              audioPath != null
                  ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              if (audioPath != null)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Prompt (show when not yet recorded)
          if (audioPath == null && !isRecording)
            Text(
              prompt,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.6,
              ),
            ),

          if (audioPath == null && !isRecording) const SizedBox(height: 16),

          // Recording area or playback card
          if (audioPath != null)
            _buildPlaybackCard(isNative: isNative, isPlaying: isPlaying)
          else
            _buildRecordingArea(
              isNative: isNative,
              isRecording: isRecording,
              duration: duration,
              disabled: otherRecording,
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingArea({
    required bool isNative,
    required bool isRecording,
    required int duration,
    required bool disabled,
  }) {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap:
                disabled
                    ? null
                    : (isRecording
                        ? () => _stopRecording(isNative: isNative)
                        : () => _startRecording(isNative: isNative)),
            child: MouseRegion(
              cursor:
                  disabled
                      ? SystemMouseCursors.forbidden
                      : SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      disabled
                          ? const Color(0xFF94A3B8)
                          : (isRecording
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A)),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A))
                          .withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isRecording
              ? _formatDuration(duration)
              : (disabled
                  ? 'Finish the other recording first'
                  : 'Tap to start recording'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isRecording ? FontWeight.w600 : FontWeight.w400,
            color:
                isRecording ? const Color(0xFFDC2626) : const Color(0xFF64748B),
          ),
        ),
        if (isRecording)
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

  Widget _buildPlaybackCard({required bool isNative, required bool isPlaying}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _togglePlayback(isNative: isNative),
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: const Color(0xFF0F172A),
              size: 36,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNative
                      ? 'Native sample recorded'
                      : 'English sample recorded',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  _formatDuration(
                    isNative ? _recordDurationNat : _recordDurationEn,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteRecording(isNative: isNative),
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
