import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
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
  bool _isOnline = false;
  String _interpreterName = '';
  String _interpreterIdStr = '';

  // --- NEW: Admin Table Variables ---
  final TextEditingController _callLogsSearchCtrl = TextEditingController();
  final ScrollController _callLogsHorizontalController = ScrollController();
  Map<int, String> jobLanguagesMap = {};
  static const _adminHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Color(0xFF64748B),
    letterSpacing: 0.5,
  );

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
    _callLogsSearchCtrl.dispose();
    _callLogsHorizontalController.dispose();
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
              .select('username')
              .eq('user_id', userId)
              .maybeSingle();

      // Fetch interpreter languages and language catalog
      final interpreterLanguagesResponse = await Supabase.instance.client
          .from('interpreter_languages')
          .select('language_id')
          .eq('user_id', userId);

      final interpreterLanguages = List<Map<String, dynamic>>.from(
        interpreterLanguagesResponse,
      );

      final languageCatalogResponse = await Supabase.instance.client
          .from('languages')
          .select('id, name');

      final languageCatalog = List<Map<String, dynamic>>.from(
        languageCatalogResponse,
      );

      // --- NEW: Fill the jobLanguagesMap for the table ---
      final langMap = <int, String>{};
      for (final l in languageCatalog) {
        langMap[l['id']] = l['name'];
      }

      String? firstLanguageName;
      if (interpreterLanguages.isNotEmpty) {
        // First language
        final firstLangId = interpreterLanguages[0]['language_id'];
        final firstMatch = languageCatalog.firstWhere(
          (l) => l['id'] == firstLangId,
          orElse: () => <String, dynamic>{},
        );
        if (firstMatch.isNotEmpty) {
          firstLanguageName = firstMatch['name'];
        }
      }

      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      final totalSessionsCount = await Supabase.instance.client
          .from('call_logs')
          .count(CountOption.exact)
          .eq('interpreter_id', userId);

      final weekSessionsCount = await Supabase.instance.client
          .from('call_logs')
          .count(CountOption.exact)
          .eq('interpreter_id', userId)
          .gte('started_at', weekStart.toIso8601String());

      // Fetch call logs for this interpreter and resolve requester names.
      final logsResponse = await Supabase.instance.client
          .from('call_logs')
          .select('*')
          .eq('interpreter_id', userId)
          .order('started_at', ascending: false)
          .limit(100);

      final rawCalls = List<Map<String, dynamic>>.from(logsResponse);
      final recentCalls = <Map<String, dynamic>>[];
      final seenRequestIds = <String>{};
      final seenLogIds = <String>{};

      for (final row in rawCalls) {
        final durationSeconds = (row['duration_seconds'] as num?)?.toInt() ?? 0;
        if (durationSeconds <= 0) {
          continue;
        }

        final startedAtRaw = row['started_at']?.toString() ?? '';
        if (startedAtRaw.isEmpty) {
          continue;
        }

        final requestId = row['request_id']?.toString() ?? '';
        final logId = row['id']?.toString() ?? '';

        if (requestId.isNotEmpty) {
          if (!seenRequestIds.add(requestId)) {
            continue;
          }
        } else if (logId.isNotEmpty) {
          if (!seenLogIds.add(logId)) {
            continue;
          }
        }

        recentCalls.add(row);
      }

      final requestIds =
          recentCalls
              .map((row) => row['request_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

      final requestCallTypes = <String, String>{};
      if (requestIds.isNotEmpty) {
        final requestRows = await Supabase.instance.client
            .from('interpreter_requests')
            .select('id, call_type')
            .inFilter('id', requestIds);

        for (final row in requestRows) {
          final item = Map<String, dynamic>.from(row);
          final id = item['id']?.toString();
          final callType = item['call_type']?.toString();
          if (id != null &&
              id.isNotEmpty &&
              callType != null &&
              callType.isNotEmpty) {
            requestCallTypes[id] = callType;
          }
        }
      }

      for (final row in recentCalls) {
        final requestId = row['request_id']?.toString();
        row['_session_call_type'] =
            (requestId != null ? requestCallTypes[requestId] : null) ??
            row['call_type']?.toString() ??
            'unknown';
      }

      double avgRating = 0.0;
      int totalFeedback = 0;
      final requestIdsForFeedback =
          recentCalls
              .map((row) => row['request_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

      if (requestIdsForFeedback.isEmpty) {
        final ratingCallRows = await Supabase.instance.client
            .from('call_logs')
            .select('request_id')
            .eq('interpreter_id', userId)
            .order('started_at', ascending: false)
            .limit(500);

        for (final row in ratingCallRows) {
          final item = Map<String, dynamic>.from(row);
          final requestId = item['request_id']?.toString();
          if (requestId != null && requestId.isNotEmpty) {
            requestIdsForFeedback.add(requestId);
          }
        }
      }

      if (requestIdsForFeedback.isNotEmpty) {
        final feedbackResponse = await Supabase.instance.client
            .from('call_feedback')
            .select('rating, user_id, channel_id')
            .inFilter('channel_id', requestIdsForFeedback.toList())
            .neq('user_id', userId);

        final feedbackRows = List<Map<String, dynamic>>.from(feedbackResponse);
        final ratings = <double>[];
        for (final row in feedbackRows) {
          final rating = (row['rating'] as num?)?.toDouble();
          if (rating != null) {
            ratings.add(rating);
          }
        }

        if (ratings.isNotEmpty) {
          totalFeedback = ratings.length;
          avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
        }
      }

      // Fallback: if ratings are still empty, derive channels directly
      // from accepted interpreter requests instead of relying on call_logs.
      if (totalFeedback == 0) {
        final acceptedRequestsResponse = await Supabase.instance.client
            .from('interpreter_requests')
            .select('id, requester_id')
            .eq('accepted_by', userId)
            .limit(1000);

        final acceptedRequests = List<Map<String, dynamic>>.from(
          acceptedRequestsResponse,
        );

        final fallbackChannelIds = <String>[];
        final requesterByChannel = <String, String>{};

        for (final row in acceptedRequests) {
          final channelId = row['id']?.toString();
          final requesterId = row['requester_id']?.toString();
          if (channelId == null || channelId.isEmpty) continue;
          fallbackChannelIds.add(channelId);
          if (requesterId != null && requesterId.isNotEmpty) {
            requesterByChannel[channelId] = requesterId;
          }
        }

        if (fallbackChannelIds.isNotEmpty) {
          final fallbackRatings = <double>[];
          const chunkSize = 200;

          for (var i = 0; i < fallbackChannelIds.length; i += chunkSize) {
            final end =
                (i + chunkSize) < fallbackChannelIds.length
                    ? (i + chunkSize)
                    : fallbackChannelIds.length;

            final chunk = fallbackChannelIds.sublist(i, end);

            final feedbackChunkResponse = await Supabase.instance.client
                .from('call_feedback')
                .select('rating, user_id, channel_id')
                .inFilter('channel_id', chunk)
                .neq('user_id', userId);

            final feedbackRows = List<Map<String, dynamic>>.from(
              feedbackChunkResponse,
            );

            for (final row in feedbackRows) {
              final channelId = row['channel_id']?.toString();
              final authorUserId = row['user_id']?.toString();
              if (channelId == null ||
                  channelId.isEmpty ||
                  authorUserId == null) {
                continue;
              }

              final expectedRequesterId = requesterByChannel[channelId];
              if (expectedRequesterId != null &&
                  expectedRequesterId.isNotEmpty &&
                  authorUserId != expectedRequesterId) {
                continue;
              }

              final rating = (row['rating'] as num?)?.toDouble();
              if (rating != null) {
                fallbackRatings.add(rating);
              }
            }
          }

          if (fallbackRatings.isNotEmpty) {
            totalFeedback = fallbackRatings.length;
            avgRating =
                fallbackRatings.reduce((a, b) => a + b) /
                fallbackRatings.length;
          }
        }
      }

      final requesterIds = <String>{};
      for (final logRow in recentCalls) {
        final requesterId = logRow['requester_id']?.toString();
        if (requesterId != null && requesterId.isNotEmpty) {
          requesterIds.add(requesterId);
        }
      }

      final requesterProfiles = <String, Map<String, dynamic>>{};
      if (requesterIds.isNotEmpty) {
        final requesterRows = await Supabase.instance.client
            .from('users_profile')
            .select('user_id, username')
            .inFilter('user_id', requesterIds.toList());

        for (final row in requesterRows) {
          final item = Map<String, dynamic>.from(row);
          final requesterId = item['user_id']?.toString();
          if (requesterId != null && requesterId.isNotEmpty) {
            requesterProfiles[requesterId] = item;
          }
        }
      }

      for (final row in recentCalls) {
        final requesterId = row['requester_id']?.toString();
        row['_requester'] =
            requesterId == null ? null : requesterProfiles[requesterId];
      }

      if (mounted) {
        setState(() {
          jobLanguagesMap = langMap; // Save map to state
          _isVerified = interpreterData?['is_verified'] ?? false;
          _isSuspended = interpreterData?['is_suspended'] ?? false;
          _isOnline = interpreterData?['is_online'] ?? false;
          _totalSessions = totalSessionsCount;
          _thisWeekSessions = weekSessionsCount;
          _avgRating = avgRating;
          _totalFeedback = totalFeedback;
          _recentCalls = recentCalls;
          _interpreterName = profileData?['username'] ?? 'Interpreter';
          final fullIdStr = uidFromUuid(userId).toString();
          _interpreterIdStr =
              fullIdStr.length > 5 ? fullIdStr.substring(0, 5) : fullIdStr;
          _isLoadingProfile = false;
          _firstLanguageName = firstLanguageName;
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

  // --- NEW: Helper method to filter calls based on search bar ---
  List<Map<String, dynamic>> _getFilteredCalls() {
    final query = _callLogsSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _recentCalls;

    return _recentCalls.where((call) {
      final callType = call['_session_call_type']?.toString() ?? '';
      final requestId = call['request_id']?.toString() ?? '';
      final customRequestId = _formatCustomRequestId(requestId);

      final metadataRaw = call['metadata'];
      final metadata =
          metadataRaw is Map<String, dynamic>
              ? metadataRaw
              : metadataRaw is Map
              ? Map<String, dynamic>.from(metadataRaw)
              : const <String, dynamic>{};

      final fromLang = _resolveLanguageName(metadata['from_language']);
      final toLang = _resolveLanguageName(metadata['to_language']);

      final searchable =
          '$requestId $customRequestId $callType $fromLang $toLang'
              .toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  String _formatCustomRequestId(String requestId) {
    if (requestId.isEmpty) return '-----';

    try {
      final numeric = uidFromUuid(requestId).toString();
      return numeric.length >= 5
          ? numeric.substring(0, 5)
          : numeric.padLeft(5, '0');
    } catch (_) {
      final digits = requestId.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return digits.length >= 5
            ? digits.substring(0, 5)
            : digits.padLeft(5, '0');
      }

      return requestId.length >= 5 ? requestId.substring(0, 5) : requestId;
    }
  }

  void _scrollCallLogsHorizontally(double delta) {
    if (!_callLogsHorizontalController.hasClients) return;

    final position = _callLogsHorizontalController.position;
    final target = (_callLogsHorizontalController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _callLogsHorizontalController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  String _resolveLanguageName(dynamic langValue) {
    if (langValue == null) return 'Unknown';

    if (langValue is int) {
      return jobLanguagesMap[langValue] ?? langValue.toString();
    }

    final asString = langValue.toString();
    final parsedInt = int.tryParse(asString);
    if (parsedInt != null) {
      return jobLanguagesMap[parsedInt] ?? asString;
    }

    return asString;
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
            Column(
              children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildStatsCard(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildRecentCallsSection(),
              ],
            )
          else
            Column(
              children: [
                _buildScriptCard(),
                const SizedBox(height: 24),
                _buildStatsCard(),
                const SizedBox(height: 24),
                _buildJobsSection(),
                const SizedBox(height: 24),
                _buildRecentCallsSection(), // <--- Updated Table Section
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
            'Your Status',
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

  // --- NEW: Admin Style Table Implementation ---
  Widget _buildRecentCallsSection() {
    final filteredCalls = _getFilteredCalls();
    final tableMinWidth = MediaQuery.of(context).size.width * 1.35;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header with Admin-style Search Bar
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Detailed logs for your completed and recent calls',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Scroll left',
                        onPressed: () => _scrollCallLogsHorizontally(-320),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: 'Scroll right',
                        onPressed: () => _scrollCallLogsHorizontally(320),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                // Search bar matching admin dashboard style
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    controller: _callLogsSearchCtrl,
                    onChanged: (val) => setState(() {}), // Local search trigger
                    decoration: InputDecoration(
                      hintText: 'Search by custom ID, type, language...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. The Data Table (The "Admin" look)
          if (filteredCalls.isEmpty)
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
                      'No call logs found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Scrollbar(
              controller: _callLogsHorizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _callLogsHorizontalController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: tableMinWidth < 1700 ? 1700 : tableMinWidth,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    dataRowMaxHeight: 70,
                    columnSpacing: 56,
                    horizontalMargin: 24,
                    columns: const [
                      DataColumn(
                        label: Text('CUSTOM ID', style: _adminHeaderStyle),
                      ),
                      DataColumn(
                        label: Text('SESSION TYPE', style: _adminHeaderStyle),
                      ),
                      DataColumn(
                        label: Text('LANGUAGES', style: _adminHeaderStyle),
                      ),
                      DataColumn(
                        label: Text('DURATION', style: _adminHeaderStyle),
                      ),
                      DataColumn(
                        label: Text('CALL START', style: _adminHeaderStyle),
                      ),
                    ],
                    rows:
                        filteredCalls
                            .map((call) => _buildAdminCallRow(call))
                            .toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  DataRow _buildAdminCallRow(Map<String, dynamic> call) {
    final requestId = call['request_id']?.toString() ?? '—';
    final customRequestId = _formatCustomRequestId(requestId);
    final durationSec = (call['duration_seconds'] as num?)?.toInt() ?? 0;
    final callType = call['_session_call_type']?.toString() ?? 'unknown';
    final startedAt = DateTime.tryParse(call['started_at']?.toString() ?? '');

    final metadataRaw = call['metadata'];
    final metadata =
        metadataRaw is Map<String, dynamic>
            ? metadataRaw
            : metadataRaw is Map
            ? Map<String, dynamic>.from(metadataRaw)
            : const <String, dynamic>{};

    final fromLang = _resolveLanguageName(metadata['from_language']);
    final toLang = _resolveLanguageName(metadata['to_language']);

    return DataRow(
      cells: [
        DataCell(
          Text(
            customRequestId,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Row(
            children: [
              Icon(
                callType == 'video' ? Icons.videocam : Icons.phone,
                size: 18,
                color: ColorManager.primary,
              ),
              const SizedBox(width: 12),
              Text(
                callType.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0955FA).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$fromLang → $toLang',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0955FA),
              ),
            ),
          ),
        ),
        DataCell(Text('${durationSec ~/ 60}m ${durationSec % 60}s')),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                startedAt != null
                    ? DateFormat('MMM d, yyyy').format(startedAt)
                    : 'Unknown',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                startedAt != null ? DateFormat('h:mm a').format(startedAt) : '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScriptCard() {
    final firstLanguage = _firstLanguageName ?? 'interpreter';
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
