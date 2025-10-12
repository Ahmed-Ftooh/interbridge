import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';
import 'package:interbridge/presentation/widgets/call_feedback_form.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedCallScreen extends StatelessWidget {
  final String channelId;
  final ChatBloc chatBloc; // Pass the chat bloc to enable communication

  const EnhancedCallScreen({
    super.key,
    required this.channelId,
    required this.chatBloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => CallBloc(
            service: CallService(),
            chatBloc: chatBloc, // Pass chat bloc to call bloc
          ),
      child: _EnhancedCallScreenBody(channelId: channelId, chatBloc: chatBloc),
    );
  }
}

class _EnhancedCallScreenBody extends StatefulWidget {
  final String channelId;
  final ChatBloc chatBloc;

  const _EnhancedCallScreenBody({
    required this.channelId,
    required this.chatBloc,
  });

  @override
  State<_EnhancedCallScreenBody> createState() =>
      _EnhancedCallScreenBodyState();
}

class _EnhancedCallScreenBodyState extends State<_EnhancedCallScreenBody> {
  DateTime? _callStartTime;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Build a stable int UID from the authenticated user UUID
    final myUid = _uidFromUuid(
      Supabase.instance.client.auth.currentUser?.id ?? '',
    );
    context.read<CallBloc>().add(
      StartCall(channelId: widget.channelId, localUid: myUid),
    );
    _saveSessionState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listener: (context, chatState) {
        // Listen for call ended messages from chat
        if (chatState is ChatLoaded && chatState.messages.isNotEmpty) {
          final lastMessage = chatState.messages.last;
          final isCallEnded = lastMessage['content'] == '__CALL_ENDED__';
          final isFromMe =
              lastMessage['sender_id'] ==
              Supabase.instance.client.auth.currentUser?.id;

          if (isCallEnded && !isFromMe) {
            // Other participant ended the call, close our call screen
            Navigator.of(context).maybePop();
          }
        }
      },
      child: BlocConsumer<CallBloc, CallState>(
        listener: (context, callState) {
          // Listen for call state changes from chat messages
          if (callState is CallEnded) {
            // Show feedback form before navigating away
            _showFeedbackForm(context);
          } else if (callState is CallError) {
            // Show error dialog and then pop back
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Call Error'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(callState.error.message),
                        if (callState.error.userAction != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            callState.error.userAction!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).maybePop(); // Go back to chat
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
          }
        },
        builder: (context, callState) {
          // Track call duration
          if (callState is CallOngoing && _callStartTime == null) {
            _callStartTime = DateTime.now();
          }

          if (callState is CallOngoing && _callStartTime != null) {
            _callDuration = DateTime.now().difference(_callStartTime!);
          }

          return Scaffold(
            backgroundColor: ColorManager.primary2Dark,
            body: Stack(
              children: [
                // Main call interface
                _buildCallInterface(callState),

                // Top controls
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: ColorManager.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        IconButton(
                          icon: Icon(Icons.chat, color: ColorManager.white),
                          onPressed: () {
                            // Navigate to chat view while keeping call active
                            // Use push instead of pushReplacement to avoid bloc disposal
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => BlocProvider.value(
                                      value: widget.chatBloc,
                                      child: ChatView(
                                        requestId: widget.channelId,
                                        requesterId:
                                            '', // These will be handled by the chat view
                                        interpreterId: '',
                                      ),
                                    ),
                              ),
                            );
                          },
                        ),
                        // End Session button
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: ColorManager.white,
                          ),
                          onSelected: (value) {
                            if (value == 'end_session') {
                              _showEndSessionDialog(context);
                            }
                          },
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'end_session',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.exit_to_app,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text('End Session'),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallInterface(CallState callState) {
    log(
      '_buildCallInterface - Building interface for state: ${callState.runtimeType}',
    );

    if (callState is CallConnecting) {
      log('_buildCallInterface - Showing connecting screen');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ColorManager.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: ColorManager.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connecting...',
              style: TextStyle(
                color: ColorManager.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we connect your call',
              style: TextStyle(
                color: ColorManager.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (callState is CallOngoing) {
      log('_buildCallInterface - Showing call interface');
      return Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: ColorManager.secondaryGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: ColorManager.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ColorManager.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 100,
                        color: ColorManager.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Voice Call',
                      style: TextStyle(
                        color: ColorManager.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Channel: ${widget.channelId}',
                      style: TextStyle(
                        color: ColorManager.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Call duration display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ColorManager.primary2.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: ColorManager.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatDuration(_callDuration),
                        style: TextStyle(
                          color: ColorManager.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildCallControls(callState),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_end, size: 80, color: ColorManager.error),
          const SizedBox(height: 16),
          Text(
            'Call ended',
            style: TextStyle(
              color: ColorManager.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls(CallOngoing state) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ColorManager.primary2Dark.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _roundIconButton(
            icon: state.muted ? Icons.mic_off : Icons.mic,
            label: state.muted ? 'Unmute' : 'Mute',
            color: state.muted ? ColorManager.error : ColorManager.white,
            onTap: () => context.read<CallBloc>().add(ToggleMute()),
          ),
          _roundIconButton(
            icon: Icons.call_end,
            label: 'Hang up',
            color: ColorManager.error,
            onTap: () {
              context.read<CallBloc>().add(EndCall());
              Navigator.of(context).maybePop();
            },
          ),
          _roundIconButton(
            icon: state.speakerOn ? Icons.volume_up : Icons.hearing,
            label: state.speakerOn ? 'Speaker' : 'Earpiece',
            color: state.speakerOn ? ColorManager.primary : ColorManager.white,
            onTap: () => context.read<CallBloc>().add(ToggleSpeaker()),
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: ColorManager.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _saveSessionState() {
    SessionService.saveSession(
      requestId: widget.channelId,
      requesterId: '', // These will be handled by the session
      interpreterId: '',
      currentScreen: 'call',
    );
  }

  void _showFeedbackForm(BuildContext context) async {
    // Only show feedback form for requesters
    try {
      final supabaseService = SupabaseService();
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        final userProfile = await supabaseService.getUserProfile(
          currentUser.id,
        );

        // Only show feedback form if user is a requester
        if (userProfile?.role == 'requester') {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => CallFeedbackForm(
                  channelId: widget.channelId,
                  callDuration: _callDuration,
                  onFeedbackSubmitted: () {
                    Navigator.of(context).pop(); // Close feedback form
                    Navigator.of(
                      context,
                    ).maybePop(); // Go back to previous screen
                  },
                ),
          );
        } else {
          // For interpreters, just navigate back without showing feedback
          Navigator.of(context).maybePop();
        }
      } else {
        // If no user, just navigate back
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      log('Error checking user role for feedback: $e');
      // On error, just navigate back
      Navigator.of(context).maybePop();
    }
  }

  void _showEndSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('End Session'),
            content: const Text(
              'Are you sure you want to end this session? You will be returned to the home screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Close the dialog first
                    Navigator.of(context).pop();

                    // End the session
                    await SessionService.endSession();

                    // Ensure we're still mounted before navigating
                    if (mounted) {
                      // Clear the entire navigation stack and go to home
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/main', (route) => false);
                    }
                  } catch (e) {
                    // If there's an error, still try to navigate back
                    if (mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/main', (route) => false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Session'),
              ),
            ],
          ),
    );
  }

  int _uidFromUuid(String uuid) {
    return uuid.hashCode.abs();
  }
}
