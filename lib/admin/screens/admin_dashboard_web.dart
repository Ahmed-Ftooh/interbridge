import 'dart:async';
import 'dart:developer';
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
  int _selectedNav = 0; // 0=interpreters, 1=pending reviews, 2=call logs
  bool _sidebarCollapsed = false;

  // Call logs data
  List<Map<String, dynamic>> _callLogs = [];
  List<Map<String, dynamic>> _activeCalls = [];
  bool _isLoadingCalls = false;
  Map<int, String> _languagesMap = {};

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
      final logs = await client
          .from('call_logs')
          .select('*')
          .order('started_at', ascending: false)
          .limit(100);

      // We had stale active calls because some older accepted requests
      // never got marked as completed correctly if someone disconnected unexpectedly.
      // We only consider requests created in the last 2 hours as 'active'.
      final twoHoursAgo =
          DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();

      final active = await client
          .from('interpreter_requests')
          .select('*')
          .eq('status', 'accepted')
          .gte('created_at', twoHoursAgo)
          .order('created_at', ascending: false);

      // Resolve user profiles for all unique user IDs
      final allLogs = List<Map<String, dynamic>>.from(logs);
      final allActive = List<Map<String, dynamic>>.from(active);

      final userIds = <String>{};
      for (final log in allLogs) {
        if (log['requester_id'] != null) userIds.add(log['requester_id']);
        if (log['interpreter_id'] != null) userIds.add(log['interpreter_id']);
      }
      for (final call in allActive) {
        if (call['requester_id'] != null) userIds.add(call['requester_id']);
        if (call['accepted_by'] != null) userIds.add(call['accepted_by']);
      }

      Map<String, Map<String, dynamic>> profileMap = {};
      if (userIds.isNotEmpty) {
        final profiles = await client
            .from('users_profile')
            .select('user_id, username, role')
            .inFilter('user_id', userIds.toList());
        for (final p in profiles) {
          profileMap[p['user_id'] as String] = Map<String, dynamic>.from(p);
        }
      }

      // Attach profiles to logs
      for (final log in allLogs) {
        log['_requester'] = profileMap[log['requester_id']];
        log['_interpreter'] = profileMap[log['interpreter_id']];
      }
      for (final call in allActive) {
        call['_requester'] = profileMap[call['requester_id']];
        call['_interpreter'] = profileMap[call['accepted_by']];
      }

      if (mounted) {
        setState(() {
          _callLogs = allLogs;
          _activeCalls = allActive;
          _isLoadingCalls = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading call logs: $e');
      if (mounted) {
        setState(() => _isLoadingCalls = false);
      }
    }
  }

  @override
  void dispose() {
    _stopListening();
    _searchCtrl.dispose();
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
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        drawer: Drawer(
          child: _buildSidebar(),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildMainContent()),
              ],
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
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search interpreters by name or 5-digit ID...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                onSubmitted: (_) => _load(reset: true),
              ),
            ),
          ),
          const SizedBox(width: 16),
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
            onPressed: () => _load(reset: true),
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
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth > 900 ? constraints.maxWidth : 900,
                      ),
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
                                      itemCount: _items.length + (_hasMore ? 1 : 0),
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
                  '${_callLogs.length}',
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
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth > 900 ? constraints.maxWidth : 900,
                      ),
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
                                    ? const Center(child: CircularProgressIndicator())
                                    : _callLogs.isEmpty
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
                                            'No call logs yet',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: _callLogs.length,
                                      itemBuilder: (context, index) {
                                        return _buildCallLogRow(
                                          _callLogs[index],
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
    final requester = call['_requester'] as Map<String, dynamic>?;
    final interpreter = call['_interpreter'] as Map<String, dynamic>?;
    final metadata = call['metadata'] as Map<String, dynamic>?;
    final fromLang = _getLanguageName(metadata?['from_language']);
    final toLang = _getLanguageName(metadata?['to_language']);
    final durationSec = (call['duration_seconds'] as int?) ?? 0;
    final cost = (call['cost'] as num?)?.toDouble() ?? 0.0;
    final startedAt = DateTime.tryParse(call['started_at'] ?? '');
    final endedAt = DateTime.tryParse(call['ended_at'] ?? '');
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
            flex: 2,
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
                  child: Text(
                    interpreter?['full_name'] ??
                        interpreter?['username'] ??
                        'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                        onChanged: (val) => setDialogState(() => sendEmail = val ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('Send Push Notification (OneSignal)'),
                        value: sendPush,
                        onChanged: (val) => setDialogState(() => sendPush = val ?? false),
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
                  onPressed: isSending
                      ? null
                      : () async {
                          final subject = titleCtrl.text.trim();
                          final message = messageCtrl.text.trim();
                          if (subject.isEmpty || message.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Subject and message are required')),
                            );
                            return;
                          }
                          if (!sendEmail && !sendPush) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Select at least one delivery method')),
                            );
                            return;
                          }

                          setDialogState(() => isSending = true);

                          try {
                            final result = await _adminService.sendAdminBroadcast(
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
                                    content: Text('Warning - partially failed: $errors\nSent to: ${delivered?['emails']} emails.'),
                                    duration: const Duration(seconds: 10),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Broadcast sent successfully!'),
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
                                  content: Text('Failed to send broadcast: $e'),
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
