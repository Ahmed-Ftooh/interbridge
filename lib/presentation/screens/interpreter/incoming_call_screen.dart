import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomingCallScreen extends StatefulWidget {
  final InterpreterRequest request;
  final String fromLanguageName;
  final String toLanguageName;

  const IncomingCallScreen({
    super.key,
    required this.request,
    required this.fromLanguageName,
    required this.toLanguageName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAccepting = false;
  bool _isDeclining = false;
  bool _isRingtoneStopped = false;
  Timer? _timeoutTimer;
  RealtimeChannel? _statusChannel;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playRingtone();
    _setupStatusListener();
    _startTimeout();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _playRingtone() async {
    try {
      // Set source first, then play
      await _audioPlayer.setSourceAsset('audio/call_ring.mpeg');
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();
      log('Ringtone started playing');
    } catch (e) {
      log('Error playing ringtone: $e');
      // Try alternative approach
      try {
        await _audioPlayer.play(AssetSource('audio/call_ring.mpeg'));
        log('Ringtone playing with fallback method');
      } catch (e2) {
        log('Error playing ringtone (fallback): $e2');
      }
    }
  }

  Future<void> _stopRingtone() async {
    if (_isRingtoneStopped) return;
    _isRingtoneStopped = true;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.dispose();
      log('Ringtone stopped and disposed');
    } catch (e) {
      log('Error stopping ringtone: $e');
    }
  }

  void _setupStatusListener() {
    // Listen for request status changes (if someone else accepts first)
    _statusChannel =
        Supabase.instance.client
            .channel('incoming_call_${widget.request.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'interpreter_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: widget.request.id,
              ),
              callback: (payload) async {
                log('Mobile: Request event type: ${payload.eventType}');

                if (payload.eventType == PostgresChangeEvent.delete) {
                  log('Mobile: Request was deleted (cancelled)');
                  if (mounted && !_isAccepting) {
                    await _stopRingtone();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                  return;
                }

                final newStatus = payload.newRecord['status']?.toString();
                log('Mobile: Request status changed to: $newStatus');

                if (newStatus == 'accepted' || newStatus == 'cancelled') {
                  // Someone else accepted or request was cancelled
                  if (mounted && !_isAccepting) {
                    await _stopRingtone();
                    if (mounted) {
                      Navigator.of(context).pop();
                      if (newStatus == 'accepted') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Call was accepted by another interpreter',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  }
                }
              },
            )
            .subscribe();
  }

  void _startTimeout() {
    // Auto-decline after 60 seconds
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_isAccepting) {
        _declineCall();
      }
    });
  }

  @override
  void dispose() {
    _stopRingtone(); // Will check flag internally
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isAccepting || _isDeclining) return;

    setState(() => _isAccepting = true);
    await _stopRingtone();
    HapticFeedback.mediumImpact();

    try {
      final jobService = InterpreterJobService();
      final acceptedRequest = await jobService.acceptJob(widget.request.id);

      if (acceptedRequest == null) {
        // Someone else already accepted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This call was already accepted by another interpreter',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Save session
      await SessionService.saveSession(
        requestId: widget.request.id,
        requesterId: widget.request.requesterId,
        interpreterId: currentUserId,
        currentScreen: 'call',
      );

      if (!mounted) return;

      // Navigate to call screen
      final isVideoCall = widget.request.callType == 'video';
      final myUid = uidFromUuid(currentUserId);

      // Start the call via CallBloc
      context.read<CallBloc>().add(
        StartCall(
          channelId: widget.request.id,
          localUid: myUid,
          isVideoCall: isVideoCall,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder:
              (_) => EnhancedCallScreen(
                channelId: widget.request.id,
                isVideoCall: isVideoCall,
              ),
        ),
        (route) => false,
      );
    } catch (e) {
      log('Error accepting call: $e');
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineCall() async {
    if (_isAccepting || _isDeclining) return;

    setState(() => _isDeclining = true);
    await _stopRingtone();
    HapticFeedback.lightImpact();

    try {
      final jobService = InterpreterJobService();
      await jobService.declineJob(widget.request.id);
    } catch (e) {
      log('Error declining call: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.request.callType == 'video';

    return Scaffold(
      backgroundColor: ColorManager.primary2Dark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Call Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isVideoCall
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isVideoCall ? Colors.blue : Colors.green,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideoCall ? Icons.videocam : Icons.phone,
                    color: isVideoCall ? Colors.blue : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isVideoCall ? 'Video Call' : 'Voice Call',
                    style: TextStyle(
                      color: isVideoCall ? Colors.blue : Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Incoming Call Text
            const Text(
              'Incoming Call',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 30),

            // Animated Avatar
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [ColorManager.primary, ColorManager.primary2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ColorManager.primary.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Language Info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Languages
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.record_voice_over,
                                color: Colors.blue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'From',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.fromLanguageName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white.withOpacity(0.5),
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'To',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.toLanguageName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Specialization (if any)
                  if (widget.request.specialization != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.medical_information,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.request.specialization!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  GestureDetector(
                    onTap: _isDeclining ? null : _declineCall,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child:
                          _isDeclining
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                              : const Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 40,
                              ),
                    ),
                  ),

                  // Accept Button
                  GestureDetector(
                    onTap: _isAccepting ? null : _acceptCall,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child:
                          _isAccepting
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                              : Icon(
                                isVideoCall ? Icons.videocam : Icons.call,
                                color: Colors.white,
                                size: 40,
                              ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Button Labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
