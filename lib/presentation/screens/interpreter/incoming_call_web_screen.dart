import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Professional web incoming call screen with ringing and animations
class IncomingCallWebScreen extends StatefulWidget {
  final InterpreterRequest request;
  final String fromLanguageName;
  final String toLanguageName;

  const IncomingCallWebScreen({
    super.key,
    required this.request,
    required this.fromLanguageName,
    required this.toLanguageName,
  });

  @override
  State<IncomingCallWebScreen> createState() => _IncomingCallWebScreenState();
}

class _IncomingCallWebScreenState extends State<IncomingCallWebScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ring1Animation;
  late Animation<double> _ring2Animation;
  late Animation<double> _ring3Animation;
  late Animation<double> _fadeAnimation;

  bool _isAccepting = false;
  bool _isDeclining = false;
  bool _isRingtoneStopped = false;
  Timer? _timeoutTimer;
  RealtimeChannel? _statusChannel;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playRingtone();
    _setupStatusListener();
    _startTimeout();
    _startElapsedTimer();
  }

  void _setupAnimations() {
    // Pulse animation for the avatar
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ring wave animations (3 expanding rings)
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _ring1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _ring2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
      ),
    );
    _ring3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _playRingtone() async {
    try {
      await _audioPlayer.setSourceAsset('audio/Call_Ring.mp3');
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();
      log('Web: Ringtone started playing');
    } catch (e) {
      log('Web: Error playing ringtone: $e');
      try {
        await _audioPlayer.play(AssetSource('audio/Call_Ring.mp3'));
      } catch (e2) {
        log('Web: Error playing ringtone (fallback): $e2');
      }
    }
  }

  Future<void> _stopRingtone() async {
    if (_isRingtoneStopped) return;
    _isRingtoneStopped = true;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.dispose();
    } catch (e) {
      log('Web: Error stopping ringtone: $e');
    }
  }

  void _setupStatusListener() {
    _statusChannel =
        Supabase.instance.client
            .channel('incoming_call_web_${widget.request.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'interpreter_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: widget.request.id,
              ),
              callback: (payload) async {
                final newStatus = payload.newRecord['status']?.toString();
                log('Web: Request status changed to: $newStatus');

                if (newStatus == 'accepted' || newStatus == 'cancelled') {
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
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_isAccepting) {
        _declineCall();
      }
    });
  }

  @override
  void dispose() {
    _stopRingtone();
    _pulseController.dispose();
    _ringController.dispose();
    _fadeController.dispose();
    _timeoutTimer?.cancel();
    _elapsedTimer?.cancel();
    _statusChannel?.unsubscribe();
    super.dispose();
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

  Future<void> _acceptCall() async {
    if (_isAccepting || _isDeclining) return;

    setState(() => _isAccepting = true);
    await _stopRingtone();

    try {
      final jobService = InterpreterJobService();
      final acceptedRequest = await jobService.acceptJob(widget.request.id);

      if (acceptedRequest == null) {
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

      await SessionService.saveSession(
        requestId: widget.request.id,
        requesterId: widget.request.requesterId,
        interpreterId: currentUserId,
        currentScreen: 'call',
      );

      if (!mounted) return;

      final isVideoCall = widget.request.callType == 'video';
      final myUid = _uidFromUuid(currentUserId);

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
              (_) => EnhancedCallScreenWeb(
                channelId: widget.request.id,
                isVideoCall: isVideoCall,
              ),
        ),
        (route) => false,
      );
    } catch (e) {
      log('Web: Error accepting call: $e');
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

    try {
      final jobService = InterpreterJobService();
      await jobService.declineJob(widget.request.id);
    } catch (e) {
      log('Web: Error declining call: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.request.callType == 'video';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          // Full-screen dark overlay
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Color(0xFF0F172A), Color(0xFF1A1040)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: isCompact ? 24 : 40,
                horizontal: 16,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth > 800 ? 520 : screenWidth * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Call type badge
                    _buildCallTypeBadge(isVideoCall),
                    SizedBox(height: isCompact ? 16 : 32),

                    // "Incoming Call" title
                    Text(
                      'Incoming Interpretation Request',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_elapsedSeconds}s',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: isCompact ? 20 : 40),

                    // Animated avatar with ring waves
                    _buildAnimatedAvatar(isCompact),
                    SizedBox(height: isCompact ? 24 : 48),

                    // Language info card
                    _buildLanguageCard(isCompact),
                    SizedBox(height: isCompact ? 28 : 48),

                    // Action buttons
                    _buildActionButtons(isVideoCall, isCompact),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallTypeBadge(bool isVideoCall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: (isVideoCall ? const Color(0xFF3B82F6) : const Color(0xFF22C55E))
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isVideoCall
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF22C55E))
              .withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideoCall ? Icons.videocam_rounded : Icons.phone_rounded,
            color:
                isVideoCall ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isVideoCall ? 'Video Call' : 'Voice Call',
            style: TextStyle(
              color:
                  isVideoCall
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF22C55E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAvatar(bool isCompact) {
    final double avatarSize = isCompact ? 90 : 120;
    final double ringBase = isCompact ? 100 : 140;
    final double ringExpand = isCompact ? 40 : 60;
    final double containerSize = isCompact ? 150 : 200;

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring wave 1
          AnimatedBuilder(
            animation: _ring1Animation,
            builder: (context, child) {
              return Container(
                width: ringBase + (_ring1Animation.value * ringExpand),
                height: ringBase + (_ring1Animation.value * ringExpand),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: (1.0 - _ring1Animation.value) * 0.4),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Ring wave 2
          AnimatedBuilder(
            animation: _ring2Animation,
            builder: (context, child) {
              return Container(
                width: ringBase + (_ring2Animation.value * ringExpand),
                height: ringBase + (_ring2Animation.value * ringExpand),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: (1.0 - _ring2Animation.value) * 0.3),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
          // Ring wave 3
          AnimatedBuilder(
            animation: _ring3Animation,
            builder: (context, child) {
              return Container(
                width: ringBase + (_ring3Animation.value * ringExpand),
                height: ringBase + (_ring3Animation.value * ringExpand),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: (1.0 - _ring3Animation.value) * 0.2),
                    width: 1,
                  ),
                ),
              );
            },
          ),
          // Avatar
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.medical_services_rounded,
                size: isCompact ? 40 : 56,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 18 : 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Languages row
          Row(
            children: [
              Expanded(
                child: _buildLanguageColumn(
                  'From',
                  widget.fromLanguageName,
                  Icons.record_voice_over_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: _buildLanguageColumn(
                  'To',
                  widget.toLanguageName,
                  Icons.person_rounded,
                  const Color(0xFF22C55E),
                ),
              ),
            ],
          ),

          // Specialization
          if (widget.request.specialization != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.medical_information_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.request.specialization!,
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
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
    );
  }

  Widget _buildLanguageColumn(
    String label,
    String language,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          language,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isVideoCall, bool isCompact) {
    final double buttonSize = isCompact ? 60 : 72;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decline button
        _buildActionButton(
          onTap: _isDeclining ? null : _declineCall,
          icon: Icons.call_end_rounded,
          label: 'Decline',
          color: const Color(0xFFEF4444),
          isLoading: _isDeclining,
          size: buttonSize,
        ),
        SizedBox(width: isCompact ? 40 : 60),
        // Accept button
        _buildActionButton(
          onTap: _isAccepting ? null : _acceptCall,
          icon: isVideoCall ? Icons.videocam_rounded : Icons.call_rounded,
          label: 'Accept',
          color: const Color(0xFF22C55E),
          isLoading: _isAccepting,
          size: buttonSize,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required Color color,
    required bool isLoading,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor:
              onTap != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child:
                  isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                      : Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
