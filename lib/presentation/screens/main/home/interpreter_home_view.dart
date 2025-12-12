import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InterpreterHomeView extends StatefulWidget {
  const InterpreterHomeView({super.key});

  @override
  State<InterpreterHomeView> createState() => _InterpreterHomeViewState();
}

class _InterpreterHomeViewState extends State<InterpreterHomeView> {
  bool isProcessingJob = false; // To show button loading state
  String? processingJobId; // Track which job is being accepted/declined
  bool _isVerified = false;
  bool _isSuspended = false;
  int _totalSessions = 0;
  bool _isLoadingProfile = true;

  // Employment type for online/offline toggle visibility
  String? _employmentType; // 'volunteer' or 'paid'

  /// Build a stable int UID from the authenticated user UUID
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
    _loadInterpreterProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeAddToJobsBloc(LoadAvailableJobs());
      }
    });
  }

  bool _isOnline = false;

  Future<void> _loadInterpreterProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Check verification and suspension status
      final interpreterData =
          await Supabase.instance.client
              .from('interpreter_details')
              .select('is_verified, is_suspended, is_online')
              .eq('user_id', userId)
              .maybeSingle();

      // 2. Get user profile for employment type (to show online/offline toggle for paid only)
      final profileData =
          await Supabase.instance.client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', userId)
              .maybeSingle();

      // 3. Count total completed sessions (calls)
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
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('interpreter_details')
          .update({'is_online': value})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error updating online status: $e');
      // Revert on error
      if (mounted) {
        setState(() => _isOnline = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: ColorManager.error,
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(InterpreterHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This is called when the widget is rebuilt (e.g., returning from chat)
    // Reload jobs to ensure fresh data
    if (mounted) {
      _safeAddToJobsBloc(LoadAvailableJobs());
      _loadInterpreterProfile(); // Reload profile stats too
    }
  }

  Future<void> _refreshJobs() async {
    _safeAddToJobsBloc(RefreshJobs());
    await _loadInterpreterProfile();
    // Optionally await bloc state change here if you want
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _onAcceptJob(String jobId) {
    setState(() {
      isProcessingJob = true;
      processingJobId = jobId;
    });
    _safeAddToJobsBloc(AcceptJob(jobId));
  }

  void _onDeclineJob(String jobId) {
    setState(() {
      isProcessingJob = true;
      processingJobId = jobId;
    });
    _safeAddToJobsBloc(DeclineJob(jobId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshJobs,
          child: ListView(
            padding: const EdgeInsets.all(AppSize.s16),
            children: [
              // Header with status
              Container(
                padding: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  color: ColorManager.primary2,
                  borderRadius: BorderRadius.circular(AppSize.s12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: AppSize.s24,
                      backgroundColor: ColorManager.white,
                      child: Icon(
                        Icons.person,
                        color: ColorManager.primary2,
                        size: AppSize.s24,
                      ),
                    ),
                    const SizedBox(width: AppSize.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              color: ColorManager.white,
                              fontSize: AppSize.s18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSize.s4),
                          Text(
                            _isVerified
                                ? 'Verified Interpreter'
                                : 'Pending Verification',
                            style: TextStyle(
                              color: ColorManager.white.withValues(alpha: 0.8),
                              fontSize: AppSize.s14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Only show online/offline toggle for experienced (paid) interpreters
                    if (_isVerified &&
                        !_isSuspended &&
                        _employmentType == 'paid')
                      Column(
                        children: [
                          Switch(
                            value: _isOnline,
                            onChanged: _toggleOnlineStatus,
                            activeColor: ColorManager.white,
                            activeTrackColor: ColorManager.success,
                            inactiveThumbColor: ColorManager.white,
                            inactiveTrackColor: ColorManager.grey,
                          ),
                          Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: ColorManager.white,
                              fontSize: AppSize.s12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSize.s16),

              // Total Sessions Card
              Container(
                padding: const EdgeInsets.all(AppSize.s20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSize.s12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColorManager.primary2.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history,
                        color: ColorManager.primary2,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Sessions',
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorManager.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoadingProfile ? '...' : '$_totalSessions',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSize.s24),

              if (_isLoadingProfile)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_isSuspended)
                _buildSuspendedView()
              else if (!_isVerified)
                // Quizzes completed (via quiz hub), waiting for admin verification
                _buildPendingVerificationView()
              else ...[
                // Verified - show available jobs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.availableJobs,
                      style: TextStyle(
                        fontSize: AppSize.s18,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSize.s16),

                BlocConsumer<InterpreterJobBloc, InterpreterJobState>(
                  listener: (context, state) {
                    // ✅ Navigate directly to call when a job is accepted
                    if (state is InterpreterJobAccepted) {
                      final request = state.request;
                      final isVideoCall = request.callType == 'video';
                      final myUid = _uidFromUuid(request.acceptedBy!);

                      // Start the call via CallBloc
                      context.read<CallBloc>().add(
                        StartCall(
                          channelId: request.id,
                          localUid: myUid,
                          isVideoCall: isVideoCall,
                        ),
                      );

                      // Navigate to call screen
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => EnhancedCallScreen(
                                channelId: request.id,
                                isVideoCall: isVideoCall,
                              ),
                        ),
                        (route) =>
                            false, // Clear stack, so back goes to main home
                      );
                    }

                    // ✅ Show error message if job acceptance/decline fails
                    if (state is InterpreterJobError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.message.contains('already accepted')
                                ? 'This job was already taken by another interpreter'
                                : 'Error: ${state.message}',
                          ),
                          backgroundColor: ColorManager.error,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }

                    // ✅ Reset button states on load or error
                    if (state is InterpreterJobLoaded ||
                        state is InterpreterJobError) {
                      if (mounted) {
                        setState(() {
                          isProcessingJob = false;
                          processingJobId = null;
                        });
                      }
                    }
                  },
                  builder: (context, state) {
                    // Handle the accepted state by showing loading until jobs are reloaded
                    if (state is InterpreterJobAccepted) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is InterpreterJobLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is InterpreterJobError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: AppSize.s60,
                              color: ColorManager.error,
                            ),
                            const SizedBox(height: AppSize.s16),
                            Text(
                              'Error loading jobs',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSize.s8),
                            Text(
                              state.message,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSize.s16),
                            ElevatedButton(
                              onPressed: () {
                                _safeAddToJobsBloc(LoadAvailableJobs());
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (state is InterpreterJobLoaded) {
                      if (state.jobs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_off,
                                size: AppSize.s60,
                                color: ColorManager.grey,
                              ),
                              const SizedBox(height: AppSize.s16),
                              Text(
                                'No available jobs',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSize.s8),
                              Text(
                                'Check back later for new interpreter requests',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: ColorManager.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSize.s16),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children:
                            state.jobs.map((job) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSize.s12,
                                ),
                                child: _buildJobCardFromRequest(job),
                              );
                            }).toList(),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingVerificationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 80,
              color: Colors.orange.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Account Pending Verification',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorManager.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your interpreter profile is currently under review. You will be able to accept jobs once an administrator verifies your account.',
              style: TextStyle(
                fontSize: 16,
                color: ColorManager.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _loadInterpreterProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quiz views removed - now handled by InterpreterQuizHubScreen

  Widget _buildSuspendedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: ColorManager.error),
            const SizedBox(height: 24),
            Text(
              'Account Suspended',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorManager.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your interpreter account has been suspended by an administrator. You cannot accept new jobs at this time.',
              style: TextStyle(
                fontSize: 16,
                color: ColorManager.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _loadInterpreterProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCardFromRequest(InterpreterRequest request) {
    final isUrgent = request.urgency.toLowerCase() == 'urgent';

    // Convert language IDs to names
    final fromLanguageId = int.tryParse(request.fromLanguage) ?? 0;
    final toLanguageId = int.tryParse(request.toLanguage) ?? 0;
    final fromLanguageName = LanguageMappingUtility.getLanguageName(
      fromLanguageId,
    );
    final toLanguageName = LanguageMappingUtility.getLanguageName(toLanguageId);

    // Use language names if available, otherwise fallback to IDs
    final language =
        fromLanguageName.isNotEmpty && toLanguageName.isNotEmpty
            ? '$fromLanguageName - $toLanguageName'
            : '${request.fromLanguage} - ${request.toLanguage}';

    final specialization = request.specialization ?? 'General';
    final description = request.description ?? 'Interpreter request';
    final isProcessingThisJob =
        isProcessingJob && processingJobId == request.id;

    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(color: ColorManager.greyMedium.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  specialization,
                  style: TextStyle(
                    fontSize: AppSize.s16,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSize.s8,
                    vertical: AppSize.s4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppSize.s4),
                  ),
                  child: const Text(
                    AppStrings.urgent,
                    style: TextStyle(
                      fontSize: AppSize.s10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSize.s8),
          Text(
            description,
            style: TextStyle(
              fontSize: AppSize.s14,
              color: ColorManager.textSecondary,
            ),
          ),
          const SizedBox(height: AppSize.s12),
          Row(
            children: [
              Icon(
                Icons.language,
                size: AppSize.s16,
                color: ColorManager.primary2,
              ),
              const SizedBox(width: AppSize.s4),
              Text(
                language,
                style: TextStyle(
                  fontSize: AppSize.s12,
                  color: ColorManager.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${request.urgency} Priority',
                style: TextStyle(
                  fontSize: AppSize.s12,
                  fontWeight: FontWeight.bold,
                  color: _getUrgencyColor(request.urgency),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: AppSize.s16,
                color: ColorManager.textSecondary,
              ),
              const SizedBox(width: AppSize.s4),
              Expanded(
                child: Text(
                  'Requested ${_formatTimeAgo(request.createdAt)}',
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      isProcessingThisJob
                          ? null
                          : () => _onAcceptJob(request.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primary2,
                    foregroundColor: ColorManager.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s8,
                      vertical: AppSize.s8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSize.s6),
                    ),
                  ),
                  child:
                      isProcessingThisJob
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            AppStrings.acceptJob,
                            style: TextStyle(fontSize: AppSize.s12),
                            textAlign: TextAlign.center,
                          ),
                ),
              ),
              const SizedBox(width: AppSize.s8),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      isProcessingThisJob
                          ? null
                          : () => _onDeclineJob(request.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorManager.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s8,
                      vertical: AppSize.s8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSize.s6),
                    ),
                  ),
                  child:
                      isProcessingThisJob
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text(
                            AppStrings.declineJob,
                            style: TextStyle(fontSize: AppSize.s12),
                            textAlign: TextAlign.center,
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.green;
      case 'low':
        return Colors.blue;
      default:
        return ColorManager.primary2;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
