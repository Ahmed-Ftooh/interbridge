import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/core/language_mapping_utility.dart';

class InterpreterHomeView extends StatefulWidget {
  const InterpreterHomeView({super.key});

  @override
  State<InterpreterHomeView> createState() => _InterpreterHomeViewState();
}

class _InterpreterHomeViewState extends State<InterpreterHomeView> {
  bool isProcessingJob = false; // To show button loading state
  String? processingJobId; // Track which job is being accepted/declined

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeAddToJobsBloc(LoadAvailableJobs());
      }
    });
  }

  Future<void> _refreshJobs() async {
    _safeAddToJobsBloc(RefreshJobs());
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSize.s24),

              // Available Jobs header with "View All" button (add navigation later)
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
                  // ✅ Navigate when a job is accepted
                  if (state is InterpreterJobAccepted) {
                    // Use push instead of pushReplacement to allow going back
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BlocProvider(
                              create: (_) => ChatBloc(service: ChatService()),
                              child: ChatView(
                                requestId: state.request.id,
                                requesterId: state.request.requesterId,
                                interpreterId: state.request.acceptedBy!,
                              ),
                            ),
                      ),
                      (route) => false,
                    );
                  }

                  // ✅ Reset button states on load or error
                  if (state is InterpreterJobLoaded ||
                      state is InterpreterJobError) {
                    setState(() {
                      isProcessingJob = false;
                      processingJobId = null;
                    });
                  }
                },
                builder: (context, state) {
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
          ),
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
