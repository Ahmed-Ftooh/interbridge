// lib/previews/embedded_audio_player.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class EmbeddedAudioPlayer extends StatefulWidget {
  final String url;
  final String? fileName;
  final bool isMe; // Adapt styling based on sender/receiver side

  const EmbeddedAudioPlayer({
    super.key,
    required this.url,
    this.fileName,
    this.isMe = false,
  });

  @override
  State<EmbeddedAudioPlayer> createState() => _EmbeddedAudioPlayerState();
}

class _EmbeddedAudioPlayerState extends State<EmbeddedAudioPlayer> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playerState = PlayerState.stopped;

    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    // Set the source and handle initial loading
    _setSource();
  }

  Future<void> _setSource() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await _audioPlayer.setSourceUrl(widget.url);
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading audio: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else if (_playerState == PlayerState.paused) {
      await _audioPlayer.resume();
    } else {
      await _audioPlayer.play(UrlSource(widget.url));
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neutral, modern card with subtle accent.
    final Color accent = ColorManager.primary2;
    final Color textPrimary =
        widget.isMe ? Colors.white : ColorManager.textPrimary;
    final Color textSecondary =
        widget.isMe ? Colors.white70 : ColorManager.textSecondary;
    final Color bg =
        widget.isMe ? accent.withValues(alpha: 0.20) : Colors.white;
    final BoxBorder? border =
        widget.isMe
            ? Border.all(color: accent.withValues(alpha: 0.25), width: 1)
            : Border.all(
              color: ColorManager.greyMedium.withValues(alpha: 0.25),
              width: 1,
            );

    final double progress =
        _duration.inMilliseconds == 0
            ? 0
            : (_position.inMilliseconds / _duration.inMilliseconds).clamp(
              0.0,
              1.0,
            );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSize.s12,
        vertical: AppSize.s10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSize.s14),
        border: border,
        boxShadow:
            widget.isMe
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Row(
        children: [
          // Play/Pause Button
          if (_isLoading)
            const SizedBox(
              width: 42,
              height: 42,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _playerState == PlayerState.playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
              ),
              iconSize: 42,
              color: accent,
              onPressed: _togglePlayPause,
            ),

          const SizedBox(width: AppSize.s8),

          // Title + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.fileName ?? 'Voice message',
                  style: TextStyle(
                    fontSize: AppSize.s14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSize.s6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _isLoading ? null : progress,
                    minHeight: 6,
                    backgroundColor: (widget.isMe
                            ? Colors.white
                            : ColorManager.greyLight)
                        .withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: AppSize.s6),
                // Time row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stop button when applicable
          if (_playerState == PlayerState.playing ||
              _playerState == PlayerState.paused)
            IconButton(
              icon: Icon(Icons.stop_circle_outlined, color: textSecondary),
              iconSize: 28,
              onPressed: _stop,
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '0:00';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
