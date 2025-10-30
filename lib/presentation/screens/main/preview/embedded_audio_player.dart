// lib/previews/embedded_audio_player.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class EmbeddedAudioPlayer extends StatefulWidget {
  final String url;
  final String? fileName;

  const EmbeddedAudioPlayer({super.key, required this.url, this.fileName});

  @override
  State<EmbeddedAudioPlayer> createState() => _EmbeddedAudioPlayerState();
}

class _EmbeddedAudioPlayerState extends State<EmbeddedAudioPlayer> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = false;

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

    // Set the source and handle initial loading
    _setSource();
  }

  Future<void> _setSource() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await _audioPlayer.setSourceUrl(widget.url);
    } catch (e) {
      // Handle error (e.g., show a snackbar)
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSize.s12,
        vertical: AppSize.s8,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Play/Pause Button
          if (_isLoading)
            const SizedBox(
              width: 40,
              height: 40,
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
              iconSize: 40,
              color: ColorManager.primary2,
              onPressed: _togglePlayPause,
            ),

          // Stop Button
          if (_playerState == PlayerState.playing ||
              _playerState == PlayerState.paused)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              iconSize: 40,
              color: ColorManager.textSecondary,
              onPressed: _stop,
            ),

          const SizedBox(width: AppSize.s12),

          // File Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName ?? 'Voice Recording',
                  style: const TextStyle(
                    fontSize: AppSize.s14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSize.s4),
                Text(
                  'Tap to play',
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    color: Colors.blue.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
