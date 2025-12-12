import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';

class OrganizationDashboardView extends StatefulWidget {
  const OrganizationDashboardView({super.key});

  @override
  State<OrganizationDashboardView> createState() =>
      _OrganizationDashboardViewState();
}

class _OrganizationDashboardViewState extends State<OrganizationDashboardView>
    with SingleTickerProviderStateMixin {
  final _supabase = SupabaseService();
  late TabController _tabController;

  Map<String, dynamic>? _organization;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  List<Map<String, dynamic>> _callHistory = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.getCurrentUser()?.id;
      final session = _supabase.client.auth.currentSession;
      debugPrint('OrganizationDashboard: Loading data for userId=$userId');
      debugPrint(
        'OrganizationDashboard: Session exists=${session != null}, hasAccessToken=${session?.accessToken != null}',
      );

      if (userId == null) {
        debugPrint('OrganizationDashboard: No user logged in');
        setState(() => _loading = false);
        return;
      }

      // Get organization for current user
      debugPrint(
        'OrganizationDashboard: Querying organization_members for user_id=$userId',
      );
      final memberData =
          await _supabase.client
              .from('organization_members')
              .select('organization_id, role')
              .eq('user_id', userId)
              .maybeSingle();

      debugPrint('OrganizationDashboard: memberData=$memberData');

      if (memberData == null) {
        debugPrint(
          'OrganizationDashboard: No organization membership found for user',
        );
        setState(() => _loading = false);
        return;
      }

      final orgId = memberData['organization_id'];

      // Load organization details
      final org =
          await _supabase.client
              .from('organizations')
              .select()
              .eq('id', orgId)
              .single();

      // Load members (without nested profile join - no direct FK)
      final membersRaw = await _supabase.client
          .from('organization_members')
          .select()
          .eq('organization_id', orgId)
          .order('joined_at', ascending: false);

      // Load profiles for all members
      final memberUserIds =
          (membersRaw as List).map((m) => m['user_id'] as String).toList();

      final profiles =
          memberUserIds.isNotEmpty
              ? await _supabase.client
                  .from('users_profile')
                  .select()
                  .inFilter('user_id', memberUserIds)
              : [];

      // Combine members with their profiles
      final profileMap = {for (var p in profiles) p['user_id']: p};

      final members =
          (membersRaw as List).map((m) {
            return {...m, 'users_profile': profileMap[m['user_id']]};
          }).toList();

      // Load call history (without nested join to be safe)
      final calls = await _supabase.client
          .from('call_logs')
          .select()
          .eq('organization_id', orgId)
          .order('started_at', ascending: false)
          .limit(50);

      // Load transactions
      final txns = await _supabase.client
          .from('organization_transactions')
          .select()
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(50);

      // Load pending invitations
      debugPrint(
        'OrganizationDashboard: Loading pending invites for orgId=$orgId',
      );
      final invites = await _supabase.client
          .from('organization_invites')
          .select()
          .eq('organization_id', orgId)
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      debugPrint(
        'OrganizationDashboard: Found ${invites.length} pending invites',
      );

      setState(() {
        _organization = org;
        _members =
            (members as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        _pendingInvites =
            (invites as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        _callHistory =
            (calls as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        _transactions =
            (txns as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading organization data: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_organization == null) {
      final userId = _supabase.getCurrentUser()?.id ?? 'Not logged in';
      return Scaffold(
        appBar: AppBar(title: const Text('Organization Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization found'),
              const SizedBox(height: 16),
              Text('User ID: $userId', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        title: Text(
          _organization!['name'] ?? 'Organization',
          style: const TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Doctors'),
            Tab(icon: Icon(Icons.call), text: 'Calls'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Billing'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, Routes.organizationSettingsRoute);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildDoctorsTab(),
          _buildCallsTab(),
          _buildBillingTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final balance = _organization!['wallet_balance'] ?? 0;
    final rate = _organization!['rate_per_minute'] ?? 1;
    final inviteCode = _organization!['invite_code'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSize.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Balance Card
          _buildStatCard(
            title: 'Wallet Balance',
            value: '\$${(balance as num).toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: ColorManager.success,
          ),
          const SizedBox(height: AppSize.s16),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Rate/Min',
                  value: '\$${(rate as num).toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: ColorManager.primary,
                ),
              ),
              const SizedBox(width: AppSize.s16),
              Expanded(
                child: _buildStatCard(
                  title: 'Doctors',
                  value: '${_members.length}',
                  icon: Icons.people,
                  color: ColorManager.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Calls',
                  value: '${_callHistory.length}',
                  icon: Icons.call,
                  color: ColorManager.warning,
                ),
              ),
              const SizedBox(width: AppSize.s16),
              Expanded(
                child: _buildStatCard(
                  title: 'This Month',
                  value: '${_getThisMonthCalls()}',
                  icon: Icons.calendar_today,
                  color: ColorManager.primary2,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSize.s24),

          // Invite Code Section
          Container(
            padding: const EdgeInsets.all(AppSize.s16),
            decoration: BoxDecoration(
              color: ColorManager.backgroundCard,
              borderRadius: BorderRadius.circular(AppSize.s12),
              border: Border.all(
                color: ColorManager.primary2.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.share, color: ColorManager.primary2),
                    const SizedBox(width: AppSize.s8),
                    Text(
                      'Invite Code',
                      style: TextStyle(
                        fontSize: AppSize.s16,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSize.s12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSize.s16,
                          vertical: AppSize.s12,
                        ),
                        decoration: BoxDecoration(
                          color: ColorManager.primary2.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSize.s8),
                        ),
                        child: Text(
                          inviteCode,
                          style: TextStyle(
                            fontSize: AppSize.s20,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.primary2,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSize.s12),
                    IconButton(
                      icon: Icon(Icons.copy, color: ColorManager.primary2),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        CustomSnackBar.show(
                          context,
                          message: 'Invite code copied!',
                          type: SnackBarType.success,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSize.s8),
                Text(
                  'Share this code with doctors to join your organization',
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSize.s24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: AppSize.s18,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          const SizedBox(height: AppSize.s12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.person_add,
                  label: 'Invite Doctor',
                  onTap: _showInviteDialog,
                ),
              ),
              const SizedBox(width: AppSize.s12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_card,
                  label: 'Top Up',
                  onTap: _showTopUpDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Add Doctor Button
          Padding(
            padding: const EdgeInsets.all(AppSize.s16),
            child: ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Doctor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary2,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSize.s12),
                ),
              ),
            ),
          ),

          // Sub-tabs for Members and Pending Invites
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSize.s16),
            decoration: BoxDecoration(
              color: ColorManager.greyLight,
              borderRadius: BorderRadius.circular(AppSize.s8),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: ColorManager.primary2,
                borderRadius: BorderRadius.circular(AppSize.s8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: ColorManager.textSecondary,
              tabs: [
                Tab(text: 'Members (${_members.length})'),
                Tab(text: 'Pending (${_pendingInvites.length})'),
              ],
            ),
          ),
          // Debug: show count
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Debug: ${_pendingInvites.length} pending invites loaded',
              style: TextStyle(fontSize: 10, color: ColorManager.textSecondary),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [_buildMembersList(), _buildPendingInvitesList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: ColorManager.greyMedium,
            ),
            const SizedBox(height: AppSize.s16),
            Text(
              'No doctors yet',
              style: TextStyle(
                fontSize: AppSize.s16,
                color: ColorManager.textSecondary,
              ),
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              'Invite doctors to your organization',
              style: TextStyle(
                fontSize: AppSize.s14,
                color: ColorManager.greyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSize.s16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final profile = member['users_profile'] as Map<String, dynamic>?;
        final role = member['role'] as String? ?? 'doctor';
        final isActive = member['is_active'] as bool? ?? true;
        final totalSpent = member['total_spent'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSize.s12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  role == 'organization_admin'
                      ? ColorManager.warning
                      : ColorManager.primary2,
              child: Icon(
                role == 'organization_admin'
                    ? Icons.admin_panel_settings
                    : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(
              profile?['username'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role == 'organization_admin' ? 'Admin' : 'Doctor'),
                Text(
                  'Spent: \$${(totalSpent as num).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSize.s8,
                vertical: AppSize.s4,
              ),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? ColorManager.success.withValues(alpha: 0.1)
                        : ColorManager.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSize.s8),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: AppSize.s12,
                  color: isActive ? ColorManager.success : ColorManager.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingInvitesList() {
    if (_pendingInvites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: ColorManager.greyMedium),
            const SizedBox(height: AppSize.s16),
            Text(
              'No pending invitations',
              style: TextStyle(
                fontSize: AppSize.s16,
                color: ColorManager.textSecondary,
              ),
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              'Invitations you send will appear here',
              style: TextStyle(
                fontSize: AppSize.s14,
                color: ColorManager.greyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSize.s16),
      itemCount: _pendingInvites.length,
      itemBuilder: (context, index) {
        final invite = _pendingInvites[index];
        final email = invite['email'] as String? ?? 'Unknown';
        final createdAt = DateTime.tryParse(invite['created_at'] ?? '');
        final expiresAt = DateTime.tryParse(invite['expires_at'] ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: AppSize.s12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ColorManager.warning.withValues(alpha: 0.2),
              child: Icon(Icons.hourglass_empty, color: ColorManager.warning),
            ),
            title: Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (createdAt != null)
                  Text(
                    'Sent: ${DateFormat('MMM d, yyyy').format(createdAt)}',
                    style: TextStyle(
                      fontSize: AppSize.s12,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                if (expiresAt != null)
                  Text(
                    'Expires: ${DateFormat('MMM d, yyyy').format(expiresAt)}',
                    style: TextStyle(
                      fontSize: AppSize.s12,
                      color: ColorManager.warning,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.cancel, color: ColorManager.error),
              onPressed: () => _cancelInvitation(invite['id']),
              tooltip: 'Cancel invitation',
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelInvitation(String inviteId) async {
    try {
      await _supabase.client
          .from('organization_invites')
          .update({'status': 'cancelled'})
          .eq('id', inviteId);

      await _loadData();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Invitation cancelled',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to cancel invitation',
          type: SnackBarType.error,
        );
      }
    }
  }

  Widget _buildCallsTab() {
    return _callHistory.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.call_outlined,
                size: 64,
                color: ColorManager.greyMedium,
              ),
              const SizedBox(height: AppSize.s16),
              Text(
                'No calls yet',
                style: TextStyle(
                  fontSize: AppSize.s16,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.all(AppSize.s16),
          itemCount: _callHistory.length,
          itemBuilder: (context, index) {
            final call = _callHistory[index];
            final request = call['call_requests'] as Map<String, dynamic>?;
            final duration = call['duration_seconds'] ?? 0;
            final cost = call['cost'] ?? 0;
            final startedAt = DateTime.tryParse(call['started_at'] ?? '');

            return Card(
              margin: const EdgeInsets.only(bottom: AppSize.s12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.s12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSize.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSize.s8),
                          decoration: BoxDecoration(
                            color: ColorManager.primary2.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSize.s8),
                          ),
                          child: Icon(
                            Icons.call,
                            color: ColorManager.primary2,
                            size: AppSize.s20,
                          ),
                        ),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${request?['from_language'] ?? 'Unknown'} → ${request?['to_language'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (startedAt != null)
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy h:mm a',
                                  ).format(startedAt),
                                  style: TextStyle(
                                    fontSize: AppSize.s12,
                                    color: ColorManager.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${(cost as num).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ColorManager.error,
                              ),
                            ),
                            Text(
                              '${(duration / 60).floor()}:${(duration % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: AppSize.s12,
                                color: ColorManager.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildBillingTab() {
    final balance = _organization!['wallet_balance'] ?? 0;

    return Column(
      children: [
        // Balance Card
        Container(
          margin: const EdgeInsets.all(AppSize.s16),
          padding: const EdgeInsets.all(AppSize.s24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ColorManager.primary2, ColorManager.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSize.s16),
          ),
          child: Column(
            children: [
              const Text(
                'Current Balance',
                style: TextStyle(color: Colors.white70, fontSize: AppSize.s14),
              ),
              const SizedBox(height: AppSize.s8),
              Text(
                '\$${(balance as num).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppSize.s36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSize.s16),
              ElevatedButton(
                onPressed: _showTopUpDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ColorManager.primary2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSize.s8),
                  ),
                ),
                child: const Text('Top Up Balance'),
              ),
            ],
          ),
        ),

        // Transactions List
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.s16),
          child: Row(
            children: [
              Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: AppSize.s16,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSize.s12),

        Expanded(
          child:
              _transactions.isEmpty
                  ? Center(
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(color: ColorManager.textSecondary),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s16,
                    ),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final txn = _transactions[index];
                      final type = txn['transaction_type'] as String? ?? '';
                      final amount = txn['amount'] ?? 0;
                      final balanceAfter = txn['balance_after'] ?? 0;
                      final createdAt = DateTime.tryParse(
                        txn['created_at'] ?? '',
                      );

                      final isCredit = type == 'topup' || type == 'refund';

                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSize.s8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isCredit
                                    ? ColorManager.success.withValues(
                                      alpha: 0.1,
                                    )
                                    : ColorManager.error.withValues(alpha: 0.1),
                            child: Icon(
                              isCredit ? Icons.add : Icons.remove,
                              color:
                                  isCredit
                                      ? ColorManager.success
                                      : ColorManager.error,
                            ),
                          ),
                          title: Text(
                            type == 'topup'
                                ? 'Top Up'
                                : type == 'call_charge'
                                ? 'Call Charge'
                                : 'Refund',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle:
                              createdAt != null
                                  ? Text(
                                    DateFormat(
                                      'MMM d, yyyy h:mm a',
                                    ).format(createdAt),
                                    style: TextStyle(
                                      fontSize: AppSize.s12,
                                      color: ColorManager.textSecondary,
                                    ),
                                  )
                                  : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isCredit ? '+' : '-'}\$${(amount as num).abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isCredit
                                          ? ColorManager.success
                                          : ColorManager.error,
                                ),
                              ),
                              Text(
                                'Bal: \$${(balanceAfter as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: AppSize.s12,
                                  color: ColorManager.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(AppSize.s12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSize.s8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s8),
                ),
                child: Icon(icon, color: color, size: AppSize.s20),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            value,
            style: TextStyle(
              fontSize: AppSize.s24,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          const SizedBox(height: AppSize.s4),
          Text(
            title,
            style: TextStyle(
              fontSize: AppSize.s12,
              color: ColorManager.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSize.s12),
      child: Container(
        padding: const EdgeInsets.all(AppSize.s16),
        decoration: BoxDecoration(
          color: ColorManager.backgroundCard,
          borderRadius: BorderRadius.circular(AppSize.s12),
          border: Border.all(
            color: ColorManager.primary2.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: ColorManager.primary2, size: AppSize.s28),
            const SizedBox(height: AppSize.s8),
            Text(
              label,
              style: TextStyle(
                fontSize: AppSize.s14,
                fontWeight: FontWeight.w500,
                color: ColorManager.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getThisMonthCalls() {
    final now = DateTime.now();
    return _callHistory.where((call) {
      final startedAt = DateTime.tryParse(call['started_at'] ?? '');
      if (startedAt == null) return false;
      return startedAt.month == now.month && startedAt.year == now.year;
    }).length;
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Invite Doctor'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter the doctor\'s email address to send an invitation:',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'doctor@example.com',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email address';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ColorManager.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: ColorManager.info,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'The doctor will receive an email with instructions to join your organization.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorManager.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        isLoading
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;

                              setDialogState(() => isLoading = true);

                              try {
                                await _sendInvitation(
                                  emailController.text.trim(),
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  CustomSnackBar.show(
                                    this.context,
                                    message: 'Invitation sent successfully!',
                                    type: SnackBarType.success,
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isLoading = false);
                                if (context.mounted) {
                                  CustomSnackBar.show(
                                    this.context,
                                    message: 'Failed to send invitation: $e',
                                    type: SnackBarType.error,
                                  );
                                }
                              }
                            },
                    icon:
                        isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.send),
                    label: Text(isLoading ? 'Sending...' : 'Send Invitation'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _sendInvitation(String email) async {
    final orgId = _organization!['id'];
    final orgName = _organization!['name'] ?? 'Organization';
    final userId = _supabase.getCurrentUser()?.id;

    debugPrint(
      'Sending invitation: orgId=$orgId, userId=$userId, email=$email',
    );

    if (userId == null) {
      throw Exception('User not logged in');
    }

    // Generate a unique invite code
    final inviteCode = _generateInviteCode();

    // Create invitation record
    try {
      await _supabase.client.from('organization_invites').insert({
        'organization_id': orgId,
        'inviter_id': userId,
        'email': email.toLowerCase(),
        'invite_code': inviteCode,
        'role': 'doctor',
        'status': 'pending',
        'expires_at':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });

      debugPrint('Invitation created for $email with code: $inviteCode');

      // Send invitation email via Edge Function
      try {
        final response = await _supabase.client.functions.invoke(
          'send-invite-email',
          body: {
            'to': email.toLowerCase(),
            'inviteCode': inviteCode,
            'organizationName': orgName,
          },
        );

        if (response.status == 200) {
          debugPrint('Invitation email sent successfully to $email');
        } else {
          debugPrint('Failed to send invitation email: ${response.data}');
          // Don't throw - the invite was created, just email failed
        }
      } catch (emailError) {
        debugPrint('Error sending invitation email: $emailError');
        // Don't throw - the invite was created, just email failed
      }

      // Reload data to show the new invitation
      await _loadData();
    } catch (e) {
      debugPrint('Error creating invitation: $e');
      rethrow;
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      8,
      (index) => chars[(random + index * 7) % chars.length],
    ).join();
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Top Up Balance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the amount to add to your wallet:'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement payment processing
                  Navigator.pop(context);
                  CustomSnackBar.show(
                    context,
                    message: 'Payment processing coming soon!',
                    type: SnackBarType.info,
                  );
                },
                child: const Text('Continue to Payment'),
              ),
            ],
          ),
    );
  }
}
