import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_bloc.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_event.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_state.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/payment_success_dialog.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web-specific organization dashboard with modern design
class OrganizationDashboardWebView extends StatefulWidget {
  const OrganizationDashboardWebView({super.key});

  @override
  State<OrganizationDashboardWebView> createState() =>
      _OrganizationDashboardWebViewState();
}

class _OrganizationDashboardWebViewState
    extends State<OrganizationDashboardWebView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTab = 0;
  final List<String> _tabNames = ['Overview', 'Doctors', 'Calls', 'Billing'];
  bool _checkoutInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<OrganizationDashboardBloc>().add(const LoadOrganizationData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the tab regains focus after Stripe checkout, refresh data
    if (state == AppLifecycleState.resumed && _checkoutInProgress) {
      _checkoutInProgress = false;
      // Delay to give webhook time to process
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<OrganizationDashboardBloc, OrganizationDashboardState>(
        listener: (context, state) {
          if (state is OrganizationDashboardLoaded && state.message != null) {
            CustomSnackBar.show(
              context,
              message: state.message!,
              type: state.isError ? SnackBarType.error : SnackBarType.success,
            );
          }
          // Open Stripe Checkout in browser when URL is available
          if (state is OrganizationDashboardLoaded &&
              state.checkoutUrl != null) {
            _openStripeCheckout(state.checkoutUrl!);
            // Clear the URL so it doesn't re-trigger on rebuild
            context.read<OrganizationDashboardBloc>().add(
              const ClearCheckoutUrl(),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (state is OrganizationNotFound) {
            return _buildErrorView(
              title: 'No Organization Found',
              message: 'User ID: ${state.userId}',
            );
          }

          if (state is OrganizationDashboardError) {
            return _buildErrorView(title: 'Error', message: state.message);
          }

          if (state is OrganizationDashboardLoaded) {
            return _buildLoadedContent(state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildErrorView({required String title, required String message}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
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

  Widget _buildLoadedContent(OrganizationDashboardLoaded state) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header
          _buildHeader(state),
          // Tab Bar
          _buildTabBar(),
          // Tab Content
          Expanded(child: _buildTabContent(state)),
        ],
      ),
    );
  }

  Widget _buildHeader(OrganizationDashboardLoaded state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.organizationName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Organization Dashboard',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                () => context.read<OrganizationDashboardBloc>().add(
                  const RefreshOrganizationData(),
                ),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  Routes.organizationSettingsRoute,
                ),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children:
            _tabNames.asMap().entries.map((entry) {
              final index = entry.key;
              final name = entry.value;
              final isSelected = _selectedTab == index;

              return InkWell(
                onTap: () => setState(() => _selectedTab = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            isSelected
                                ? const Color(0xFF0955FA)
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getTabIcon(index),
                        size: 18,
                        color:
                            isSelected
                                ? const Color(0xFF0955FA)
                                : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSelected
                                  ? const Color(0xFF0955FA)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.people;
      case 2:
        return Icons.call;
      case 3:
        return Icons.receipt_long;
      default:
        return Icons.dashboard;
    }
  }

  Widget _buildTabContent(OrganizationDashboardLoaded state) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(state);
      case 1:
        return _buildDoctorsTab(state);
      case 2:
        return _buildCallsTab(state);
      case 3:
        return _buildBillingTab(state);
      default:
        return _buildOverviewTab(state);
    }
  }

  Widget _buildOverviewTab(OrganizationDashboardLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildStatCard(
                title: 'Wallet Balance',
                value: '\$${state.walletBalance.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF22C55E),
              ),
              _buildStatCard(
                title: 'Rate/Min',
                value: '\$${state.ratePerMinute.toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: const Color(0xFF0955FA),
              ),
              _buildStatCard(
                title: 'Doctors',
                value: '${state.members.length}',
                icon: Icons.people,
                color: const Color(0xFF8B5CF6),
              ),
              _buildStatCard(
                title: 'Total Calls',
                value: '${state.callHistory.length}',
                icon: Icons.call,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Invite Code Section
          _buildInviteCodeCard(state),
          const SizedBox(height: 32),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.person_add,
                  label: 'Invite Doctor',
                  onTap: () => _showInviteDialog(state),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_card,
                  label: 'Top Up Wallet',
                  onTap: _showTopUpDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeCard(OrganizationDashboardLoaded state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share, color: Color(0xFF0955FA)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Invite Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0955FA).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0955FA).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.inviteCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF0955FA),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: state.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Color(0xFF0955FA)),
                  tooltip: 'Copy code',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share this code with doctors to invite them to your organization.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF0955FA)),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorsTab(OrganizationDashboardLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Members
          _buildSectionHeader('Active Doctors', Icons.people),
          const SizedBox(height: 16),
          if (state.members.isEmpty)
            _buildEmptyState(
              'No doctors yet. Invite doctors using the invite code.',
            )
          else
            _buildMembersTable(state.members),

          const SizedBox(height: 32),

          // Pending Invites
          _buildSectionHeader('Pending Invites', Icons.pending),
          const SizedBox(height: 16),
          if (state.pendingInvites.isEmpty)
            _buildEmptyState('No pending invites.')
          else
            _buildPendingInvitesTable(state.pendingInvites),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildMembersTable(List<Map<String, dynamic>> members) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Joined',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ...members.map((member) {
            final profile = member['profiles'] as Map<String, dynamic>? ?? {};
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(profile['username'] ?? 'Unknown'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      member['email'] ?? '',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(child: _buildRoleBadge(member['role'] ?? 'member')),
                  Expanded(
                    child: Text(
                      _formatDate(member['created_at']),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role.toLowerCase().contains('admin');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            isAdmin
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                : const Color(0xFF0955FA).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAdmin ? const Color(0xFF8B5CF6) : const Color(0xFF0955FA),
        ),
      ),
    );
  }

  Widget _buildPendingInvitesTable(List<Map<String, dynamic>> invites) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Sent',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ...invites.map((invite) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(invite['email'] ?? '')),
                  Expanded(
                    child: _buildStatusBadge(invite['status'] ?? 'pending'),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(invite['created_at']),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: IconButton(
                      onPressed: () {
                        context.read<OrganizationDashboardBloc>().add(
                          CancelInvitation(invite['id'] as String),
                        );
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Cancel invite',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF59E0B),
        ),
      ),
    );
  }

  Widget _buildCallsTab(OrganizationDashboardLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Call History', Icons.history),
          const SizedBox(height: 16),
          if (state.callHistory.isEmpty)
            _buildEmptyState('No calls yet.')
          else
            _buildCallsTable(state.callHistory),
        ],
      ),
    );
  }

  Widget _buildCallsTable(List<Map<String, dynamic>> calls) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Doctor',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Duration',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cost',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ...calls.map((call) {
            final requester =
                call['requester_profile'] as Map<String, dynamic>? ?? {};
            final duration = call['duration_minutes'] ?? 0;
            final cost = call['total_cost'] ?? 0.0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(requester['username'] ?? 'Unknown'),
                  ),
                  Expanded(child: Text('$duration min')),
                  Expanded(
                    child: Text(
                      '\$${(cost as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(call['started_at']),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBillingTab(OrganizationDashboardLoaded state) {
    final lowBalance = state.walletBalance < (state.ratePerMinute * 30);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Low balance warning
          if (lowBalance)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Low Balance Warning',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        Text(
                          'Your balance (\$${state.walletBalance.toStringAsFixed(2)}) covers less than 30 minutes. Top up to avoid service interruption.',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showTopUpDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Top Up Now'),
                  ),
                ],
              ),
            ),

          // Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${state.walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rate: \$${state.ratePerMinute.toStringAsFixed(2)}/min',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showTopUpDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Top Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0955FA),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                    if (state.isProcessingTopUp)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
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
          const SizedBox(height: 32),

          // Per-Doctor Spending
          if (state.members.isNotEmpty) ...[
            _buildSectionHeader('Doctor Spending', Icons.person_outline),
            const SizedBox(height: 16),
            _buildDoctorSpendingTable(state.members),
            const SizedBox(height: 32),
          ],

          // Invoices
          _buildSectionHeader('Invoices', Icons.receipt_long),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed:
                    state.isGeneratingInvoice
                        ? null
                        : () => _showGenerateInvoiceDialog(state),
                icon:
                    state.isGeneratingInvoice
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_chart, size: 18),
                label: Text(
                  state.isGeneratingInvoice
                      ? 'Generating...'
                      : 'Generate Invoice',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.invoices.isEmpty)
            _buildEmptyState(
              'No invoices yet. Generate one from your call history.',
            )
          else
            _buildInvoicesTable(state.invoices),
          const SizedBox(height: 32),

          // Transaction History
          _buildSectionHeader('Transaction History', Icons.swap_horiz),
          const SizedBox(height: 16),
          if (state.transactions.isEmpty)
            _buildEmptyState('No transactions yet.')
          else
            _buildTransactionsTable(state.transactions),
        ],
      ),
    );
  }

  Widget _buildDoctorSpendingTable(List<Map<String, dynamic>> members) {
    final doctors = members.where((m) => m['role'] == 'doctor').toList();

    if (doctors.isEmpty) {
      return _buildEmptyState('No doctors have made calls yet.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Doctor',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Spent',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Limit',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...doctors.map((doc) {
            final profile = doc['users_profile'] as Map<String, dynamic>? ?? {};
            final name =
                profile['full_name'] ?? profile['username'] ?? 'Doctor';
            final spent = (doc['total_spent'] as num?)?.toDouble() ?? 0.0;
            final limit = (doc['spending_limit'] as num?)?.toDouble() ?? 0.0;
            final hasLimit = limit > 0;
            final overLimit = hasLimit && spent >= limit;
            final nearLimit = hasLimit && spent >= limit * 0.8;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      name.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${spent.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            overLimit
                                ? const Color(0xFFDC2626)
                                : nearLimit
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hasLimit ? '\$${limit.toStringAsFixed(2)}' : 'No limit',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            overLimit
                                ? const Color(0xFFFEE2E2)
                                : nearLimit
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        overLimit
                            ? 'Over limit'
                            : nearLimit
                            ? 'Near limit'
                            : 'OK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              overLimit
                                  ? const Color(0xFFDC2626)
                                  : nearLimit
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF22C55E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInvoicesTable(List<Map<String, dynamic>> invoices) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Invoice #',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Period',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Calls',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 80),
              ],
            ),
          ),
          const Divider(height: 1),
          ...invoices.map((inv) {
            final number = inv['invoice_number'] ?? '-';
            final start = inv['billing_period_start'] ?? '';
            final end = inv['billing_period_end'] ?? '';
            final period = '${_formatDate(start)} — ${_formatDate(end)}';
            final calls = inv['total_calls'] ?? 0;
            final amount = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
            final status = inv['status'] ?? 'draft';
            final pdfUrl = inv['pdf_url'] as String?;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$number',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      period,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(child: Text('$calls')),
                  Expanded(
                    child: Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: _buildInvoiceStatusBadge(status)),
                  SizedBox(
                    width: 80,
                    child:
                        pdfUrl != null
                            ? IconButton(
                              onPressed: () => _openInvoice(pdfUrl),
                              icon: const Icon(
                                Icons.download,
                                size: 20,
                                color: Color(0xFF0955FA),
                              ),
                              tooltip: 'Download Invoice',
                            )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInvoiceStatusBadge(String status) {
    Color bg, fg;
    switch (status) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF22C55E);
        break;
      case 'sent':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF3B82F6);
        break;
      case 'overdue':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _checkoutInProgress = false;
        CustomSnackBar.show(
          context,
          message: 'Could not open payment page. Please try again.',
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to open payment page: $e',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Generate Monthly Invoice'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate an invoice for a billing period.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(
                                  DateFormat.MMMM().format(
                                    DateTime(2024, i + 1),
                                  ),
                                ),
                              ),
                            ),
                            onChanged:
                                (v) => setDialogState(() => selectedMonth = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
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
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: sendEmail,
                      onChanged:
                          (v) => setDialogState(() => sendEmail = v ?? false),
                      title: const Text('Send invoice via email'),
                      subtitle: const Text(
                        'Email will be sent to the billing contact',
                        style: TextStyle(fontSize: 12),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionsTable(List<Map<String, dynamic>> transactions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ...transactions.map((tx) {
            final type = tx['type'] ?? 'unknown';
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final isCredit = type == 'topup' || type == 'credit';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(tx['description'] ?? 'Transaction'),
                  ),
                  Expanded(child: _buildTransactionTypeBadge(type)),
                  Expanded(
                    child: Text(
                      '${isCredit ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isCredit
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(tx['created_at']),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeBadge(String type) {
    final isCredit = type == 'topup' || type == 'credit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            isCredit
                ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                : const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isCredit ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showInviteDialog(OrganizationDashboardLoaded state) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Invite Doctor'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the email address of the doctor you want to invite.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  context.read<OrganizationDashboardBloc>().add(
                    SendDoctorInvitation(email),
                  );
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        );
      },
    );
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Top Up Wallet'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the amount you want to add to your wallet.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(dialogContext);
                  context.read<OrganizationDashboardBloc>().add(
                    ProcessTopUp(amount),
                  );
                }
              },
              child: const Text('Top Up'),
            ),
          ],
        );
      },
    );
  }
}
