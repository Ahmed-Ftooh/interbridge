import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/data/services/incoming_call_service.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view_web.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';

/// Modern web-specific interpreter home view with dashboard layout
class InterpreterHomeWeb extends StatefulWidget {
  const InterpreterHomeWeb({super.key});

  @override
  State<InterpreterHomeWeb> createState() => _InterpreterHomeWebState();
}

class _InterpreterHomeWebState extends State<InterpreterHomeWeb>
    with WidgetsBindingObserver {
  String? _firstLanguageName;
  String? _secondLanguageName;
  bool isProcessingJob = false;
  String? processingJobId;
  bool _isVerified = false;
  bool _isSuspended = false;
  int _totalSessions = 0;
  int _thisWeekSessions = 0;
  double _avgRating = 0.0;
  int _totalFeedback = 0;
  List<Map<String, dynamic>> _recentCalls = [];
  bool _isLoadingProfile = true;
  String? _employmentType;
  bool _isOnline = false;
  String _interpreterName = '';
  String _interpreterIdStr = '';

  final CallService _callService = CallService();
  final IncomingCallService _incomingCallService = IncomingCallService();

  void _safeAddToJobsBloc(InterpreterJobEvent event) {
    if (!mounted) return;
    final bloc = context.read<InterpreterJobBloc>();
    if (!bloc.isClosed) {
      bloc.add(event);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInterpreterProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeAddToJobsBloc(LoadAvailableJobs());
        // Auto-set online on web and start listening for calls
        _autoGoOnlineAndListen();
      }
    });
  }

  /// On web, automatically set interpreter online and start listening.
  /// This ensures ringing works without manually toggling the switch.
  Future<void> _autoGoOnlineAndListen() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Check current online status first
      final data =
          await Supabase.instance.client
              .from('interpreter_details')
              .select('is_online, is_verified, is_suspended')
              .eq('user_id', userId)
              .maybeSingle();

      final isVerified = data?['is_verified'] ?? false;
      final isSuspended = data?['is_suspended'] ?? false;
      final isAlreadyOnline = data?['is_online'] ?? false;

      // Only auto-enable for verified, non-suspended interpreters
      if (!isVerified || isSuspended) {
        log(
          'Web: Not auto-enabling online (verified=$isVerified, suspended=$isSuspended)',
        );
        return;
      }

      // Set online in DB if not already
      if (!isAlreadyOnline) {
        await Supabase.instance.client
            .from('interpreter_details')
            .update({'is_online': true})
            .eq('user_id', userId);
        log('Web: Auto-set interpreter online');
      }

      if (mounted) {
        setState(() => _isOnline = true);
      }

      // Now start listening — skip online check since we just wrote is_online=true
      _incomingCallService.startListening(skipOnlineCheck: true);
    } catch (e) {
      log('Web: Error auto-enabling online: $e');
      // Fallback: try listening anyway
      _incomingCallService.startListening(skipOnlineCheck: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallService.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _safeAddToJobsBloc(LoadAvailableJobs());
      if (_isOnline) {
        _incomingCallService.startListening();
      }
    }
  }

  Future<void> _loadInterpreterProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final interpreterData =
          await Supabase.instance.client
              .from('interpreter_details')
              .select('is_verified, is_suspended, is_online')
              .eq('user_id', userId)
              .maybeSingle();

      final profileData =
          await Supabase.instance.client
              .from('users_profile')
              .select('employment_type, username')
              .eq('user_id', userId)
              .maybeSingle();

      // Fetch interpreter languages and language catalog
      final interpreterLanguages = await Supabase.instance.client
          .from('interpreter_languages')
          .select('language_id')
          .eq('user_id', userId);
      final languageCatalog = await Supabase.instance.client
          .from('languages')
          .select('id, name');

      String? firstLanguageName;
      String? secondLanguageName;
      if (interpreterLanguages is List && interpreterLanguages.isNotEmpty) {
        // First language
        final firstLangId = interpreterLanguages[0]['language_id'];
        final firstMatch = (languageCatalog as List?)?.firstWhere(
          (l) => l['id'] == firstLangId,
          orElse: () => <String, dynamic>{},
        );
        if (firstMatch != null && firstMatch.isNotEmpty) {
          firstLanguageName = firstMatch['name'];
        }
        // Second language (if available)
        if (interpreterLanguages.length > 1) {
          final secondLangId = interpreterLanguages[1]['language_id'];
          final secondMatch = (languageCatalog as List?)?.firstWhere(
            (l) => l['id'] == secondLangId,
            orElse: () => <String, dynamic>{},
          );
          if (secondMatch != null && secondMatch.isNotEmpty) {
            secondLanguageName = secondMatch['name'];
          }
        }
      }
      final sessionsCount = await Supabase.instance.client
          .from('interpreter_requests')
          .count(CountOption.exact)
          .eq('accepted_by', userId)
          .eq('status', 'completed');

      // Fetch this week's sessions
      final weekStart = DateTime.now().subtract(
        Duration(days: DateTime.now().weekday - 1),
      );
      final weekSessions = await Supabase.instance.client
          .from('call_sessions')
          .select('id')
          .or('user_id.eq.$userId,remote_user_id.eq.$userId')
          .gte('created_at', weekStart.toIso8601String());

      // Fetch average rating from feedback received (where interpreter is the remote user)
      final feedbackStats = await _callService.getFeedbackStatistics(
        userId: userId,
      );

      // Fetch recent call sessions
      final recentCalls = await _callService.getRecentCallSessions(
        userId: userId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _isVerified = interpreterData?['is_verified'] ?? false;
          _isSuspended = interpreterData?['is_suspended'] ?? false;
          _isOnline = interpreterData?['is_online'] ?? false;
          _totalSessions = sessionsCount;
          _thisWeekSessions = (weekSessions as List).length;
          _avgRating =
              (feedbackStats['average_rating'] as num?)?.toDouble() ?? 0.0;
          _totalFeedback = feedbackStats['total_feedback'] as int? ?? 0;
          _recentCalls = recentCalls;
          _employmentType = profileData?['employment_type'] ?? 'volunteer';
          _interpreterName = profileData?['username'] ?? 'Interpreter';
          final fullIdStr = uidFromUuid(userId).toString();
          _interpreterIdStr =
              fullIdStr.length > 5 ? fullIdStr.substring(0, 5) : fullIdStr;
          _isLoadingProfile = false;
          _firstLanguageName = firstLanguageName;
          _secondLanguageName = secondLanguageName;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final previousValue = _isOnline;
    setState(() => _isOnline = value);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('interpreter_details')
          .update({'is_online': value})
          .eq('user_id', userId);

      if (value) {
        _incomingCallService.startListening();
      } else {
        _incomingCallService.stopListening();
      }
    } catch (e) {
      debugPrint('Error toggling online status: $e');
      setState(() => _isOnline = previousValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1400;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          _buildStatusBanner(),
          const SizedBox(height: 24),

          // Main content
          // Only show jobs and call features for verified, non-suspended interpreters
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_isSuspended)
            _buildSuspendedView()
          else if (!_isVerified)
            _buildPendingVerificationWebView()
          else if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildScriptCard(),
                      const SizedBox(height: 24),
                      _buildJobsSection(),
                      const SizedBox(height: 24),
                      _buildRecentCallsSection(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [_buildStatsCard(), const SizedBox(height: 24)],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 24),
                _buildScriptCard(),
                const SizedBox(height: 24),
                _buildJobsSection(),
                const SizedBox(height: 24),
                _buildRecentCallsSection(),
                const SizedBox(height: 24),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_isLoadingProfile) {
      return const SizedBox.shrink();
    }

    if (_isSuspended) {
      return _buildAlertBanner(
        'Account Suspended',
        'Your account has been suspended. Please contact support.',
        Colors.red,
        Icons.block,
      );
    }

    if (!_isVerified) {
      return _buildAlertBanner(
        'Verification Pending',
        'Your account is being reviewed. You\'ll be notified once approved.',
        Colors.orange,
        Icons.hourglass_empty,
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorManager.primaryLight, ColorManager.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0955FA).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NEW: Name and Premium Welcome Text
                Text(
                  'Welcome back, ${_interpreterName.split(" ").first}! 👋',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // NEW: Show Interpreter ID clearly for doctors to copy
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Text(
                      'Ready to bridge the gap? You have completed $_totalSessions sessions.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    // Built-in ID Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Interpreter ID: ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _interpreterIdStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 32),

          // NEW: The integrated Online/Offline Switch Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color:
                            _isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        boxShadow:
                            _isOnline
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF22C55E,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color:
                            _isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 60,
                  height: 36,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: Switch(
                      value: _isOnline,
                      onChanged:
                          _isVerified && !_isSuspended
                              ? _toggleOnlineStatus
                              : null,
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF22C55E),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(
    String title,
    String message,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationWebView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: Colors.orange.shade400,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Account Pending Verification',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your interpreter profile is currently under review by our team.\nYou will be able to accept jobs and receive calls once verified.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _loadInterpreterProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Status'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              foregroundColor: const Color(0xFF0955FA),
              side: const BorderSide(color: Color(0xFF0955FA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspendedView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block, size: 64, color: Colors.red),
          ),
          const SizedBox(height: 32),
          const Text(
            'Account Suspended',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your interpreter account has been suspended.\nPlease contact support for more information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _loadInterpreterProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Status'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          _buildStatTile(
            'Total Sessions',
            _totalSessions.toString(),
            Icons.call,
            const Color(0xFF0955FA),
          ),
          const Divider(height: 24),
          _buildStatTile(
            'This Week',
            _thisWeekSessions.toString(),
            Icons.calendar_today,
            const Color(0xFF22C55E),
          ),
          const Divider(height: 24),
          _buildStatTile(
            'Avg. Rating',
            _totalFeedback > 0 ? _avgRating.toStringAsFixed(1) : '—',
            Icons.star,
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildJobsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Requests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Accept a request to start interpreting',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _safeAddToJobsBloc(LoadAvailableJobs()),
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          BlocBuilder<InterpreterJobBloc, InterpreterJobState>(
            builder: (context, state) {
              if (state is InterpreterJobLoading) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0955FA),
                      ),
                    ),
                  ),
                );
              }

              if (state is InterpreterJobError) {
                return Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: const TextStyle(color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              () => _safeAddToJobsBloc(LoadAvailableJobs()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0955FA),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is InterpreterJobLoaded) {
                final jobs = state.jobs;
                if (jobs.isEmpty) {
                  return _buildEmptyJobsState();
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _buildJobCard(jobs[index]),
                );
              }

              return _buildEmptyJobsState();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyJobsState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No requests available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'New interpretation requests will appear here.',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(InterpreterRequest job) {
    final isProcessing = processingJobId == job.id;
    final fromLang = job.fromLanguage;
    final toLang = job.toLanguage;
    final timeAgo = _formatTimeAgo(job.createdAt);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Language info
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.translate,
                    color: Color(0xFF0955FA),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$fromLang → $toLang',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            job.callType == 'video'
                                ? Icons.videocam
                                : Icons.phone,
                            size: 14,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            job.callType == 'video'
                                ? 'Video Call'
                                : 'Voice Call',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Type badge
          if (job.specialization != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    job.specialization != null
                        ? const Color(0xFF9333EA).withValues(alpha: 0.1)
                        : const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                job.specialization ?? 'General',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      job.specialization != null
                          ? const Color(0xFF9333EA)
                          : const Color(0xFF0EA5E9),
                ),
              ),
            ),
          // Accept button
          ElevatedButton(
            onPressed: isProcessing ? null : () => _acceptJob(job),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child:
                isProcessing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dateTime);
  }

  Future<void> _acceptJob(InterpreterRequest job) async {
    if (isProcessingJob) return;

    setState(() {
      isProcessingJob = true;
      processingJobId = job.id;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Use InterpreterJobService for atomic accept (only if still pending)
      final jobService = InterpreterJobService();
      final acceptedRequest = await jobService.acceptJob(job.id);

      if (acceptedRequest == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This request was already accepted by another interpreter',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Save session for recovery
      await SessionService.saveSession(
        requestId: job.id,
        requesterId: job.requesterId,
        interpreterId: userId,
        currentScreen: 'call',
      );

      if (!mounted) return;

      // Fire StartCall on CallBloc BEFORE navigating
      final isVideoCall = job.callType == 'video';
      final myUid = uidFromUuid(userId);

      context.read<CallBloc>().add(
        StartCall(channelId: job.id, localUid: myUid, isVideoCall: isVideoCall),
      );

      log('Web: Accepted job ${job.id}, starting call (video: $isVideoCall)');

      // Navigate to web call screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => EnhancedCallScreenWeb(
                channelId: job.id,
                isVideoCall: isVideoCall,
              ),
        ),
      );
    } catch (e) {
      debugPrint('Error accepting job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessingJob = false;
          processingJobId = null;
        });
      }
    }
  }

  Widget _buildRecentCallsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Sessions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recentCalls.isEmpty
                          ? 'No sessions yet'
                          : 'Your last ${_recentCalls.length} interpretation sessions',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (_totalFeedback > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_avgRating.toStringAsFixed(1)} avg',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_recentCalls.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.history,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No sessions yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your completed sessions will appear here.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentCalls.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final call = _recentCalls[index];
                return _buildRecentCallTile(call);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentCallTile(Map<String, dynamic> call) {
    final durationSec = call['duration_seconds'] as int? ?? 0;
    final callType = call['call_type'] as String? ?? 'voice';
    final quality = call['connection_quality'] as String? ?? '';
    final startedAt = DateTime.tryParse(call['started_at'] ?? '');

    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    final durationStr = '${minutes}m ${seconds.toString().padLeft(2, '0')}s';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Call type icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  callType == 'video'
                      ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                      : const Color(0xFF0955FA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              callType == 'video' ? Icons.videocam : Icons.phone,
              color:
                  callType == 'video'
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF0955FA),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${callType == 'video' ? 'Video' : 'Voice'} Session',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      durationStr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (quality.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        quality == 'excellent' || quality == 'good'
                            ? Icons.signal_cellular_alt
                            : Icons.signal_cellular_alt_2_bar,
                        size: 14,
                        color:
                            quality == 'excellent' || quality == 'good'
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        quality,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              quality == 'excellent' || quality == 'good'
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (startedAt != null)
                Text(
                  DateFormat('MMM d').format(startedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              if (startedAt != null)
                Text(
                  DateFormat('h:mm a').format(startedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard() {
    final firstLanguage = _firstLanguageName ?? 'interpreter';
    final secondLanguage = _secondLanguageName ?? firstLanguage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Interpreter Introduction Script',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildScriptSection(
            title: 'Welcome the Doctor',
            content:
                'Hello, my name is $_interpreterName the $firstLanguage interpreter, My ID $_interpreterIdStr.\n'
                'Please speak in short segments for the highest accuracy. I’m ready when you are.',
            icon: Icons.medical_services_rounded,
            color: const Color(0xFF0955FA),
          ),
          const SizedBox(height: 20),
          _buildScriptSection(
            title: 'Greeting the Patient (in $firstLanguage)',
            content:
                'Hello, I\'m your $firstLanguage interpreter, everything you say will be interpreted accurately and will be confidential. Thank you.',
            icon: Icons.person_rounded,
            color: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptSection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
