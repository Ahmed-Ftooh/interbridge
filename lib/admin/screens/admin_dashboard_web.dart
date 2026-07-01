import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:interbridge/admin/screens/admin_details_web.dart';
import 'package:interbridge/admin/services/admin_service.dart';
import 'package:interbridge/config.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  final _adminService = AdminService();
  final _supabaseService = SupabaseService();
  final _appPreferences = instance<AppPreferences>();
  final _searchCtrl = TextEditingController();
  final _callLogsSearchCtrl = TextEditingController();
  final _organizationsSearchCtrl = TextEditingController();

  List<dynamic> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 30;

  String _filterStatus = 'all';
  String _filterAccount = 'all';

  bool _isAdmin = false;
  bool _checking = true;

  // Sidebar
  int _selectedNav =
      0; // 0=interpreters, 1=pending reviews, 2=call logs, 3=organizations
  bool _sidebarCollapsed = false;

  // Call logs data
  List<Map<String, dynamic>> _callLogs = [];
  List<Map<String, dynamic>> _activeCalls = [];
  bool _isLoadingCalls = false;
  Map<int, String> _languagesMap = {};

  // Organizations data
  List<Map<String, dynamic>> _organizations = [];
  Map<String, List<Map<String, dynamic>>> _organizationMembersById = {};
  Map<String, List<Map<String, dynamic>>> _organizationCallsById = {};
  Map<String, Map<String, dynamic>> _organizationStatsById = {};
  bool _isLoadingOrganizations = false;
  String? _selectedOrganizationId;
  bool _showInactiveOrganizations = false;

  // Admin listen mode
  final CallService _callService = CallService();
  RtcEngine? _listenEngine;
  bool _isListening = false;
  String? _listeningToCallId;
  Map<String, dynamic>? _listeningCallInfo;
  Timer? _listenTimer;
  Duration _listenElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _verifyAdminAndLoad();
  }

  Future<void> _verifyAdminAndLoad() async {
    try {
      User? user = _supabaseService.getCurrentUser();
      if (user == null) {
        await Future.delayed(const Duration(seconds: 1));
        user = _supabaseService.getCurrentUser();
      }
      if (user == null) throw Exception('Not authenticated');

      final profile = await _supabaseService.getUserProfile(user.id);
      final isAdmin = profile?.role == 'admin' || profile?.role == 'superadmin';

      final langs = await _supabaseService.getLanguages();
      final langMap = <int, String>{};
      for (final l in langs) {
        langMap[l.id] = l.name;
      }

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _checking = false;
          _languagesMap = langMap;
        });
      }
      if (isAdmin) _load(reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _isAdmin = false;
        });
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _items = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final searchText = _searchCtrl.text.trim();
      // Check if search is a 5-digit number (interpreter ID)
      final isFiveDigitId = RegExp(r'^\d{5}$').hasMatch(searchText);
      List<dynamic> newItems;
      if (isFiveDigitId) {
        // Fetch a large enough batch to find the match (or implement backend support for this)
        final allItems = await _adminService.listInterpreters(
          search: '',
          limit: 500,
          offset: 0,
          filterStatus: _filterStatus,
          filterAccount: _filterAccount,
        );
        newItems =
            allItems.where((item) {
              final userId = item['user_id']?.toString() ?? '';
              if (userId.isEmpty) return false;
              final idNum = uidFromUuid(userId).toString();
              final id5 = idNum.length > 5 ? idNum.substring(0, 5) : idNum;
              return id5 == searchText;
            }).toList();
        // No pagination for ID search
        _hasMore = false;
        _offset = 0;
      } else {
        newItems = await _adminService.listInterpreters(
          search: searchText,
          limit: _limit,
          offset: _offset,
          filterStatus: _filterStatus,
          filterAccount: _filterAccount,
        );
      }

      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          if (!isFiveDigitId) _offset += newItems.length;
          if (newItems.length < _limit || isFiveDigitId) _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCallLogs() async {
    if (_isLoadingCalls) return;
    setState(() => _isLoadingCalls = true);

    try {
      final client = Supabase.instance.client;

      // Fetch recent call logs
      List<dynamic> logs = const [];
      try {
        logs = await client
            .from('call_logs')
            .select('*')
            .order('started_at', ascending: false)
            .limit(100);
      } catch (e) {
        debugPrint('Error loading call_logs: $e');
      }

      // We had stale active calls because some older accepted requests
      // never got marked as completed correctly if someone disconnected unexpectedly.
      // We only consider requests created in the last 2 hours as 'active'.
      final twoHoursAgo =
          DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 2))
              .toIso8601String();

      List<dynamic> active = const [];
      try {
        active = await client
            .from('interpreter_requests')
            .select('*')
            .eq('status', 'accepted')
            .gte('created_at', twoHoursAgo)
            .order('created_at', ascending: false);
      } catch (e) {
        // Active calls are optional for this tab. Do not block call history.
        debugPrint('Error loading active interpreter requests: $e');
      }

      // Resolve user profiles for all unique user IDs
      final allLogs = List<Map<String, dynamic>>.from(logs);
      final allActive = List<Map<String, dynamic>>.from(active);

      final userIds = <String>{};
      final interpreterIds = <String>{};
      final feedbackLookupKeys = <String>{};
      for (final log in allLogs) {
        final requesterId = log['requester_id']?.toString();
        final interpreterId = log['interpreter_id']?.toString();
        final requestId = log['request_id']?.toString();
        final callRequestId = log['call_request_id']?.toString();

        if (requesterId != null && requesterId.isNotEmpty) {
          userIds.add(requesterId);
        }
        if (interpreterId != null && interpreterId.isNotEmpty) {
          userIds.add(interpreterId);
          interpreterIds.add(interpreterId);
        }
        if (requestId != null && requestId.isNotEmpty) {
          feedbackLookupKeys.add(requestId);
        }
        if (callRequestId != null && callRequestId.isNotEmpty) {
          feedbackLookupKeys.add(callRequestId);
        }
      }
      for (final call in allActive) {
        final requesterId = call['requester_id']?.toString();
        final acceptedBy = call['accepted_by']?.toString();

        if (requesterId != null && requesterId.isNotEmpty) {
          userIds.add(requesterId);
        }
        if (acceptedBy != null && acceptedBy.isNotEmpty) {
          userIds.add(acceptedBy);
          interpreterIds.add(acceptedBy);
        }
      }

      Map<String, Map<String, dynamic>> profileMap = {};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await client
              .from('users_profile')
              .select('user_id, username, role')
              .inFilter('user_id', userIds.toList());
          for (final p in profiles) {
            profileMap[p['user_id'] as String] = Map<String, dynamic>.from(p);
          }
        } catch (e) {
          debugPrint('Error loading users_profile for call logs: $e');
        }
      }

      final interpreterEmailMap = await _fetchInterpreterEmails(interpreterIds);
      final feedbackMap = await _fetchCallFeedbackByChannel(feedbackLookupKeys);

      // Attach profiles to logs
      for (final log in allLogs) {
        final requesterId = log['requester_id']?.toString();
        final interpreterId = log['interpreter_id']?.toString();
        final requestId = log['request_id']?.toString();
        final callRequestId = log['call_request_id']?.toString();

        log['_requester'] =
            requesterId == null ? null : profileMap[requesterId];
        log['_interpreter'] =
            interpreterId == null ? null : profileMap[interpreterId];
        log['_interpreter_email'] =
            interpreterId == null ? null : interpreterEmailMap[interpreterId];

        final feedbackRows = _feedbackRowsForLog(
          feedbackMap,
          requestId: requestId,
          callRequestId: callRequestId,
        );
        log['_feedback'] = _pickFeedbackForCall(
          feedbackRows: feedbackRows,
          requesterId: requesterId,
        );
      }
      for (final call in allActive) {
        final requesterId = call['requester_id']?.toString();
        final acceptedBy = call['accepted_by']?.toString();

        call['_requester'] =
            requesterId == null ? null : profileMap[requesterId];
        call['_interpreter'] =
            acceptedBy == null ? null : profileMap[acceptedBy];
        call['_interpreter_email'] =
            acceptedBy == null ? null : interpreterEmailMap[acceptedBy];
      }

      if (mounted) {
        setState(() {
          _callLogs = allLogs;
          _activeCalls = allActive;
          _isLoadingCalls = false;
        });
      }
    } catch (e) {
      debugPrint('Fatal error loading call logs tab: $e');
      if (mounted) {
        setState(() => _isLoadingCalls = false);
      }
    }
  }

  Future<void> _loadOrganizations() async {
    if (_isLoadingOrganizations) return;
    setState(() => _isLoadingOrganizations = true);

    try {
      final client = Supabase.instance.client;

      List<Map<String, dynamic>> organizations = [];
      try {
        final rows = await client
            .from('organizations')
            .select(
              'id, name, email, phone, address, wallet_balance, rate_per_minute, billing_email, billing_contact_name, billing_method, invite_code, is_active, verification_status, created_at, updated_at',
            )
            .order('created_at', ascending: false)
            .limit(500);
        organizations =
            (rows as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList();
      } catch (e) {
        debugPrint('Error loading organizations with selected fields: $e');
        final fallbackRows = await client
            .from('organizations')
            .select('*')
            .order('created_at', ascending: false)
            .limit(500);
        organizations =
            (fallbackRows as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList();
      }

      final organizationIds =
          organizations
              .map((org) => org['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();

      List<Map<String, dynamic>> members = [];
      List<Map<String, dynamic>> calls = [];

      if (organizationIds.isNotEmpty) {
        try {
          final memberRows = await client
              .from('organization_members')
              .select(
                'id, organization_id, user_id, role, is_active, spending_limit, total_spent, joined_at',
              )
              .inFilter('organization_id', organizationIds);
          members =
              (memberRows as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList();
        } catch (e) {
          debugPrint('Error loading organization members for admin tab: $e');
        }

        try {
          final callRows = await client
              .from('call_logs')
              .select(
                'id, organization_id, requester_id, interpreter_id, request_id, duration_seconds, cost, started_at, ended_at',
              )
              .inFilter('organization_id', organizationIds)
              .order('started_at', ascending: false)
              .limit(4000);
          calls =
              (callRows as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList();
        } catch (e) {
          debugPrint('Error loading organization calls for admin tab: $e');
        }
      }

      final userIds = <String>{};
      for (final member in members) {
        final userId = member['user_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          userIds.add(userId);
        }
      }
      for (final call in calls) {
        final requesterId = call['requester_id']?.toString();
        final interpreterId = call['interpreter_id']?.toString();
        if (requesterId != null && requesterId.isNotEmpty) {
          userIds.add(requesterId);
        }
        if (interpreterId != null && interpreterId.isNotEmpty) {
          userIds.add(interpreterId);
        }
      }

      final profileMap = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await client
              .from('users_profile')
              .select('user_id, username, full_name, role')
              .inFilter('user_id', userIds.toList());
          for (final row in profiles) {
            final item = Map<String, dynamic>.from(row as Map);
            final userId = item['user_id']?.toString();
            if (userId == null || userId.isEmpty) continue;
            profileMap[userId] = item;
          }
        } catch (e) {
          debugPrint('Error loading profiles for organizations tab: $e');
        }
      }

      for (final member in members) {
        final userId = member['user_id']?.toString();
        member['_profile'] = userId == null ? null : profileMap[userId];
      }
      for (final call in calls) {
        final requesterId = call['requester_id']?.toString();
        final interpreterId = call['interpreter_id']?.toString();
        call['_requester'] = requesterId == null ? null : profileMap[requesterId];
        call['_interpreter'] =
            interpreterId == null ? null : profileMap[interpreterId];
      }

      final membersByOrg = <String, List<Map<String, dynamic>>>{};
      for (final member in members) {
        final orgId = member['organization_id']?.toString();
        if (orgId == null || orgId.isEmpty) continue;
        membersByOrg.putIfAbsent(orgId, () => []).add(member);
      }

      final callsByOrg = <String, List<Map<String, dynamic>>>{};
      for (final call in calls) {
        final orgId = call['organization_id']?.toString();
        if (orgId == null || orgId.isEmpty) continue;
        callsByOrg.putIfAbsent(orgId, () => []).add(call);
      }

      final nowUtc = DateTime.now().toUtc();
      final weekStartUtc =
          DateTime.utc(
            nowUtc.year,
            nowUtc.month,
            nowUtc.day,
          ).subtract(Duration(days: nowUtc.weekday - 1));
      final monthStartUtc = DateTime.utc(nowUtc.year, nowUtc.month, 1);

      final statsByOrg = <String, Map<String, dynamic>>{};
      for (final org in organizations) {
        final orgId = org['id']?.toString();
        if (orgId == null || orgId.isEmpty) continue;

        final orgMembers =
            membersByOrg[orgId] ?? const <Map<String, dynamic>>[];
        final orgCalls = callsByOrg[orgId] ?? const <Map<String, dynamic>>[];

        final doctorMembers =
            orgMembers
                .where((member) => (member['role']?.toString() ?? '') == 'doctor')
                .toList();

        final activeDoctors =
            doctorMembers.where((member) => member['is_active'] != false).length;

        final doctorUsage = <String, Map<String, dynamic>>{};
        for (final doctor in doctorMembers) {
          final userId = doctor['user_id']?.toString();
          if (userId == null || userId.isEmpty) continue;
          doctorUsage[userId] = {
            'calls': 0,
            'duration_seconds': 0,
            'cost': 0.0,
          };
        }

        var totalDurationSeconds = 0;
        var totalCost = 0.0;
        var callsThisWeek = 0;
        var callsThisMonth = 0;
        var costThisMonth = 0.0;
        DateTime? lastCallAt;

        for (final call in orgCalls) {
          final durationSeconds = _asInt(call['duration_seconds']);
          final callCost = _asDouble(call['cost']);
          totalDurationSeconds += durationSeconds;
          totalCost += callCost;

          final startedAt = _parseDateTime(call['started_at']);
          if (startedAt != null) {
            final startedAtUtc = startedAt.toUtc();
            if (startedAtUtc.isAfter(weekStartUtc)) {
              callsThisWeek++;
            }
            if (startedAtUtc.isAfter(monthStartUtc)) {
              callsThisMonth++;
              costThisMonth += callCost;
            }
            if (lastCallAt == null || startedAtUtc.isAfter(lastCallAt)) {
              lastCallAt = startedAtUtc;
            }
          }

          final requesterId = call['requester_id']?.toString();
          if (requesterId != null && requesterId.isNotEmpty) {
            final usage = doctorUsage.putIfAbsent(requesterId, () {
              return {
                'calls': 0,
                'duration_seconds': 0,
                'cost': 0.0,
              };
            });
            usage['calls'] = _asInt(usage['calls']) + 1;
            usage['duration_seconds'] =
                _asInt(usage['duration_seconds']) + durationSeconds;
            usage['cost'] = _asDouble(usage['cost']) + callCost;
          }
        }

        final totalDoctorSpent = doctorMembers.fold<double>(
          0.0,
          (sum, member) => sum + _asDouble(member['total_spent']),
        );

        String? topDoctorName;
        double topDoctorSpent = 0.0;
        for (final doctor in doctorMembers) {
          final spent = _asDouble(doctor['total_spent']);
          if (spent >= topDoctorSpent) {
            topDoctorSpent = spent;
            final profileRaw = doctor['_profile'];
            final profile =
                profileRaw is Map<String, dynamic>
                    ? profileRaw
                    : profileRaw is Map
                    ? Map<String, dynamic>.from(profileRaw)
                    : null;
            topDoctorName =
                profile?['full_name']?.toString() ??
                profile?['username']?.toString();
          }
        }

        statsByOrg[orgId] = {
          'members_count': orgMembers.length,
          'doctors_count': doctorMembers.length,
          'active_doctors_count': activeDoctors,
          'calls_count': orgCalls.length,
          'total_duration_seconds': totalDurationSeconds,
          'total_minutes': (totalDurationSeconds / 60).ceil(),
          'total_cost': totalCost,
          'calls_this_week': callsThisWeek,
          'calls_this_month': callsThisMonth,
          'cost_this_month': costThisMonth,
          'total_doctor_spent': totalDoctorSpent,
          'last_call_at': lastCallAt?.toIso8601String(),
          'doctor_usage': doctorUsage,
          'top_doctor_name': topDoctorName,
          'top_doctor_spent': topDoctorSpent,
        };
      }

      if (mounted) {
        final visibleOrganizations =
            _showInactiveOrganizations
                ? organizations
                : organizations
                    .where((org) => org['is_active'] != false)
                    .toList();
        setState(() {
          _organizations = organizations;
          _organizationMembersById = membersByOrg;
          _organizationCallsById = callsByOrg;
          _organizationStatsById = statsByOrg;
          _selectedOrganizationId = _resolveNextSelectedOrganizationId(
            previousSelection: _selectedOrganizationId,
            organizations: visibleOrganizations,
          );
          _isLoadingOrganizations = false;
        });
      }
    } catch (e) {
      debugPrint('Fatal error loading organizations tab: $e');
      if (mounted) {
        setState(() => _isLoadingOrganizations = false);
      }
    }
  }

  String? _resolveNextSelectedOrganizationId({
    required String? previousSelection,
    required List<Map<String, dynamic>> organizations,
  }) {
    if (organizations.isEmpty) return null;

    if (previousSelection != null && previousSelection.isNotEmpty) {
      final exists = organizations.any(
        (org) => org['id']?.toString() == previousSelection,
      );
      if (exists) return previousSelection;
    }

    return organizations.first['id']?.toString();
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _filteredOrganizations() {
    final query = _organizationsSearchCtrl.text.trim().toLowerCase();
    final baseOrganizations =
        _showInactiveOrganizations
            ? _organizations
            : _organizations
                .where((org) => org['is_active'] != false)
                .toList();

    if (query.isEmpty) return baseOrganizations;

    return baseOrganizations.where((org) {
      final orgId = org['id']?.toString() ?? '';
      final name = org['name']?.toString() ?? '';
      final email = org['email']?.toString() ?? '';
      final billingEmail = org['billing_email']?.toString() ?? '';
      final contactName = org['billing_contact_name']?.toString() ?? '';
      final inviteCode = org['invite_code']?.toString() ?? '';

      final searchable =
          '$orgId $name $email $billingEmail $contactName $inviteCode'
              .toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  String _formatCurrency(dynamic value) {
    return '\$${_asDouble(value).toStringAsFixed(2)}';
  }

  String _formatShortDate(dynamic value) {
    final date = _parseDateTime(value);
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy').format(date.toLocal());
  }

  String _formatShortDateTime(dynamic value) {
    final date = _parseDateTime(value);
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy - h:mm a').format(date.toLocal());
  }

  Future<Map<String, String>> _fetchInterpreterEmails(
    Set<String> interpreterIds,
  ) async {
    final emails = <String, String>{};
    if (interpreterIds.isEmpty) return emails;

    try {
      final remaining = Set<String>.from(interpreterIds);
      var offset = 0;
      const pageSize = 100;

      while (remaining.isNotEmpty) {
        List<dynamic> batch;
        try {
          batch = await _adminService.listInterpreters(
            search: '',
            limit: pageSize,
            offset: offset,
            filterStatus: 'all',
            filterAccount: 'all',
            includeEmail: true,
          );
        } catch (e) {
          debugPrint('Error loading interpreter emails for call logs: $e');
          break;
        }

        if (batch.isEmpty) break;

        for (final raw in batch) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final userId = item['user_id']?.toString();
          if (userId == null || userId.isEmpty || !remaining.contains(userId)) {
            continue;
          }

          final email = item['email']?.toString();
          if (email != null && email.isNotEmpty) {
            emails[userId] = email;
          }
          remaining.remove(userId);
        }

        if (batch.length < pageSize) break;
        offset += batch.length;
      }
    } catch (e) {
      debugPrint('Interpreter email enrichment failed: $e');
    }

    return emails;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchCallFeedbackByChannel(
    Set<String> channelIds,
  ) async {
    final feedbackByChannel = <String, List<Map<String, dynamic>>>{};
    if (channelIds.isEmpty) return feedbackByChannel;

    try {
      final rows = await Supabase.instance.client
          .from('call_feedback')
          .select('channel_id, user_id, rating, comments, created_at')
          .inFilter('channel_id', channelIds.toList());

      for (final row in rows) {
        final item = Map<String, dynamic>.from(row);
        final channelId = item['channel_id']?.toString();
        if (channelId == null || channelId.isEmpty) continue;

        feedbackByChannel.putIfAbsent(channelId, () => []).add(item);
      }

      for (final rows in feedbackByChannel.values) {
        rows.sort((a, b) {
          final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
      }
    } catch (e) {
      debugPrint('Error loading call feedback for admin logs: $e');
    }

    return feedbackByChannel;
  }

  List<Map<String, dynamic>> _feedbackRowsForLog(
    Map<String, List<Map<String, dynamic>>> feedbackMap, {
    String? requestId,
    String? callRequestId,
  }) {
    final merged = <Map<String, dynamic>>[];

    if (requestId != null && requestId.isNotEmpty) {
      merged.addAll(feedbackMap[requestId] ?? const []);
    }
    if (callRequestId != null &&
        callRequestId.isNotEmpty &&
        callRequestId != requestId) {
      merged.addAll(feedbackMap[callRequestId] ?? const []);
    }

    if (merged.length <= 1) return merged;

    merged.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return merged;
  }

  Map<String, dynamic>? _pickFeedbackForCall({
    List<Map<String, dynamic>>? feedbackRows,
    String? requesterId,
  }) {
    if (feedbackRows == null || feedbackRows.isEmpty) return null;

    if (requesterId != null && requesterId.isNotEmpty) {
      for (final row in feedbackRows) {
        final userId = row['user_id']?.toString();
        if (userId == requesterId) return row;
      }
    }

    return feedbackRows.first;
  }

  String _shortInterpreterId(String? userId) {
    if (userId == null || userId.isEmpty) return '';
    final idNum = uidFromUuid(userId).toString();
    return idNum.length > 5 ? idNum.substring(0, 5) : idNum;
  }

  List<Map<String, dynamic>> _filteredCallLogs() {
    final query = _callLogsSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _callLogs;

    return _callLogs.where((call) {
      final interpreterRaw = call['_interpreter'];
      final interpreter =
          interpreterRaw is Map<String, dynamic>
              ? interpreterRaw
              : interpreterRaw is Map
              ? Map<String, dynamic>.from(interpreterRaw)
              : null;

      final interpreterId = call['interpreter_id']?.toString() ?? '';
      final interpreterId5 = _shortInterpreterId(interpreterId);
      final username = interpreter?['username']?.toString() ?? '';
      final email = call['_interpreter_email']?.toString() ?? '';

      final searchable =
          '$interpreterId $interpreterId5 $username $email'.toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _stopListening();
    _searchCtrl.dispose();
    _callLogsSearchCtrl.dispose();
    _organizationsSearchCtrl.dispose();
    super.dispose();
  }

  // ──────── ADMIN LISTEN TO ACTIVE CALL ────────

  Future<void> _startListening(Map<String, dynamic> call) async {
    if (_isListening) {
      // Already listening — stop current and start new
      await _stopListening();
    }

    final channelId = call['id'] as String;
    final adminUser = _supabaseService.getCurrentUser();
    if (adminUser == null) return;

    final adminUid = uidFromUuid(adminUser.id);

    setState(() {
      _isListening = true;
      _listeningToCallId = channelId;
      _listeningCallInfo = call;
      _listenElapsed = Duration.zero;
    });

    try {
      // 1) Create & init Agora engine
      _listenEngine = createAgoraRtcEngine();
      await _listenEngine!.initialize(RtcEngineContext(appId: agoraAppId));

      // 2) Register event handlers
      _listenEngine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            log('Admin joined channel $channelId as listener');
            if (mounted) {
              setState(() {});
              // Start elapsed timer
              _listenTimer?.cancel();
              _listenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                if (mounted) {
                  setState(() {
                    _listenElapsed += const Duration(seconds: 1);
                  });
                }
              });
            }
          },
          onError: (errorCode, errorMsg) {
            log('Admin listen error: $errorCode - $errorMsg');
          },
          onUserOffline: (connection, remoteUid, reason) {
            log('Remote user left during admin listen: $remoteUid');
          },
        ),
      );

      // 3) Audio config — audience mode, listen-only
      await _listenEngine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
      );
      await _listenEngine!.enableAudio();
      await _listenEngine!.setClientRole(
        role: ClientRoleType.clientRoleAudience,
      );

      // 4) Fetch SUBSCRIBER token (audience-only, no publish rights)
      final token = await _callService.fetchAgoraToken(
        channelName: channelId,
        uid: adminUid,
        role: 'subscriber',
      );

      // 5) Join channel as audience
      await _listenEngine!.joinChannel(
        token: token,
        channelId: channelId,
        uid: adminUid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
        ),
      );

      // 6) Record admin_listener_id in call_logs
      try {
        await Supabase.instance.client
            .from('call_logs')
            .update({'admin_listener_id': adminUser.id})
            .eq('request_id', channelId);
      } catch (e) {
        log('Could not update admin_listener_id: $e');
      }

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Now listening to the call...'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      log('Error starting admin listen: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _listeningToCallId = null;
          _listeningCallInfo = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to listen: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Clean up engine on error
      try {
        await _listenEngine?.release();
      } catch (_) {}
      _listenEngine = null;
    }
  }

  Future<void> _stopListening() async {
    _listenTimer?.cancel();
    _listenTimer = null;

    if (_listenEngine != null) {
      try {
        await _listenEngine!.leaveChannel();
        await _listenEngine!.release();
      } catch (e) {
        log('Error stopping admin listen: $e');
      }
      _listenEngine = null;
    }

    if (mounted) {
      setState(() {
        _isListening = false;
        _listeningToCallId = null;
        _listeningCallInfo = null;
        _listenElapsed = Duration.zero;
      });
    }
  }

  Widget _buildListenPanel() {
    final call = _listeningCallInfo;
    if (call == null) return const SizedBox.shrink();

    final requester = call['_requester'] as Map<String, dynamic>?;
    final interpreter = call['_interpreter'] as Map<String, dynamic>?;
    final fromLang = _getLanguageName(call['from_language']);
    final toLang = _getLanguageName(call['to_language']);
    final minutes = _listenElapsed.inMinutes;
    final seconds = _listenElapsed.inSeconds % 60;

    return Positioned(
      bottom: 24,
      right: 24,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF22C55E).withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Listening to Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Language pair
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$fromLang → $toLang',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Participants
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF3B82F6), size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      requester?['username'] ?? 'Doctor',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    ' ↔ ',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const Icon(
                    Icons.translate,
                    color: Color(0xFF6366F1),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      interpreter?['username'] ?? 'Interpreter',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Audio waveform indicator + stop button
              Row(
                children: [
                  // Animated audio indicator
                  ...List.generate(5, (i) {
                    final heights = [8.0, 14.0, 10.0, 16.0, 6.0];
                    return Container(
                      width: 3,
                      height: heights[i],
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  const Text(
                    'Audio Only',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  const Spacer(),
                  // Stop button
                  ElevatedButton.icon(
                    onPressed: _stopListening,
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You must be an admin to access this page.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 900) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black87),
          elevation: 1,
          title: const Text(
            'Admin Portal',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        drawer: Drawer(child: _buildSidebar()),
        body: Stack(
          children: [
            Column(
              children: [_buildTopBar(), Expanded(child: _buildMainContent())],
            ),
            if (_isListening) _buildListenPanel(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildMainContent()),
                  ],
                ),
              ),
            ],
          ),
          // Floating listen panel
          if (_isListening) _buildListenPanel(),
        ],
      ),
    );
  }

  // ──────── SIDEBAR ────────
  Widget _buildSidebar() {
    final collapsed = _sidebarCollapsed;
    final width = collapsed ? 72.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: ColorManager.primary2,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo / Title
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 20),
            alignment: collapsed ? Alignment.center : Alignment.centerLeft,
            child:
                collapsed
                    ? const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 28,
                    )
                    : const Text(
                      'Admin Portal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          // Links
          _buildNavItem(0, Icons.people_alt_outlined, 'All Interpreters'),
          _buildNavItem(1, Icons.pending_actions_outlined, 'Pending Reviews'),
          _buildNavItem(2, Icons.history_outlined, 'Call Logs'),
          _buildNavItem(3, Icons.business_outlined, 'Organizations'),
          const Spacer(),
          // Broadcast Button here
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showBroadcastDialog(context),
                icon: const Icon(Icons.campaign, size: 18),
                label: const Text('Broadcast', overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Indigo
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Broadcast',
              icon: const Icon(Icons.campaign, color: Colors.white),
              onPressed: () => _showBroadcastDialog(context),
            ),
          // Logout / Collapse
          const Divider(color: Colors.white24, height: 1),
          // Collapse toggle
          InkWell(
            onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                collapsed ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final selected = _selectedNav == index;
    final collapsed = _sidebarCollapsed;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _selectedNav = index);
            if (index == 2) {
              _loadCallLogs();
            } else if (index == 3) {
              _loadOrganizations();
            } else if (index == 1) {
              // Filter to unverified
              setState(() {
                _filterStatus = 'unverified';
                _filterAccount = 'all';
              });
              _load(reset: true);
            } else {
              setState(() {
                _filterStatus = 'all';
                _filterAccount = 'all';
              });
              _load(reset: true);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
            decoration: BoxDecoration(
              color:
                  selected
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border:
                  selected
                      ? Border.all(color: ColorManager.primary.withOpacity(0.3))
                      : null,
            ),
            alignment: collapsed ? Alignment.center : Alignment.centerLeft,
            child:
                collapsed
                    ? Icon(
                      icon,
                      color: selected ? ColorManager.primary : Colors.white70,
                      size: 22,
                    )
                    : Row(
                      children: [
                        Icon(
                          icon,
                          color:
                              selected ? ColorManager.primary : Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight:
                                  selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  // ──────── TOP BAR ────────
  Widget _buildTopBar() {
    final isCallLogsTab = _selectedNav == 2;
    final isOrganizationsTab = _selectedNav == 3;
    final activeSearchCtrl =
      isCallLogsTab
        ? _callLogsSearchCtrl
        : isOrganizationsTab
        ? _organizationsSearchCtrl
        : _searchCtrl;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: TextField(
                controller: activeSearchCtrl,
                decoration: InputDecoration(
                  hintText:
                      isCallLogsTab
                          ? 'Search call logs by interpreter ID, username, or email...'
                        : isOrganizationsTab
                        ? 'Search organizations by name, email, invite code, or ID...'
                          : 'Search interpreters by name or 5-digit ID...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) {
                  if (isCallLogsTab || isOrganizationsTab) {
                    setState(() {});
                  }
                },
                onSubmitted: (_) {
                  if (isCallLogsTab || isOrganizationsTab) {
                    setState(() {});
                  } else {
                    _load(reset: true);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (!isCallLogsTab && !isOrganizationsTab)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: _filterStatusLabel(),
                    icon: Icons.verified_user,
                    items: [
                      {'label': 'All Status', 'value': 'all'},
                      {'label': 'Verified', 'value': 'verified'},
                      {'label': 'Unverified', 'value': 'unverified'},
                    ],
                    value: _filterStatus,
                    onChanged: (val) {
                      setState(() => _filterStatus = val);
                      _load(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: _filterAccountLabel(),
                    icon: Icons.manage_accounts,
                    items: [
                      {'label': 'All Accounts', 'value': 'all'},
                      {'label': 'Active', 'value': 'active'},
                      {'label': 'Suspended', 'value': 'suspended'},
                    ],
                    value: _filterAccount,
                    onChanged: (val) {
                      setState(() => _filterAccount = val);
                      _load(reset: true);
                    },
                  ),
                ],
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed:
                isCallLogsTab
                    ? _loadCallLogs
                    : isOrganizationsTab
                    ? _loadOrganizations
                    : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(width: 8),
          _buildUserMenu(),
        ],
      ),
    );
  }

  String _filterStatusLabel() {
    switch (_filterStatus) {
      case 'verified':
        return 'Verified';
      case 'unverified':
        return 'Unverified';
      default:
        return 'All Status';
    }
  }

  String _filterAccountLabel() {
    switch (_filterAccount) {
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      default:
        return 'All Accounts';
    }
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required List<Map<String, String>> items,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder:
          (_) =>
              items
                  .map(
                    (item) => PopupMenuItem(
                      value: item['value'],
                      child: Row(
                        children: [
                          if (item['value'] == value)
                            Icon(
                              Icons.check,
                              size: 16,
                              color: ColorManager.primary,
                            )
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(item['label']!),
                        ],
                      ),
                    ),
                  )
                  .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              value != 'all'
                  ? ColorManager.primary.withOpacity(0.1)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                value != 'all'
                    ? ColorManager.primary.withOpacity(0.3)
                    : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  value != 'all' ? ColorManager.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color:
                    value != 'all'
                        ? ColorManager.primary
                        : Colors.grey.shade700,
                fontWeight:
                    value != 'all' ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color:
                  value != 'all' ? ColorManager.primary : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMenu() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (val) async {
        if (val == 'logout') {
          await _supabaseService.signOut();
          await _appPreferences.logout();
          if (context.mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
          }
        }
      },
      itemBuilder:
          (_) => [
            const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: ColorManager.primary2,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('Admin', style: TextStyle(fontWeight: FontWeight.w500)),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  // ──────── MAIN CONTENT ────────
  Widget _buildMainContent() {
    if (_selectedNav == 2) return _buildCallLogsContent();
    if (_selectedNav == 3) return _buildOrganizationsContent();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryRow(),
          const SizedBox(height: 24),

          // Data table header
          Row(
            children: [
              Text(
                _selectedNav == 1 ? 'Pending Reviews' : 'All Interpreters',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ColorManager.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_items.length}${_hasMore ? '+' : ''}',
                  style: TextStyle(
                    color: ColorManager.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),

          // Data table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth =
                      constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
                  final tableHeight =
                      constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : 520.0;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: tableHeight,
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(width: 48), // Avatar space
                                SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Interpreter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'User ID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 44),
                              ],
                            ),
                          ),

                          // Table rows
                          Expanded(
                            child:
                                _items.isEmpty && !_isLoading
                                    ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 48,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No interpreters found',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount:
                                          _items.length + (_hasMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == _items.length) {
                                          return _buildLoadMore();
                                        }
                                        return _buildTableRow(
                                          _items[index] as Map,
                                          index,
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = _items.length;
    final verified = _items.where((i) => i['is_verified'] == true).length;
    final unverified = total - verified;
    final suspended = _items.where((i) => i['is_suspended'] == true).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Loaded',
            '$total${_hasMore ? '+' : ''}',
            Icons.people,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Verified',
            '$verified',
            Icons.verified_user,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Unverified',
            '$unverified',
            Icons.pending,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Suspended',
            '$suspended',
            Icons.block,
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map item, int index) {
    final userId = item['user_id']?.toString() ?? '';
    final username = item['username']?.toString() ?? 'Unknown';
    final isVerified = item['is_verified'] == true;
    final isSuspended = item['is_suspended'] == true;
    // Generate 5-digit interpreter ID (same as interpreter home web)
    String interpreterId5 = '';
    if (userId.isNotEmpty) {
      final idNum = uidFromUuid(userId).toString();
      interpreterId5 = idNum.length > 5 ? idNum.substring(0, 5) : idNum;
    }

    return InkWell(
      onTap: () => _openDetails(userId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : const Color(0xFFFAFBFC),
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  isVerified
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : Colors.grey.shade100,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  color:
                      isVerified
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Show 5-digit ID next to username
            if (interpreterId5.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  interpreterId5,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                userId.length > 8 ? '${userId.substring(0, 8)}...' : userId,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _buildStatusBadge(
                isVerified ? 'Verified' : 'Unverified',
                isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
            Expanded(
              flex: 2,
              child: _buildStatusBadge(
                isSuspended ? 'Suspended' : 'Active',
                isSuspended ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              ),
            ),
            SizedBox(
              width: 44,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                color: Colors.grey.shade400,
                onPressed: () => _openDetails(userId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : TextButton.icon(
                  onPressed: () => _load(),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load More'),
                ),
      ),
    );
  }

  void _openDetails(String userId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AdminDetailsWeb(userId: userId)));
  }

  // ──────── CALL LOGS CONTENT ────────
  Widget _buildCallLogsContent() {
    final filteredLogs = _filteredCallLogs();
    final hasSearchQuery = _callLogsSearchCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards for calls
          _buildCallSummaryRow(),
          const SizedBox(height: 24),

          // Active calls section
          if (_activeCalls.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Calls (${_activeCalls.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadCallLogs,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _activeCalls.length,
                itemBuilder: (context, index) {
                  return _buildActiveCallCard(_activeCalls[index]);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Call logs header
          Row(
            children: [
              const Text(
                'Call History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ColorManager.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasSearchQuery
                      ? '${filteredLogs.length}/${_callLogs.length}'
                      : '${_callLogs.length}',
                  style: TextStyle(
                    color: ColorManager.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadCallLogs,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Call logs table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth =
                      constraints.maxWidth > 1500
                          ? constraints.maxWidth
                          : 1500.0;
                  final tableHeight =
                      constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : 520.0;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: tableHeight,
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Requester',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Interpreter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Languages',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Duration',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Cost',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Rating',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Feedback',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Date / Time',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Rows
                          Expanded(
                            child:
                                _isLoadingCalls
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : filteredLogs.isEmpty
                                    ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.phone_missed,
                                            size: 48,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _callLogs.isEmpty
                                                ? 'No call logs yet'
                                                : 'No call logs matched your search',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: filteredLogs.length,
                                      itemBuilder: (context, index) {
                                        return _buildCallLogRow(
                                          filteredLogs[index],
                                          index,
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallSummaryRow() {
    final totalCalls = _callLogs.length;
    final totalDuration = _callLogs.fold<int>(
      0,
      (sum, c) => sum + ((c['duration_seconds'] as int?) ?? 0),
    );
    final totalHours = (totalDuration / 3600).toStringAsFixed(1);
    final activeCalls = _activeCalls.length;
    final totalCost = _callLogs.fold<double>(
      0.0,
      (sum, c) => sum + ((c['cost'] as num?)?.toDouble() ?? 0.0),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Calls',
            '$totalCalls',
            Icons.phone,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Total Hours',
            totalHours,
            Icons.access_time,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Active Now',
            '$activeCalls',
            Icons.phone_in_talk,
            const Color(0xFF22C55E),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Total Cost',
            '\$${totalCost.toStringAsFixed(2)}',
            Icons.attach_money,
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallCard(Map<String, dynamic> call) {
    final requester = call['_requester'] as Map<String, dynamic>?;
    final interpreter = call['_interpreter'] as Map<String, dynamic>?;
    final fromLang = _getLanguageName(call['from_language']);
    final toLang = _getLanguageName(call['to_language']);
    final callType = call['call_type'] ?? 'voice';
    final startedAt = DateTime.tryParse(call['created_at'] ?? '');
    final elapsed =
        startedAt != null ? DateTime.now().difference(startedAt).inMinutes : 0;

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  callType == 'video' ? Icons.videocam : Icons.phone,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$fromLang → $toLang',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${elapsed}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${requester?['username'] ?? 'Doctor'} ↔ ${interpreter?['username'] ?? 'Interpreter'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _startListening(call),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _listeningToCallId == call['id']
                            ? const Color(0xFFEF4444)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _listeningToCallId == call['id']
                            ? Icons.hearing
                            : Icons.headset,
                        size: 14,
                        color:
                            _listeningToCallId == call['id']
                                ? Colors.white
                                : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _listeningToCallId == call['id']
                            ? 'Listening...'
                            : 'Listen',
                        style: TextStyle(
                          color:
                              _listeningToCallId == call['id']
                                  ? Colors.white
                                  : const Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLanguageName(dynamic langId) {
    if (langId == null) return 'Unknown';
    if (langId is int) return _languagesMap[langId] ?? langId.toString();
    if (langId is String) {
      final parsed = int.tryParse(langId);
      if (parsed != null) return _languagesMap[parsed] ?? langId;
      return langId; // Fallback if already a string name
    }
    return langId.toString();
  }

  Widget _buildCallLogRow(Map<String, dynamic> call, int index) {
    final requesterRaw = call['_requester'];
    final requester =
        requesterRaw is Map<String, dynamic>
            ? requesterRaw
            : requesterRaw is Map
            ? Map<String, dynamic>.from(requesterRaw)
            : null;

    final interpreterRaw = call['_interpreter'];
    final interpreter =
        interpreterRaw is Map<String, dynamic>
            ? interpreterRaw
            : interpreterRaw is Map
            ? Map<String, dynamic>.from(interpreterRaw)
            : null;

    final metadataRaw = call['metadata'];
    final metadata =
        metadataRaw is Map<String, dynamic>
            ? metadataRaw
            : metadataRaw is Map
            ? Map<String, dynamic>.from(metadataRaw)
            : null;

    final feedbackRaw = call['_feedback'];
    final feedback =
        feedbackRaw is Map<String, dynamic>
            ? feedbackRaw
            : feedbackRaw is Map
            ? Map<String, dynamic>.from(feedbackRaw)
            : null;

    final fromLang = _getLanguageName(metadata?['from_language']);
    final toLang = _getLanguageName(metadata?['to_language']);
    final durationSec = (call['duration_seconds'] as num?)?.toInt() ?? 0;
    final cost = (call['cost'] as num?)?.toDouble() ?? 0.0;
    final startedAt = DateTime.tryParse(call['started_at']?.toString() ?? '');
    final endedAt = DateTime.tryParse(call['ended_at']?.toString() ?? '');
    final rating = (feedback?['rating'] as num?)?.toInt();
    final feedbackText = feedback?['comments']?.toString().trim() ?? '';
    final interpreterId = call['interpreter_id']?.toString() ?? '';
    final interpreterId5 = _shortInterpreterId(interpreterId);
    final interpreterEmail = call['_interpreter_email']?.toString() ?? '';

    final interpreterMetaParts = <String>[];
    if (interpreterId5.isNotEmpty) {
      interpreterMetaParts.add('ID $interpreterId5');
    }
    if (interpreterEmail.isNotEmpty) {
      interpreterMetaParts.add(interpreterEmail);
    }

    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFBFC),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Requester
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                  child: Text(
                    (requester?['username'] ?? 'D')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requester?['full_name'] ??
                            requester?['username'] ??
                            'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        requester?['role'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Interpreter
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  child: Text(
                    (interpreter?['username'] ?? 'I')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        interpreter?['full_name'] ??
                            interpreter?['username'] ??
                            'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (interpreterMetaParts.isNotEmpty)
                        Text(
                          interpreterMetaParts.join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Languages
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0955FA).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$fromLang → $toLang',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0955FA),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Duration
          Expanded(
            child: Text(
              '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          // Cost
          Expanded(
            child: Text(
              cost > 0 ? '\$${cost.toStringAsFixed(2)}' : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cost > 0 ? const Color(0xFFEF4444) : Colors.grey,
              ),
            ),
          ),
          // Rating
          Expanded(
            child:
                rating == null
                    ? Text(
                      '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    )
                    : Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rating/5',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
          ),
          // Feedback text
          Expanded(
            flex: 3,
            child: Text(
              feedbackText.isEmpty ? '—' : feedbackText,
              style: TextStyle(
                fontSize: 12,
                color:
                    feedbackText.isEmpty
                        ? Colors.grey.shade500
                        : Colors.black87,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (startedAt != null)
                  Text(
                    DateFormat('MMM d, yyyy').format(startedAt),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (startedAt != null)
                  Text(
                    '${DateFormat('h:mm a').format(startedAt)}${endedAt != null ? ' – ${DateFormat('h:mm a').format(endedAt)}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────── ORGANIZATIONS CONTENT ────────
  Widget _buildOrganizationsContent() {
    final filteredOrganizations = _filteredOrganizations();
    final hasSearchQuery = _organizationsSearchCtrl.text.trim().isNotEmpty;
    final showFilteredCount = hasSearchQuery || !_showInactiveOrganizations;

    final selectedOrgId =
        filteredOrganizations.any(
          (org) => org['id']?.toString() == _selectedOrganizationId,
        )
            ? _selectedOrganizationId
            : null;

    Map<String, dynamic>? selectedOrganization;
    if (selectedOrgId != null && selectedOrgId.isNotEmpty) {
      for (final org in _organizations) {
        if (org['id']?.toString() == selectedOrgId) {
          selectedOrganization = org;
          break;
        }
      }
    }

    final selectedMembers =
        selectedOrgId == null
            ? const <Map<String, dynamic>>[]
            : (_organizationMembersById[selectedOrgId] ??
                const <Map<String, dynamic>>[]);

    final selectedCalls =
        selectedOrgId == null
            ? const <Map<String, dynamic>>[]
            : (_organizationCallsById[selectedOrgId] ??
                const <Map<String, dynamic>>[]);

    final selectedStats =
        selectedOrgId == null
            ? const <String, dynamic>{}
            : (_organizationStatsById[selectedOrgId] ??
                const <String, dynamic>{});

    if (selectedOrgId != null && selectedOrganization != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedOrganizationId = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Organizations list',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Organization Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildOrganizationDetailsPanel(
                organization: selectedOrganization,
                members: selectedMembers,
                calls: selectedCalls,
                stats: selectedStats,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrganizationsSummaryRow(_organizations),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Organizations',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ColorManager.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  showFilteredCount
                      ? '${filteredOrganizations.length}/${_organizations.length}'
                      : '${_organizations.length}',
                  style: TextStyle(
                    color: ColorManager.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Include inactive'),
                selected: _showInactiveOrganizations,
                onSelected: (value) {
                  setState(() {
                    _showInactiveOrganizations = value;
                    if (!_filteredOrganizations().any((org) => org['id']?.toString() == _selectedOrganizationId)) {
                      _selectedOrganizationId = null;
                    }
                  });
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _generateRegistrationCode,
                icon: const Icon(Icons.vpn_key),
                label: const Text('Generate Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primary2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadOrganizations,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth =
                      constraints.maxWidth > 1400
                          ? constraints.maxWidth
                          : 1400.0;
                  final tableHeight =
                      constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : 420.0;

                  Widget tableBody;
                  if (_isLoadingOrganizations && _organizations.isEmpty) {
                    tableBody =
                        const Center(child: CircularProgressIndicator());
                  } else if (filteredOrganizations.isEmpty) {
                    tableBody = Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildOrganizationsEmptyState(
                          _organizations.isEmpty
                              ? 'No organizations found.'
                              : 'No organizations matched your search.',
                        ),
                      ),
                    );
                  } else {
                    tableBody = ListView.builder(
                      itemCount: filteredOrganizations.length,
                      itemBuilder: (context, index) {
                        final org = filteredOrganizations[index];
                        final orgId = org['id']?.toString() ?? '';
                        final stats = _organizationStatsById[orgId] ??
                            const <String, dynamic>{};
                        final isSelected = orgId == selectedOrgId;

                        return _buildOrganizationsTableRow(
                          organization: org,
                          stats: stats,
                          isSelected: isSelected,
                          index: index,
                        );
                      },
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: tableHeight,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Organization',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Contact',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Doctors',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Calls',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Usage Spend',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Wallet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: tableBody),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationsSummaryRow(List<Map<String, dynamic>> organizations) {
    var activeOrganizations = 0;
    var totalDoctors = 0;
    var totalCalls = 0;
    var totalCost = 0.0;

    for (final org in organizations) {
      if (org['is_active'] != false) {
        activeOrganizations++;
      }

      final orgId = org['id']?.toString();
      if (orgId == null || orgId.isEmpty) continue;

      final stats = _organizationStatsById[orgId];
      if (stats == null) continue;

      totalDoctors += _asInt(stats['doctors_count']);
      totalCalls += _asInt(stats['calls_count']);
      totalCost += _asDouble(stats['total_cost']);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            'Organizations',
            '${organizations.length}',
            Icons.business,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Active Organizations',
            '$activeOrganizations',
            Icons.verified,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Doctors',
            '$totalDoctors',
            Icons.medical_information_outlined,
            const Color(0xFF6366F1),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Total Calls',
            '$totalCalls',
            Icons.call,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Usage Spend',
            _formatCurrency(totalCost),
            Icons.payments_outlined,
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Future<void> _generateRegistrationCode() async {
    try {
      final code = 'ORG-${_generateRandomString(4)}-${_generateRandomString(4)}'.toUpperCase();
      
      await Supabase.instance.client.from('organization_registration_codes').insert({
        'code': code,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Code Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Give this code to the hospital/clinic so they can register:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    code,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: ColorManager.primary2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is a single-use code.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating code: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 1, 0
    final rnd = math.Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Widget _buildOrganizationsTableRow({
    required Map<String, dynamic> organization,
    required Map<String, dynamic> stats,
    required bool isSelected,
    required int index,
  }) {
    final orgId = organization['id']?.toString() ?? '';
    final orgName = organization['name']?.toString() ?? 'Unnamed Organization';
    final email = organization['email']?.toString() ?? '';
    final billingEmail = organization['billing_email']?.toString() ?? '';
    final inviteCode = organization['invite_code']?.toString() ?? '';
    final isActive = organization['is_active'] != false;
    final verificationStatus =
        organization['verification_status']?.toString().toLowerCase() ??
        'unknown';

    final doctorsCount = _asInt(stats['doctors_count']);
    final callsCount = _asInt(stats['calls_count']);
    final callsThisWeek = _asInt(stats['calls_this_week']);
    final totalCost = _asDouble(stats['total_cost']);
    final walletBalance = _asDouble(organization['wallet_balance']);

    Color verificationColor;
    String verificationLabel;
    switch (verificationStatus) {
      case 'approved':
        verificationColor = const Color(0xFF10B981);
        verificationLabel = 'Approved';
        break;
      case 'rejected':
        verificationColor = const Color(0xFFEF4444);
        verificationLabel = 'Rejected';
        break;
      case 'pending':
        verificationColor = const Color(0xFFF59E0B);
        verificationLabel = 'Pending';
        break;
      default:
        verificationColor = const Color(0xFF64748B);
        verificationLabel = 'Unknown';
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrganizationId = orgId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFFEEF2FF)
                  : index.isEven
                  ? Colors.white
                  : const Color(0xFFFAFBFC),
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                    child: Text(
                      orgName.isNotEmpty ? orgName[0].toUpperCase() : 'O',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orgName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (inviteCode.isNotEmpty)
                          Text(
                            'Invite: $inviteCode',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.isNotEmpty ? email : '-',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    billingEmail.isNotEmpty ? billingEmail : '-',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                '$doctorsCount',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$callsCount total',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    '$callsThisWeek this week',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                _formatCurrency(totalCost),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
            Expanded(
              child: Text(
                _formatCurrency(walletBalance),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      walletBalance <= 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBadge(
                    isActive ? 'Active' : 'Inactive',
                    isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusBadge(verificationLabel, verificationColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationDetailsPanel({
    required Map<String, dynamic>? organization,
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> calls,
    required Map<String, dynamic> stats,
  }) {
    if (organization == null) {
      return _buildOrganizationsEmptyState(
        'Select an organization to view doctors, call usage, and billing details.',
      );
    }

    final orgName = organization['name']?.toString() ?? 'Organization';
    final orgId = organization['id']?.toString() ?? '';
    final walletBalance = _asDouble(organization['wallet_balance']);
    final ratePerMinute = _asDouble(organization['rate_per_minute']);
    final callsCount = _asInt(stats['calls_count']);
    final callsThisWeek = _asInt(stats['calls_this_week']);
    final totalCost = _asDouble(stats['total_cost']);
    final doctorsCount = _asInt(stats['doctors_count']);
    final activeDoctors = _asInt(stats['active_doctors_count']);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$orgName Details',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Last call: ${_formatShortDateTime(stats['last_call_at'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryCard(
                  'Doctors',
                  '$doctorsCount',
                  Icons.people,
                  const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Active Doctors',
                  '$activeDoctors',
                  Icons.how_to_reg,
                  const Color(0xFF10B981),
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Calls (Week / Total)',
                  '$callsThisWeek / $callsCount',
                  Icons.call,
                  const Color(0xFF6366F1),
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Total Usage Spend',
                  _formatCurrency(totalCost),
                  Icons.account_balance_wallet,
                  const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Wallet / Rate',
                  '${_formatCurrency(walletBalance)} / ${_formatCurrency(ratePerMinute)}m',
                  Icons.payments,
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildOrganizationMetaItem('Organization ID', orgId),
                _buildOrganizationMetaItem(
                  'Email',
                  organization['email']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Billing Email',
                  organization['billing_email']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Billing Contact',
                  organization['billing_contact_name']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Phone',
                  organization['phone']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Address',
                  organization['address']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Billing Method',
                  organization['billing_method']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Invite Code',
                  organization['invite_code']?.toString() ?? '-',
                ),
                _buildOrganizationMetaItem(
                  'Created',
                  _formatShortDate(organization['created_at']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildOrganizationDoctorsTable(
            organizationId: orgId,
            members: members,
            stats: stats,
          ),
          const SizedBox(height: 16),
          _buildOrganizationRecentCallsTable(
            organizationId: orgId,
            calls: calls,
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationMetaItem(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationDoctorsTable({
    required String organizationId,
    required List<Map<String, dynamic>> members,
    required Map<String, dynamic> stats,
  }) {
    final doctors =
        members.where((member) => member['role']?.toString() == 'doctor').toList();

    if (doctors.isEmpty) {
      return _buildOrganizationsEmptyState(
        'No doctors linked to this organization yet.',
      );
    }

    doctors.sort(
      (a, b) =>
          _asDouble(b['total_spent']).compareTo(_asDouble(a['total_spent'])),
    );

    final usageByDoctor = <String, Map<String, dynamic>>{};
    final usageRaw = stats['doctor_usage'];
    if (usageRaw is Map) {
      usageRaw.forEach((key, value) {
        final usage = _asMap(value);
        if (usage == null) return;
        usageByDoctor[key.toString()] = usage;
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Doctors & Usage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${doctors.length}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  constraints.maxWidth > 1250 ? constraints.maxWidth : 1250.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade100),
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Doctor',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Calls',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Minutes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Call Cost',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Total Spent',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Limit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Joined',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...doctors.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doctor = entry.value;
                        final profile = _asMap(doctor['_profile']);
                        final userId = doctor['user_id']?.toString() ?? '';
                        final shortId = _shortInterpreterId(userId);
                        final displayName =
                            profile?['full_name']?.toString() ??
                            profile?['username']?.toString() ??
                            'Doctor';

                        final usage = usageByDoctor[userId] ??
                            const <String, dynamic>{};
                        final callsCount = _asInt(usage['calls']);
                        final usageDurationSeconds =
                            _asInt(usage['duration_seconds']);
                        final usageMinutes = (usageDurationSeconds / 60).ceil();
                        final usageCost = _asDouble(usage['cost']);

                        final totalSpent = _asDouble(doctor['total_spent']);
                        final spendingLimit = doctor['spending_limit'];
                        final isActive = doctor['is_active'] != false;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                index.isEven
                                    ? Colors.white
                                    : const Color(0xFFFAFBFC),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      shortId.isEmpty ? userId : 'ID $shortId',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: _buildStatusBadge(
                                  isActive ? 'Active' : 'Inactive',
                                  isActive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$callsCount',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$usageMinutes',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatCurrency(usageCost),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatCurrency(totalSpent),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  spendingLimit == null
                                      ? 'No limit'
                                      : _formatCurrency(spendingLimit),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        spendingLimit == null
                                            ? Colors.grey.shade500
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatShortDate(doctor['joined_at']),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationRecentCallsTable({
    required String organizationId,
    required List<Map<String, dynamic>> calls,
  }) {
    if (calls.isEmpty) {
      return _buildOrganizationsEmptyState(
        'No call history available for this organization yet.',
      );
    }

    final sortedCalls = List<Map<String, dynamic>>.from(calls)
      ..sort((a, b) {
        final aDate = _parseDateTime(a['started_at']);
        final bDate = _parseDateTime(b['started_at']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final recentCalls =
        sortedCalls.length > 25 ? sortedCalls.take(25).toList() : sortedCalls;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Recent Calls',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${recentCalls.length}',
                    style: const TextStyle(
                      color: Color(0xFF0E7490),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Organization: ${organizationId.length > 8 ? organizationId.substring(0, 8) : organizationId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  constraints.maxWidth > 1180 ? constraints.maxWidth : 1180.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade100),
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Doctor',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Interpreter',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Duration',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Cost',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Started',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Ended',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Request',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...recentCalls.asMap().entries.map((entry) {
                        final index = entry.key;
                        final call = entry.value;

                        final requester = _asMap(call['_requester']);
                        final interpreter = _asMap(call['_interpreter']);

                        final requesterName =
                            requester?['full_name']?.toString() ??
                            requester?['username']?.toString() ??
                            'Doctor';
                        final interpreterName =
                            interpreter?['full_name']?.toString() ??
                            interpreter?['username']?.toString() ??
                            'Interpreter';

                        final durationSeconds = _asInt(call['duration_seconds']);
                        final minutes = durationSeconds ~/ 60;
                        final seconds = durationSeconds % 60;

                        final cost = _asDouble(call['cost']);
                        final startedAt = _formatShortDateTime(call['started_at']);
                        final endedAt = _formatShortDateTime(call['ended_at']);
                        final requestId = call['request_id']?.toString() ?? '-';

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                index.isEven
                                    ? Colors.white
                                    : const Color(0xFFFAFBFC),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  requesterName,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  interpreterName,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatCurrency(cost),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  startedAt,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  endedAt,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  requestId.length > 18
                                      ? '${requestId.substring(0, 18)}...'
                                      : requestId,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationsEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ──────── MOBILE FALLBACK ────────
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await _supabaseService.signOut();
              await _appPreferences.logout();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search interpreters...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _load(reset: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _items.isEmpty && !_isLoading
                    ? const Center(child: Text('No interpreters found'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length) return _buildLoadMore();
                        final item = _items[index] as Map;
                        final userId = item['user_id']?.toString() ?? '';
                        final username =
                            item['username']?.toString() ?? 'Unknown';
                        final isVerified = item['is_verified'] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => _openDetails(userId),
                            leading: CircleAvatar(
                              backgroundColor:
                                  isVerified
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color:
                                      isVerified
                                          ? Colors.green.shade800
                                          : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'ID: ${userId.substring(0, 8)}...',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // ──────── HELPER: Broadcast Dialog ────────
  Future<void> _showBroadcastDialog(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool sendEmail = true;
    bool sendPush = true;
    bool isSending = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Broadcast Message'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Send a message to ALL verified interpreters.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subject / Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Message Body',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Send Email (Resend)'),
                        value: sendEmail,
                        onChanged:
                            (val) =>
                                setDialogState(() => sendEmail = val ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('Send Push Notification (OneSignal)'),
                        value: sendPush,
                        onChanged:
                            (val) =>
                                setDialogState(() => sendPush = val ?? false),
                      ),
                      if (isSending)
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      isSending
                          ? null
                          : () async {
                            final subject = titleCtrl.text.trim();
                            final message = messageCtrl.text.trim();
                            if (subject.isEmpty || message.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Subject and message are required',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!sendEmail && !sendPush) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Select at least one delivery method',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isSending = true);

                            try {
                              final result = await _adminService
                                  .sendAdminBroadcast(
                                    subject: subject,
                                    message: message,
                                    sendEmail: sendEmail,
                                    sendPush: sendPush,
                                  );

                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                final delivered = result['deliveredToCounts'];
                                final errors = result['errors'];
                                if (errors != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Warning - partially failed: $errors\nSent to: ${delivered?['emails']} emails.',
                                      ),
                                      duration: const Duration(seconds: 10),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Broadcast sent successfully!',
                                      ),
                                      duration: Duration(seconds: 5),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => isSending = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to send broadcast: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  child: const Text('Send Broadcast'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
