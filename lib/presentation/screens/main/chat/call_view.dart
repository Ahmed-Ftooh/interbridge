import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallScreen extends StatelessWidget {
  final String channelId; // use your requestId as channel id

  const CallScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CallBloc(service: CallService()),
      child: _CallScreenBody(channelId: channelId),
    );
  }
}

class _CallScreenBody extends StatefulWidget {
  final String channelId;
  const _CallScreenBody({required this.channelId});

  @override
  State<_CallScreenBody> createState() => _CallScreenBodyState();
}

class _CallScreenBodyState extends State<_CallScreenBody> {
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallEnded) {
          Navigator.of(context).maybePop();
        } else if (state is CallError) {
          // Show error dialog and then pop back
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  title: Text('Call Error'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.error.message),
                      if (state.error.userAction != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          state.error.userAction!,
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
      builder: (context, state) {
        final theme = Theme.of(context);

        String title = 'Connecting…';
        String subtitle = 'Channel: ${widget.channelId}';
        bool muted = false;
        bool speakerOn = true;
        int participants = 1;
        String timer = '00:00';

        if (state is CallOngoing) {
          title = 'In Call';
          participants = 1 + state.remoteUids.length;
          muted = state.muted;
          speakerOn = state.speakerOn;
          timer = _formatDuration(state.elapsed);
        } else if (state is CallConnecting) {
          title = 'Connecting…';
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Voice Call',
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Participants: $participants',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  timer,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _roundIconButton(
                        icon: muted ? Icons.mic_off : Icons.mic,
                        label: muted ? 'Unmute' : 'Mute',
                        color: Colors.white,
                        onTap: () => context.read<CallBloc>().add(ToggleMute()),
                      ),
                      _roundIconButton(
                        icon: Icons.call_end,
                        label: 'Hang up',
                        color: Colors.redAccent,
                        onTap: () => context.read<CallBloc>().add(EndCall()),
                      ),
                      _roundIconButton(
                        icon: speakerOn ? Icons.volume_up : Icons.hearing,
                        label: speakerOn ? 'Speaker' : 'Earpiece',
                        color: Colors.white,
                        onTap:
                            () => context.read<CallBloc>().add(ToggleSpeaker()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkResponse(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  static int _uidFromUuid(String uuid) {
    if (uuid.isNotEmpty) {
      final hex = uuid.replaceAll('-', '');
      final first8 =
          hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
      return int.tryParse(first8, radix: 16) ?? 1;
    }
    return 1;
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
}
