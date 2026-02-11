import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/incoming_call_service.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';

/// Modern web-specific interpreter home view with dashboard layout
class InterpreterHomeWeb extends StatefulWidget {
  const InterpreterHomeWeb({super.key});

  @override
  State<InterpreterHomeWeb> createState() => _InterpreterHomeWebState();
}

class _InterpreterHomeWebState extends State<InterpreterHomeWeb>
    with WidgetsBindingObserver {
  bool isProcessingJob = false;
  String? processingJobId;
  bool _isVerified = false;
  bool _isSuspended = false;
  int _totalSessions = 0;
  bool _isLoadingProfile = true;
  String? _employmentType;
  bool _isOnline = false;

  final IncomingCallService _incomingCallService = IncomingCallService();

  static int _uidFromUuid(String uuid) {
    if (uuid.isNotEmpty) {
      final hex = uuid.replaceAll('-', '');
      final first8 =
          hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
      return int.tryParse(first8, radix: 16) ?? 1;
    }
    return 1;
  }

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
        _incomingCallService.startListening();
      }
    });
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
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();

      final sessionsCount = await Supabase.instance.client
          .from('interpreter_requests')
          .count(CountOption.exact)
          .eq('accepted_by', userId)
          .eq('status', 'completed');

      if (mounted) {
        setState(() {
          _isVerified = interpreterData?['is_verified'] ?? false;
          _isSuspended = interpreterData?['is_suspended'] ?? false;
          _isOnline = interpreterData?['is_online'] ?? false;
          _totalSessions = sessionsCount;
          _employmentType = profileData?['employment_type'] ?? 'volunteer';
          _isLoadingProfile = false;
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
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildJobsSection()),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildStatsCard(),
                      const SizedBox(height: 24),
                      _buildOnlineStatusCard(),
                      const SizedBox(height: 24),
                      _buildQuickActionsCard(),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildOnlineStatusCard(),
                const SizedBox(height: 24),
                _buildStatsCard(),
                const SizedBox(height: 24),
                _buildJobsSection(),
                const SizedBox(height: 24),
                _buildQuickActionsCard(),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _isOnline
                                ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  _isOnline
                                      ? const Color(0xFF22C55E)
                                      : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color:
                                  _isOnline
                                      ? const Color(0xFF22C55E)
                                      : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ready to Help 🎯',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have completed $_totalSessions interpretation sessions. Keep up the great work!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              size: 64,
              color: Colors.white,
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

  Widget _buildOnlineStatusCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Availability',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      _isOnline
                          ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            _isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            _isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isOnline
                ? 'You are currently available to receive interpretation requests.'
                : 'Toggle the switch to start receiving requests.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Accept Requests',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        _isVerified && !_isSuspended
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: _isOnline,
                  onChanged:
                      _isVerified && !_isSuspended ? _toggleOnlineStatus : null,
                  activeColor: const Color(0xFF22C55E),
                  inactiveThumbColor: const Color(0xFF94A3B8),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                ),
              ),
            ],
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
            '3',
            Icons.calendar_today,
            const Color(0xFF22C55E),
          ),
          const Divider(height: 24),
          _buildStatTile(
            'Avg. Rating',
            '4.9',
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

      // Update request status
      await Supabase.instance.client
          .from('interpreter_requests')
          .update({
            'status': 'accepted',
            'accepted_by': userId,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', job.id);

      // Navigate to call
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EnhancedCallScreen(channelId: job.id),
          ),
        );
      }
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

  Widget _buildQuickActionsCard() {
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
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'View History',
            Icons.history,
            const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Take Quiz',
            Icons.quiz_outlined,
            const Color(0xFF9333EA),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Earnings',
            Icons.account_balance_wallet_outlined,
            const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
