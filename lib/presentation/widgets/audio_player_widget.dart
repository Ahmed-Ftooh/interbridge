// lib/previews/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final String? fileName;
  final bool isInline; // Add parameter to control display mode

  const AudioPlayerWidget({
    super.key,
    required this.url,
    this.fileName,
    this.isInline = true, // Default to inline display
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
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
      // Handle error
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _play() async {
    await _audioPlayer.resume();
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    // Release the player
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.fileName ?? 'Voice Recording',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSize.s24),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause Button
                IconButton(
                  icon: Icon(
                    _playerState == PlayerState.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  iconSize: 64,
                  color: ColorManager.primary2,
                  onPressed:
                      _playerState == PlayerState.playing ? _pause : _play,
                ),
                // Stop Button (if playing or paused)
                if (_playerState == PlayerState.playing ||
                    _playerState == PlayerState.paused)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    iconSize: 64,
                    color: ColorManager.textSecondary,
                    onPressed: _stop,
                  ),
              ],
            ),
          const SizedBox(height: AppSize.s16),
        ],
      ),
    );
  }
}
