import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DraggableCallWidget extends StatefulWidget {
  final String channelId;
  final Function(Duration) onCallEnded;
  final bool isVideoCall;

  const DraggableCallWidget({
    super.key,
    required this.channelId,
    required this.onCallEnded,
    this.isVideoCall = false,
  });

  @override
  State<DraggableCallWidget> createState() => _DraggableCallWidgetState();
}

class _DraggableCallWidgetState extends State<DraggableCallWidget> {
  // State for dragging
  Offset _position = const Offset(16, 100);
  bool _isMinimized = false;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Build a stable int UID from the authenticated user UUID
    final myUid = uidFromUuid(
      Supabase.instance.client.auth.currentUser?.id ?? '',
    );
    context.read<CallBloc>().add(
      StartCall(
        channelId: widget.channelId,
        localUid: myUid,
        isVideoCall: widget.isVideoCall,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hh = d.inHours;
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hh > 0) {
      return '${hh.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    // Constrain position within screen bounds
    if (_position.dx < 0) _position = Offset(0, _position.dy);
    if (_position.dx > screenSize.width - 120) {
      _position = Offset(screenSize.width - 120, _position.dy);
    }
    if (_position.dy < safeArea.top) {
      _position = Offset(_position.dx, safeArea.top);
    }
    if (_position.dy > screenSize.height - safeArea.bottom - 200) {
      _position = Offset(
        _position.dx,
        screenSize.height - safeArea.bottom - 200,
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildCallWidget(
          isFeedback: true,
        ), // Show a semi-transparent version while dragging
        childWhenDragging: Container(), // Leave nothing behind
        onDragEnd: (details) {
          setState(() => _position = details.offset); // Update position
        },
        child: _buildCallWidget(isFeedback: false),
      ),
    );
  }

  Widget _buildCallWidget({required bool isFeedback}) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallEnded) {
          widget.onCallEnded(_callDuration);
        } else if (state is CallError) {
          widget.onCallEnded(Duration.zero); // End call on error
          // Note: The original CallScreen showed a dialog.
          // We can't show a dialog here as we are popping.
          // The error handling should be managed by the ChatView now.
        } else if (state is CallOngoing) {
          _callDuration = state.elapsed; // Keep track of duration
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        String title = 'Connecting…';
        bool muted = false;
        bool speakerOn = true;
        String timer = '00:00';

        if (state is CallOngoing) {
          title = 'In Call';
          muted = state.muted;
          speakerOn = state.speakerOn;
          timer = _formatDuration(state.elapsed);
        }

        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: isFeedback ? 0.5 : 0.85),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isMinimized ? 120 : 280,
            height: _isMinimized ? 60 : 320,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment:
                  _isMinimized
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
              children: [
                // Title / Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isMinimized)
                      Text(
                        timer,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    IconButton(
                      icon: Icon(
                        _isMinimized ? Icons.fullscreen : Icons.fullscreen_exit,
                      ),
                      color: Colors.white,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed:
                          () => setState(() => _isMinimized = !_isMinimized),
                    ),
                  ],
                ),

                if (!_isMinimized) ...[
                  const Spacer(),
                  Text(
                    timer,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // --- Your Agora Video/Audio UI would go here ---
                  const Expanded(
                    child: Center(
                      child: Icon(
                        Icons.person,
                        color: Colors.white60,
                        size: 80,
                      ),
                    ),
                  ),
                  // ----------------------------------------------
                  const Spacer(),
                  // Call Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _roundIconButton(
                        icon: muted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        onTap: () => context.read<CallBloc>().add(ToggleMute()),
                      ),
                      _roundIconButton(
                        icon: Icons.call_end,
                        color: Colors.redAccent,
                        onTap: () => context.read<CallBloc>().add(EndCall()),
                      ),
                      _roundIconButton(
                        icon: speakerOn ? Icons.volume_up : Icons.hearing,
                        color: Colors.white,
                        onTap:
                            () => context.read<CallBloc>().add(ToggleSpeaker()),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
