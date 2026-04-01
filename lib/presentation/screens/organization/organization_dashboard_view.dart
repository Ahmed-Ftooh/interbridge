import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:interbridge/config.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_bloc.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_event.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_state.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/payment_success_dialog.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class OrganizationDashboardView extends StatefulWidget {
  const OrganizationDashboardView({super.key});

  @override
  State<OrganizationDashboardView> createState() =>
      _OrganizationDashboardViewState();
}

class _OrganizationDashboardViewState extends State<OrganizationDashboardView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _checkoutInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    // Load data when view initializes
    context.read<OrganizationDashboardBloc>().add(const LoadOrganizationData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from external Stripe checkout, refresh data
    if (state == AppLifecycleState.resumed && _checkoutInProgress) {
      _checkoutInProgress = false;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          context.read<OrganizationDashboardBloc>().add(
            const RefreshOrganizationData(),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrganizationDashboardBloc, OrganizationDashboardState>(
      listener: (context, state) {
        // Handle message display from state
        if (state is OrganizationDashboardLoaded && state.message != null) {
          CustomSnackBar.show(
            context,
            message: state.message!,
            type: state.isError ? SnackBarType.error : SnackBarType.success,
          );
        }
        // Handle Stripe checkout URL (fallback, mainly for web)
        if (state is OrganizationDashboardLoaded && state.checkoutUrl != null) {
          _openStripeCheckout(state.checkoutUrl!);
          context.read<OrganizationDashboardBloc>().add(
            const ClearCheckoutUrl(),
          );
        }
        // Handle mobile Stripe Payment Sheet
        if (state is OrganizationDashboardLoaded &&
            state.paymentSheetData != null) {
          _presentPaymentSheet(state.paymentSheetData!);
          context.read<OrganizationDashboardBloc>().add(
            const ClearPaymentSheetData(),
          );
        }
        // Handle payment success — show animated dialog
        if (state is OrganizationDashboardLoaded &&
            state.paymentSuccessAmount != null) {
          final amount = state.paymentSuccessAmount!;
          context.read<OrganizationDashboardBloc>().add(
            const ClearPaymentSuccess(),
          );
          PaymentSuccessDialog.show(context, amount: amount);
        }
      },
      builder: (context, state) {
        if (state is OrganizationDashboardLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is OrganizationNotFound) {
          return Scaffold(
            appBar: AppBar(title: const Text('Organization Dashboard')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No organization found'),
                  const SizedBox(height: 16),
                  Text(
                    'User ID: ${state.userId}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed:
                        () => context.read<OrganizationDashboardBloc>().add(
                          const LoadOrganizationData(),
                        ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is OrganizationDashboardError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Organization Dashboard')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () => context.read<OrganizationDashboardBloc>().add(
                          const LoadOrganizationData(),
                        ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is OrganizationDashboardLoaded) {
          return _buildLoadedContent(state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadedContent(OrganizationDashboardLoaded state) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        title: Text(
          state.organizationName,
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
            onPressed:
                () => context.read<OrganizationDashboardBloc>().add(
                  const RefreshOrganizationData(),
                ),
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
          _buildOverviewTab(state),
          _buildDoctorsTab(state),
          _buildCallsTab(state),
          _buildBillingTab(state),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(OrganizationDashboardLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSize.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Balance Card
          _buildStatCard(
            title: 'Wallet Balance',
            value: '\$${state.walletBalance.toStringAsFixed(2)}',
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
                  value: '\$${state.ratePerMinute.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: ColorManager.primary,
                ),
              ),
              const SizedBox(width: AppSize.s16),
              Expanded(
                child: _buildStatCard(
                  title: 'Doctors',
                  value: '${state.members.length}',
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
                  value: '${state.callHistory.length}',
                  icon: Icons.call,
                  color: ColorManager.warning,
                ),
              ),
              const SizedBox(width: AppSize.s16),
              Expanded(
                child: _buildStatCard(
                  title: 'This Month',
                  value: '${state.thisMonthCalls}',
                  icon: Icons.calendar_today,
                  color: ColorManager.primary2,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSize.s24),

          // Invite Code Section
          _buildInviteCodeSection(state),

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
                  onTap: () => _showInviteDialog(state),
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

  Widget _buildInviteCodeSection(OrganizationDashboardLoaded state) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(color: ColorManager.primary2.withValues(alpha: 0.3)),
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
                    state.inviteCode,
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
                  Clipboard.setData(ClipboardData(text: state.inviteCode));
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
    );
  }

  Widget _buildDoctorsTab(OrganizationDashboardLoaded state) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Add Doctor Button
          Padding(
            padding: const EdgeInsets.all(AppSize.s16),
            child: ElevatedButton.icon(
              onPressed: () => _showInviteDialog(state),
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
                Tab(text: 'Members (${state.members.length})'),
                Tab(text: 'Pending (${state.pendingInvites.length})'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildMembersList(state),
                _buildPendingInvitesList(state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(OrganizationDashboardLoaded state) {
    if (state.members.isEmpty) {
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
      itemCount: state.members.length,
      itemBuilder: (context, index) {
        final member = state.members[index];
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

  Widget _buildPendingInvitesList(OrganizationDashboardLoaded state) {
    if (state.pendingInvites.isEmpty) {
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
      itemCount: state.pendingInvites.length,
      itemBuilder: (context, index) {
        final invite = state.pendingInvites[index];
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
              onPressed:
                  () => context.read<OrganizationDashboardBloc>().add(
                    CancelInvitation(invite['id']),
                  ),
              tooltip: 'Cancel invitation',
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallsTab(OrganizationDashboardLoaded state) {
    return state.callHistory.isEmpty
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
          itemCount: state.callHistory.length,
          itemBuilder: (context, index) {
            final call = state.callHistory[index];
            final meta = call['metadata'] as Map<String, dynamic>? ?? {};
            final duration = call['duration_seconds'] ?? 0;
            final cost = call['cost'] ?? 0;
            final startedAt = DateTime.tryParse(call['started_at'] ?? '');
            final fromLang = meta['from_language'] ?? 'Unknown';
            final toLang = meta['to_language'] ?? 'Unknown';

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
                                '$fromLang → $toLang',
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

  Widget _buildBillingTab(OrganizationDashboardLoaded state) {
    final lowBalance = state.walletBalance < (state.ratePerMinute * 30);

    return ListView(
      padding: const EdgeInsets.all(AppSize.s16),
      children: [
        // Low balance warning
        if (lowBalance)
          Container(
            margin: const EdgeInsets.only(bottom: AppSize.s16),
            padding: const EdgeInsets.all(AppSize.s12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(AppSize.s12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Low balance (\$${state.walletBalance.toStringAsFixed(2)}). Top up to avoid interruption.',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Balance Card
        Container(
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
                '\$${state.walletBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppSize.s36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rate: \$${state.ratePerMinute.toStringAsFixed(2)}/min',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: AppSize.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showTopUpDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Top Up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ColorManager.primary2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSize.s8),
                      ),
                    ),
                  ),
                  if (state.isProcessingTopUp)
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSize.s24),

        // Doctor Spending Section
        if (state.members.any((m) => m['role'] == 'doctor')) ...[
          _buildMobileSectionHeader('Doctor Spending'),
          const SizedBox(height: AppSize.s8),
          ...state.members.where((m) => m['role'] == 'doctor').map((doc) {
            final profile = doc['users_profile'] as Map<String, dynamic>? ?? {};
            final name =
                profile['full_name'] ?? profile['username'] ?? 'Doctor';
            final spent = (doc['total_spent'] as num?)?.toDouble() ?? 0.0;
            final limit = (doc['spending_limit'] as num?)?.toDouble() ?? 0.0;
            final hasLimit = limit > 0;
            final overLimit = hasLimit && spent >= limit;

            return Card(
              margin: const EdgeInsets.only(bottom: AppSize.s8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      overLimit
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDBEAFE),
                  child: Icon(
                    overLimit ? Icons.warning : Icons.person,
                    color:
                        overLimit
                            ? const Color(0xFFDC2626)
                            : ColorManager.primary2,
                    size: 20,
                  ),
                ),
                title: Text(
                  name.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle:
                    hasLimit
                        ? Text(
                          'Limit: \$${limit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: AppSize.s12,
                            color: ColorManager.textSecondary,
                          ),
                        )
                        : null,
                trailing: Text(
                  '\$${spent.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        overLimit
                            ? const Color(0xFFDC2626)
                            : ColorManager.textPrimary,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSize.s24),
        ],

        // Invoices Section
        Row(
          children: [
            Expanded(child: _buildMobileSectionHeader('Invoices')),
            OutlinedButton.icon(
              onPressed:
                  state.isGeneratingInvoice
                      ? null
                      : () => _showGenerateInvoiceDialog(state),
              icon:
                  state.isGeneratingInvoice
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.add_chart, size: 16),
              label: Text(
                state.isGeneratingInvoice ? 'Generating...' : 'Generate',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSize.s8),
        if (state.invoices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No invoices yet',
                style: TextStyle(color: ColorManager.textSecondary),
              ),
            ),
          )
        else
          ...state.invoices.map((inv) {
            final number = inv['invoice_number'] ?? '-';
            final start = inv['billing_period_start'] ?? '';
            final end = inv['billing_period_end'] ?? '';
            final amount = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
            final status = inv['status'] ?? 'draft';
            final pdfUrl = inv['pdf_url'] as String?;
            final calls = inv['total_calls'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: AppSize.s8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _invoiceStatusColor(
                    status,
                  ).withValues(alpha: 0.15),
                  child: Text(
                    '#$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _invoiceStatusColor(status),
                    ),
                  ),
                ),
                title: Text(
                  '${_formatShortDate(start)} — ${_formatShortDate(end)}',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  '$calls calls • ${status[0].toUpperCase()}${status.substring(1)}',
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    color: _invoiceStatusColor(status),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (pdfUrl != null)
                      IconButton(
                        onPressed: () => _openInvoice(pdfUrl),
                        icon: Icon(
                          Icons.download,
                          size: 20,
                          color: ColorManager.primary2,
                        ),
                        tooltip: 'Download',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: AppSize.s24),

        // Transaction History
        _buildMobileSectionHeader('Transaction History'),
        const SizedBox(height: AppSize.s8),
        if (state.transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: ColorManager.textSecondary),
              ),
            ),
          )
        else
          ...state.transactions.map((txn) {
            final type = txn['transaction_type'] as String? ?? '';
            final amount = txn['amount'] ?? 0;
            final balanceAfter = txn['balance_after'] ?? 0;
            final createdAt = DateTime.tryParse(txn['created_at'] ?? '');
            final isCredit = type == 'topup' || type == 'refund';

            return Card(
              margin: const EdgeInsets.only(bottom: AppSize.s8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isCredit
                          ? ColorManager.success.withValues(alpha: 0.1)
                          : ColorManager.error.withValues(alpha: 0.1),
                  child: Icon(
                    isCredit ? Icons.add : Icons.remove,
                    color: isCredit ? ColorManager.success : ColorManager.error,
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
                          DateFormat('MMM d, yyyy h:mm a').format(createdAt),
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
          }),
      ],
    );
  }

  Widget _buildMobileSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppSize.s16,
        fontWeight: FontWeight.bold,
        color: ColorManager.textPrimary,
      ),
    );
  }

  Color _invoiceStatusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF22C55E);
      case 'sent':
        return const Color(0xFF3B82F6);
      case 'overdue':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatShortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _openInvoice(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openStripeCheckout(String url) async {
    _checkoutInProgress = true;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _checkoutInProgress = false;
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Could not open payment page. Please try again.',
          type: SnackBarType.error,
        );
      }
    }
  }

  /// Present Stripe's native Payment Sheet as a bottom sheet
  Future<void> _presentPaymentSheet(Map<String, String> paymentData) async {
    try {
      // Initialize Stripe with publishable key
      Stripe.publishableKey = stripePublishableKey;

      // Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentData['paymentIntentClientSecret']!,
          customerEphemeralKeySecret: paymentData['ephemeralKeySecret']!,
          customerId: paymentData['customerId']!,
          merchantDisplayName: 'InterBridge',
          style: ThemeMode.system,
        ),
      );

      // Present the payment sheet (native bottom sheet)
      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded
      if (mounted) {
        final amount = double.tryParse(paymentData['amount'] ?? '0') ?? 0;
        final paymentIntentId = paymentData['paymentIntentId'] ?? '';
        context.read<OrganizationDashboardBloc>().add(
          PaymentSheetCompleted(amount, paymentIntentId: paymentIntentId),
        );
      }
    } on StripeException catch (e) {
      if (mounted) {
        final msg = e.error.localizedMessage ?? 'Payment cancelled';
        if (e.error.code != FailureCode.Canceled) {
          CustomSnackBar.show(context, message: msg, type: SnackBarType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Payment failed: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _showGenerateInvoiceDialog(OrganizationDashboardLoaded state) {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month == 1 ? 12 : now.month - 1;
    if (now.month == 1) selectedYear = now.year - 1;
    bool sendEmail = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Generate Invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(
                                DateFormat.MMM().format(DateTime(2024, i + 1)),
                              ),
                            ),
                          ),
                          onChanged:
                              (v) => setDialogState(() => selectedMonth = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items:
                              [now.year - 1, now.year]
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text('$y'),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setDialogState(() => selectedYear = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: sendEmail,
                    onChanged:
                        (v) => setDialogState(() => sendEmail = v ?? false),
                    title: const Text(
                      'Send via email',
                      style: TextStyle(fontSize: 14),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.read<OrganizationDashboardBloc>().add(
                      GenerateInvoice(
                        year: selectedYear,
                        month: selectedMonth,
                        sendEmail: sendEmail,
                      ),
                    );
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================
  // Helper Widgets
  // ============================================

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

  // ============================================
  // Dialogs
  // ============================================

  void _showInviteDialog(OrganizationDashboardLoaded state) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (dialogContext) => BlocProvider.value(
            value: context.read<OrganizationDashboardBloc>(),
            child: BlocConsumer<
              OrganizationDashboardBloc,
              OrganizationDashboardState
            >(
              listener: (context, blocState) {
                // Close dialog on success
                if (blocState is OrganizationDashboardLoaded &&
                    !blocState.isSendingInvite &&
                    blocState.message != null &&
                    !blocState.isError) {
                  Navigator.pop(dialogContext);
                }
              },
              builder: (context, blocState) {
                final isLoading =
                    blocState is OrganizationDashboardLoaded &&
                    blocState.isSendingInvite;

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
                      onPressed:
                          isLoading ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          isLoading
                              ? null
                              : () {
                                if (!formKey.currentState!.validate()) return;
                                context.read<OrganizationDashboardBloc>().add(
                                  SendDoctorInvitation(
                                    emailController.text.trim(),
                                  ),
                                );
                              },
                      icon:
                          isLoading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.send),
                      label: Text(isLoading ? 'Sending...' : 'Send Invitation'),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount < 5) {
                    CustomSnackBar.show(
                      context,
                      message: 'Minimum top-up amount is \$5',
                      type: SnackBarType.error,
                    );
                    return;
                  }
                  Navigator.pop(dialogContext);
                  // Use native Stripe Payment Sheet on mobile
                  context.read<OrganizationDashboardBloc>().add(
                    OpenMobilePaymentSheet(amount),
                  );
                },
                child: const Text('Continue to Payment'),
              ),
            ],
          ),
    );
  }
}
