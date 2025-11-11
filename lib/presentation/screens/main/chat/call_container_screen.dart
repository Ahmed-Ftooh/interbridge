import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/widgets/draggable_call_widget.dart';

/// This screen acts as a container that shows the ChatView in the background
/// and stacks the DraggableCallWidget on top, allowing the user to chat
/// while in a call.
class CallContainerScreen extends StatelessWidget {
  final Widget chatScreen; // The ChatView instance
  final String requestId;
  final bool isRequester; // To know whether to show feedback
  final Function() onCallEnded; // Callback to show feedback dialog

  const CallContainerScreen({
    super.key,
    required this.chatScreen,
    required this.requestId,
    required this.isRequester,
    required this.onCallEnded,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CallBloc(service: CallService()),
      child: Scaffold(
        body: Stack(
          children: [
            // 1. The Chat Screen (in the background)
            chatScreen,

            // 2. The Draggable Call UI (on top)
            DraggableCallWidget(
              channelId: requestId,
              onCallEnded: (callDuration) {
                // When call ends, pop this container screen
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                // Then trigger the feedback dialog (if requester)
                if (isRequester) {
                  onCallEnded();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
