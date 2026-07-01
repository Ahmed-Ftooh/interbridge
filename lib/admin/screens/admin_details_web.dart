import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:interbridge/admin/services/admin_service.dart';
import 'package:interbridge/admin/widgets/admin_stats_card.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDetailsWeb extends StatefulWidget {
  final String userId;
  const AdminDetailsWeb({super.key, required this.userId});

  @override
  State<AdminDetailsWeb> createState() => _AdminDetailsWebState();
}

class _AdminDetailsWebState extends State<AdminDetailsWeb>
    with SingleTickerProviderStateMixin {
  final _service = AdminService();
  final _callService = instance<CallService>();

  Map<String, dynamic> _data = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getInterpreterDetails(widget.userId),
        _callService.getCallStatistics(userId: widget.userId),
        _callService.getFeedbackStatistics(userId: widget.userId),
      ]);
      final details = results[0];
      final callStats = results[1];
      final feedbackStats = results[2];

      if (mounted) {
        setState(() {
          _data = details;
          _stats = {...callStats, ...feedbackStats};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  // Data accessors
  Map get _profile => (_data['profile'] ?? {}) as Map;
  Map get _details => (_data['details'] ?? {}) as Map;
  List get _languages => (_data['languages'] ?? []) as List;
  List get _skills => (_data['skills'] ?? []) as List;
  List get _specializations => (_data['specializations'] ?? []) as List;
  List get _certificates => (_data['certificates'] ?? []) as List;
  List get _voiceSamples => (_data['voiceSamples'] ?? []) as List;
  List get _quizAttempts => (_data['quizAttempts'] ?? []) as List;
  List get _badges => (_data['badges'] ?? []) as List;
  List get _governmentIds => (_data['governmentIds'] ?? []) as List;
  Map? get _phoneVerification => _data['phoneVerification'] as Map?;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: ColorManager.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Interpreter Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: isMobile ? _buildMobileBody() : _buildWebBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final username = _profile['username']?.toString() ?? 'Interpreter Details';
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: ColorManager.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          if (_details['is_verified'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_details['is_suspended'] == true) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 14, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'Suspended',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: ColorManager.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: ColorManager.primary,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Verification'),
          Tab(text: 'Documents'),
          Tab(text: 'Voice Samples'),
          Tab(text: 'Quiz Results'),
          Tab(text: 'Badges'),
          Tab(text: 'Account'),
        ],
      ),
    );
  }

  // ──────── WEB BODY ────────
  Widget _buildWebBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildVerificationTab(),
        _buildDocumentsTab(),
        _buildVoiceSamplesTab(),
        _buildQuizResultsTab(),
        _buildBadgesTab(),
        _buildAccountTab(),
      ],
    );
  }

  Widget _buildMobileBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildVerificationTab(),
        _buildDocumentsTab(),
        _buildVoiceSamplesTab(),
        _buildQuizResultsTab(),
        _buildBadgesTab(),
        _buildAccountTab(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: OVERVIEW
  // ═══════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats card
              AdminStatsCard(
                totalCalls: (_stats['total_calls'] as num?)?.toInt() ?? 0,
                totalDurationSeconds:
                    (_stats['total_duration_seconds'] as num?)?.toInt() ?? 0,
                averageRating:
                    (_stats['average_rating'] as num?)?.toDouble() ?? 0.0,
                totalFeedback: (_stats['total_feedback'] as num?)?.toInt() ?? 0,
              ),
              const SizedBox(height: 24),

              // Two columns on web
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 700) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildBasicInfoCard()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildExpertiseCard()),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildBasicInfoCard(),
                      const SizedBox(height: 24),
                      _buildExpertiseCard(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Quick status overview at bottom
              _buildQuickStatusRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatusRow() {
    final phoneNumber = _phoneVerification?['phone_number']?.toString().trim();
    final hasPhoneNumber = phoneNumber != null && phoneNumber.isNotEmpty;
    final hasGovId = _governmentIds.isNotEmpty;
    final govIdStatus = _normalizeGovIdStatus(
        hasGovId
            ? (_governmentIds.first['status']?.toString() ?? 'pending')
            : 'none',
      );
    final govIdReady = hasGovId && govIdStatus != 'rejected';
    final quizPassed = _quizAttempts.any((q) => q['passed'] == true);
    final hasFlaggedQuiz = _quizAttempts.any((q) => q['is_flagged'] == true);
    final hasVoiceSamples = _voiceSamples.isNotEmpty;
    final hasCerts = _certificates.isNotEmpty;
    final isVerified = _details['is_verified'] == true;

    return _buildSectionCard(
      'Onboarding Progress',
      Icons.checklist,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildProgressChip(
            'Phone Provided',
            hasPhoneNumber,
            hasPhoneNumber ? Icons.phone : Icons.phone_disabled,
          ),
          _buildProgressChip(
            'Gov ID: ${govIdStatus.toUpperCase()}',
            govIdReady,
            hasGovId ? Icons.badge : Icons.no_accounts,
            isError: govIdStatus == 'rejected',
          ),
          _buildProgressChip(
            'Quiz Passed',
            quizPassed,
            quizPassed ? Icons.school : Icons.quiz,
          ),
          if (hasFlaggedQuiz)
            _buildProgressChip(
              'Quiz Flagged',
              false,
              Icons.flag,
              isError: true,
            ),
          _buildProgressChip(
            'Voice Samples',
            hasVoiceSamples,
            hasVoiceSamples ? Icons.mic : Icons.mic_off,
          ),
          _buildProgressChip(
            'Certificates',
            hasCerts,
            hasCerts ? Icons.description : Icons.description_outlined,
          ),
          _buildProgressChip(
            'Verified',
            isVerified,
            isVerified ? Icons.verified : Icons.pending,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChip(
    String label,
    bool success,
    IconData icon, {
    bool warning = false,
    bool isError = false,
  }) {
    final Color color;
    if (isError) {
      color = Colors.red;
    } else if (warning) {
      color = Colors.orange;
    } else if (success) {
      color = const Color(0xFF10B981);
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildSectionCard(
      'Basic Information',
      Icons.person,
      child: Column(
        children: [
          _infoRow('User ID', _profile['user_id'], copyable: true),
          _infoRow('Username', _profile['username']),
          _infoRow('Email', _profile['email'] ?? 'Not available'),
          _infoRow('Role', _profile['role']),
          _infoRow('Gender', _profile['gender']),
          _infoRow('Country', _profile['country'] ?? 'Not set'),
          _infoRow(
            'Employment',
            (_details['employment_type'] ?? 'Not set').toString().toUpperCase(),
          ),
          _infoRow('Bio', _details['bio']),
          _infoRow('Experience', '${_details['years_experience'] ?? 0} years'),
          _infoRow(
            'Joined',
            _profile['created_at']?.toString().split('T')[0] ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildExpertiseCard() {
    return _buildSectionCard(
      'Expertise',
      Icons.school,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chipSection(
            'Languages',
            _languages,
            (e) => e['languages']?['name']?.toString() ?? '',
            Colors.blue,
          ),
          const Divider(height: 24),
          _chipSection(
            'Specializations',
            _specializations,
            (e) => e['specializations']?['name']?.toString() ?? '',
            Colors.purple,
          ),
          const Divider(height: 24),
          _chipSection(
            'Skills',
            _skills,
            (e) => e['skills']?['name']?.toString() ?? '',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _chipSection(
    String title,
    List items,
    String Function(dynamic) getName,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        items.isEmpty
            ? Text(
              'No $title',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            )
            : Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  items
                      .map(
                        (e) => Chip(
                          label: Text(
                            getName(e),
                            style: TextStyle(fontSize: 13, color: color),
                          ),
                          backgroundColor: color.withOpacity(0.08),
                          side: BorderSide(color: color.withOpacity(0.2)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
            ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: VERIFICATION
  // ═══════════════════════════════════════════════════════
  Widget _buildVerificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interpreter Verification
              _buildVerificationStatusCard(),
              const SizedBox(height: 24),

              // Phone Verification
              _buildPhoneVerificationCard(),
              const SizedBox(height: 24),

              // Government ID
              _buildGovernmentIdCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStatusCard() {
    final isVerified = _details['is_verified'] == true;

    return _buildSectionCard(
      'Interpreter Verification',
      Icons.verified_user,
      headerColor: isVerified ? const Color(0xFF10B981) : Colors.orange,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isVerified
                      ? const Color(0xFF10B981).withOpacity(0.06)
                      : Colors.orange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.warning_amber,
                  color: isVerified ? const Color(0xFF10B981) : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified
                            ? 'This interpreter is VERIFIED'
                            : 'This interpreter is NOT verified',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified
                            ? 'They can accept calls and appear in searches.'
                            : 'They cannot accept calls until verified by an admin.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (isVerified)
                  OutlinedButton.icon(
                    onPressed: () => _toggleVerification(false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Revoke'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _toggleVerification(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve & Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneVerificationCard() {
    final pv = _phoneVerification;
    final phoneVerified = pv?['verified'] == true;
    final hasPhone =
        (pv?['phone_number']?.toString().trim().isNotEmpty ?? false);

    return _buildSectionCard(
      'Phone Verification',
      Icons.phone_android,
      child:
          pv == null
              ? _emptyState(
                'No phone verification record found',
                Icons.phone_disabled,
              )
              : Column(
                children: [
                  _infoRow('Phone Number', pv['phone_number'] ?? 'N/A'),
                  _infoRow('Email', pv['email'] ?? 'N/A'),
                  _infoRow(
                    'Status',
                    phoneVerified
                        ? 'VERIFIED \u2713'
                        : (hasPhone ? 'RECORDED (OTP not required)' : 'NOT PROVIDED'),
                  ),
                  if (pv['verified_at'] != null)
                    _infoRow(
                      'Verified At',
                      pv['verified_at'].toString().split('T')[0],
                    ),
                ],
              ),
    );
  }

  Widget _buildGovernmentIdCard() {
    if (_governmentIds.isEmpty) {
      return _buildSectionCard(
        'Government ID',
        Icons.badge,
        child: _emptyState('No government ID uploaded', Icons.badge_outlined),
      );
    }

    return _buildSectionCard(
      'Government ID (${_governmentIds.length})',
      Icons.badge,
      child: Column(
        children:
            _governmentIds.map<Widget>((gid) {
              final status = _normalizeGovIdStatus(
                gid['status']?.toString() ?? 'pending',
              );
              final fileName = gid['file_name']?.toString() ?? 'document';
              final uploadedAt =
                  gid['uploaded_at']?.toString().split('T')[0] ?? '';
              final reviewerNotes = gid['reviewer_notes']?.toString();
              final fileUrl = gid['file_url']?.toString();

              Color statusColor;
              switch (status) {
                case 'approved':
                  statusColor = const Color(0xFF10B981);
                  break;
                case 'uploaded':
                  statusColor = const Color(0xFF2563EB);
                  break;
                case 'rejected':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.orange;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: statusColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Uploaded: $uploadedAt',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reviewerNotes != null && reviewerNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notes: $reviewerNotes',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (fileUrl != null && fileUrl.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _openGovernmentId(fileUrl),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('View Document'),
                          ),
                        const Spacer(),
                        // Status is read-only — shown as badge above
                        Text(
                          status == 'uploaded'
                            ? 'Document uploaded'
                            : status == 'approved'
                              ? 'Document verified'
                              : 'Document rejected',
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  String _normalizeGovIdStatus(String? status) {
    final normalized = (status ?? '').toLowerCase().trim();
    if (normalized == 'pending') return 'uploaded';
    if (normalized.isEmpty) return 'none';
    return normalized;
  }

  // ═══════════════════════════════════════════════════════
  // TAB: DOCUMENTS
  // ═══════════════════════════════════════════════════════
  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
              _certificates.isEmpty
                  ? _emptyState(
                    'No certificates uploaded',
                    Icons.description_outlined,
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certificates & Documents (${_certificates.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._certificates.map<Widget>(
                        (c) => _buildCertificateCard(c),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildCertificateCard(dynamic cert) {
    final status = (cert['status'] ?? '').toString();
    final verified = (cert['is_verified'] ?? false) == true;
    final fileName = (cert['file_name'] ?? '').toString();
    final type = (cert['certificate_type'] ?? '').toString();
    final uploadedAt = cert['uploaded_at']?.toString().split('T')[0] ?? '';
    final certId = cert['id']?.toString() ?? '';

    Color statusColor = Colors.grey;
    if (status == 'approved' || verified) statusColor = const Color(0xFF10B981);
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'pending') statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
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
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isEmpty ? '(certificate)' : fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Type: $type  •  Uploaded: $uploadedAt',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              verified ? 'VERIFIED' : status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _viewCertificate(certId),
            child: const Text('View'),
          ),
          if (status == 'pending' || (!verified && status != 'rejected')) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _approveCertificate(certId),
              icon: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
              tooltip: 'Approve',
            ),
            IconButton(
              onPressed: () => _rejectCertificate(certId),
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Reject',
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: VOICE SAMPLES
  // ═══════════════════════════════════════════════════════
  Widget _buildVoiceSamplesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
              _voiceSamples.isEmpty
                  ? _emptyState('No voice samples uploaded', Icons.mic_off)
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Samples (${_voiceSamples.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._voiceSamples.map<Widget>(
                        (v) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _WebVoiceSampleTile(voiceSample: v as Map),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: QUIZ RESULTS
  // ═══════════════════════════════════════════════════════
  Widget _buildQuizResultsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child:
              _quizAttempts.isEmpty
                  ? _emptyState('No quiz attempts yet', Icons.quiz)
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Quiz Attempts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ColorManager.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_quizAttempts.length}',
                              style: TextStyle(
                                color: ColorManager.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_quizAttempts.any((q) => q['is_flagged'] == true))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flag, size: 16, color: Colors.red),
                                  SizedBox(width: 6),
                                  Text(
                                    'Has Flagged Attempts',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._quizAttempts.map<Widget>(
                        (q) => _buildQuizAttemptCard(q),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildQuizAttemptCard(dynamic attempt) {
    final quizType = attempt['quiz_type']?.toString() ?? 'Unknown';
    final section = attempt['medical_section']?.toString();
    final score = attempt['score_percentage']?.toString() ?? '0';
    final passed = attempt['passed'] == true;
    final takenAt = attempt['taken_at']?.toString().split('T')[0] ?? '';
    final totalQ = attempt['total_questions']?.toString() ?? '0';
    final correctA = attempt['correct_answers']?.toString() ?? '0';
    final timeTaken = attempt['time_taken_seconds'];

    // Anti-cheat fields
    final tabSwitches = (attempt['tab_switches'] as num?)?.toInt() ?? 0;
    final copyPaste = (attempt['copy_paste_attempts'] as num?)?.toInt() ?? 0;
    final screenshots = (attempt['screenshot_attempts'] as num?)?.toInt() ?? 0;
    final isFlagged = attempt['is_flagged'] == true;
    final sessionStart = attempt['session_start_at']?.toString();
    final sessionEnd = attempt['session_end_at']?.toString();
    final browserInfo = attempt['browser_info']?.toString();

    String title =
        quizType == 'medical' && section != null
            ? 'Medical - ${section.replaceAll('_', ' ').toUpperCase()}'
            : quizType.toUpperCase();

    final hasAntiCheatData =
        tabSwitches > 0 || copyPaste > 0 || screenshots > 0 || isFlagged;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            isFlagged
                ? Border.all(color: Colors.red.withOpacity(0.4), width: 2)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isFlagged
                      ? Colors.red.withOpacity(0.04)
                      : passed
                      ? const Color(0xFF10B981).withOpacity(0.04)
                      : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? const Color(0xFF10B981) : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Taken: $takenAt',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isFlagged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'FLAGGED',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        passed
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    passed ? 'PASSED' : 'FAILED',
                    style: TextStyle(
                      color: passed ? const Color(0xFF10B981) : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Score details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildQuizStat(
                      'Score',
                      '$correctA/$totalQ ($score%)',
                      Icons.score,
                      Colors.blue,
                    ),
                    const SizedBox(width: 24),
                    if (timeTaken != null)
                      _buildQuizStat(
                        'Time',
                        _formatQuizTime(timeTaken),
                        Icons.timer,
                        Colors.purple,
                      ),
                  ],
                ),

                // Anti-cheat section
                if (hasAntiCheatData ||
                    sessionStart != null ||
                    browserInfo != null) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Anti-Cheat Monitor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isFlagged ? Colors.red : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _buildAntiCheatStat(
                        'Tab Switches',
                        tabSwitches.toString(),
                        Icons.tab,
                        tabSwitches > 2
                            ? Colors.red
                            : tabSwitches > 0
                            ? Colors.orange
                            : const Color(0xFF10B981),
                      ),
                      _buildAntiCheatStat(
                        'Copy/Paste',
                        copyPaste.toString(),
                        Icons.content_copy,
                        copyPaste > 0 ? Colors.red : const Color(0xFF10B981),
                      ),
                      _buildAntiCheatStat(
                        'Screenshots',
                        screenshots.toString(),
                        Icons.screenshot,
                        screenshots > 0 ? Colors.red : const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  if (sessionStart != null || sessionEnd != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Session: ${_formatDateTime(sessionStart)} → ${_formatDateTime(sessionEnd)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (browserInfo != null && browserInfo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.devices,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Browser: $browserInfo',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAntiCheatStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: BADGES
  // ═══════════════════════════════════════════════════════
  Widget _buildBadgesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
              _badges.isEmpty
                  ? _emptyState(
                    'No badges earned yet',
                    Icons.emoji_events_outlined,
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earned Badges (${_badges.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children:
                            _badges.map<Widget>((badge) {
                              final badgeName =
                                  badge['badge']?.toString() ?? 'Unknown';
                              final score = badge['score']?.toString() ?? '0';
                              final earnedAt =
                                  badge['earned_at']?.toString().split(
                                    'T',
                                  )[0] ??
                                  '';

                              return Container(
                                width: 200,
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
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      size: 40,
                                      color: Colors.amber.shade600,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      badgeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '$score%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: ColorManager.primary,
                                      ),
                                    ),
                                    Text(
                                      earnedAt,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: ACCOUNT ACTIONS
  // ═══════════════════════════════════════════════════════
  Widget _buildAccountTab() {
    final isSuspended = _details['is_suspended'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Account Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              _buildActionCard(
                icon: Icons.edit,
                title: 'Edit Profile',
                description: 'Update username, bio, and experience',
                color: Colors.blue,
                onTap: () => _showEditProfileDialog(),
              ),
              const SizedBox(height: 12),

              _buildActionCard(
                icon: isSuspended ? Icons.check_circle : Icons.block,
                title: isSuspended ? 'Activate Account' : 'Suspend Account',
                description:
                    isSuspended
                        ? 'Reactivate this interpreter\'s account'
                        : 'Temporarily disable this interpreter\'s account',
                color: isSuspended ? const Color(0xFF10B981) : Colors.orange,
                onTap: () => _toggleSuspend(isSuspended),
              ),
              const SizedBox(height: 12),

              _buildActionCard(
                icon: Icons.lock_reset,
                title: 'Reset Password',
                description:
                    'Send a password reset email to ${_profile['email'] ?? 'this user'}',
                color: Colors.purple,
                onTap: () => _resetPassword(),
              ),
              const SizedBox(height: 24),

              // Delete — destructive action separated
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Danger Zone',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Deleting this account is permanent and cannot be undone.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showDeleteDialog(),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete Account Permanently'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
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
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════
  Widget _buildSectionCard(
    String title,
    IconData icon, {
    required Widget child,
    Color? headerColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: headerColor ?? ColorManager.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, {bool copyable = false}) {
    final text = value?.toString() ?? '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (copyable && text != '-') ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════
  Future<void> _toggleVerification(bool verify) async {
    if (!verify) {
      final confirm = await _showConfirmation(
        'Revoke Verification',
        'Are you sure you want to revoke verification? They will lose their verified badge.',
        confirmLabel: 'Revoke',
        confirmColor: Colors.red,
      );
      if (confirm != true) return;
    }

    try {
      final cleanupWarning = await _service.setInterpreterVerification(
        widget.userId,
        verified: verify,
      );
      String? emailWarning;

      // Send verification email when approving
      if (verify) {
        final email = _profile['email']?.toString();
        final name = _profile['username']?.toString() ?? 'Interpreter';
        try {
          await _service.sendVerificationEmail(
            userId: widget.userId,
            to: email,
            interpreterName: name,
          );
        } catch (e) {
          emailWarning = 'Interpreter verified, but email was not sent: $e';
        }
      }

      _snack(
        verify ? 'Interpreter verified' : 'Verification revoked',
        color: verify ? const Color(0xFF10B981) : Colors.orange,
      );

      if (cleanupWarning != null) {
        _snack(cleanupWarning, color: Colors.orange);
      }

      if (emailWarning != null) {
        _snack(emailWarning, color: Colors.orange);
      }

      _load();
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    }
  }

  /// Opens a government ID document URL in an external browser.
  /// Tries to get a fresh signed URL first so the link never expires.
  Future<void> _openGovernmentId(String fileUrl) async {
    try {
      final signedUrl = await _service.getFreshCertificateUrl(url: fileUrl);
      final url = signedUrl ?? fileUrl;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Cannot open document URL', color: Colors.red);
      }
    } catch (e) {
      _snack('Error opening document: $e', color: Colors.red);
    }
  }

  Future<void> _viewCertificate(String certId) async {
    try {
      final url = await _service.getFreshCertificateUrl(certificateId: certId);
      if (url == null) throw Exception('No URL');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('Failed to open: $e', color: Colors.red);
    }
  }

  Future<void> _approveCertificate(String certId) async {
    try {
      await _service.approveCertificate(certId);
      _snack('Certificate approved', color: const Color(0xFF10B981));
      _load();
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    }
  }

  Future<void> _rejectCertificate(String certId) async {
    final note = await _showTextInputDialog(
      'Reject Certificate',
      'Optional: reason for rejection',
    );
    try {
      await _service.rejectCertificate(certId, note: note);
      _snack('Certificate rejected', color: Colors.orange);
      _load();
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    }
  }

  Future<void> _showEditProfileDialog() async {
    final bioCtrl = TextEditingController(text: _details['bio']?.toString());
    final expCtrl = TextEditingController(
      text: _details['years_experience']?.toString() ?? '0',
    );
    final usernameCtrl = TextEditingController(
      text: _profile['username']?.toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Profile'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Years of Experience',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.functions.invoke(
          'admin-update-profile',
          headers: const {'x-portal-context': 'admin'},
          body: {
            'user_id': widget.userId,
            'username': usernameCtrl.text,
            'bio': bioCtrl.text,
            'years_experience': int.tryParse(expCtrl.text) ?? 0,
          },
        );
        _snack('Profile updated', color: const Color(0xFF10B981));
        _load();
      } catch (e) {
        _snack('Error: $e', color: Colors.red);
      }
    }
  }

  Future<void> _toggleSuspend(bool currentlySuspended) async {
    final action = currentlySuspended ? 'activate' : 'suspend';
    final confirmed = await _showConfirmation(
      '${action[0].toUpperCase()}${action.substring(1)} Account',
      'Are you sure you want to $action this account?',
      confirmLabel: action[0].toUpperCase() + action.substring(1),
      confirmColor:
          currentlySuspended ? const Color(0xFF10B981) : Colors.orange,
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.functions.invoke(
          'admin-suspend-account',
          headers: const {'x-portal-context': 'admin'},
          body: {'user_id': widget.userId, 'suspend': !currentlySuspended},
        );
        _snack(
          'Account ${currentlySuspended ? "activated" : "suspended"}',
          color: const Color(0xFF10B981),
        );
        _load();
      } catch (e) {
        _snack('Error: $e', color: Colors.red);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _profile['email']?.toString();
    if (email == null || email.isEmpty) {
      _snack('Email not available', color: Colors.red);
      return;
    }

    final confirmed = await _showConfirmation(
      'Reset Password',
      'Send password reset email to $email?',
      confirmLabel: 'Send',
    );

    if (confirmed == true) {
      try {
        await SupabaseService().sendPasswordResetEmail(
          email: email,
          portalHint: 'interpreter',
        );
        _snack('Password reset email sent', color: const Color(0xFF10B981));
      } catch (e) {
        _snack('Error: $e', color: Colors.red);
      }
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is PERMANENT and cannot be undone!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete account for: ${_profile['username'] ?? "Unknown"}?',
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will delete:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• User profile'),
                const Text('• Interpreter details'),
                const Text('• All certificates'),
                const Text('• All languages, skills, and specializations'),
                const Text('• Call history and records'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('DELETE PERMANENTLY'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.functions.invoke(
          'admin-delete-account',
          headers: const {'x-portal-context': 'admin'},
          body: {'user_id': widget.userId},
        );
        _snack('Account deleted', color: const Color(0xFF10B981));
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        _snack('Error: $e', color: Colors.red);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════
  Future<bool?> _showConfirmation(
    String title,
    String message, {
    String confirmLabel = 'Confirm',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor ?? ColorManager.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }

  Future<String?> _showTextInputDialog(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _formatQuizTime(dynamic seconds) {
    if (seconds == null) return '-';
    final sec = (seconds as num).toInt();
    if (sec < 60) return '${sec}s';
    final min = sec ~/ 60;
    final rem = sec % 60;
    return '${min}m ${rem}s';
  }

  String _formatDateTime(String? dt) {
    if (dt == null || dt.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(dt);
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
          '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt.split('T')[0];
    }
  }
}

// ═══════════════════════════════════════════════════════
// VOICE SAMPLE TILE (Self-contained with audio player)
// ═══════════════════════════════════════════════════════
class _WebVoiceSampleTile extends StatefulWidget {
  final Map voiceSample;
  const _WebVoiceSampleTile({required this.voiceSample});

  @override
  State<_WebVoiceSampleTile> createState() => _WebVoiceSampleTileState();
}

class _WebVoiceSampleTileState extends State<_WebVoiceSampleTile> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerComplSub;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _playerComplSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _playerComplSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isLoading) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = widget.voiceSample['url'] as String?;
      if (url == null || url.isEmpty) throw Exception('No URL');
      final mimeType = _guessMimeType(url);
      await _audioPlayer.play(UrlSource(url, mimeType: mimeType));
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String? _guessMimeType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.webm')) return 'audio/webm';
    if (lower.contains('.m4a')) return 'audio/mp4';
    if (lower.contains('.mp3')) return 'audio/mpeg';
    if (lower.contains('.wav')) return 'audio/wav';
    if (lower.contains('.aac')) return 'audio/aac';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sentenceTypeRaw = widget.voiceSample['sentence_type']?.toString() ?? '';
    final prompt = widget.voiceSample['prompt']?.toString() ?? '';
    final createdAt = widget.voiceSample['created_at']?.toString().split('T')[0] ?? '';

    String displayName = 'Voice Sample';
    if (sentenceTypeRaw.isNotEmpty) {
      displayName = sentenceTypeRaw[0].toUpperCase() + 
          sentenceTypeRaw.substring(1).replaceAll('_', ' ');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    _isLoading
                        ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : IconButton(
                          onPressed: _toggle,
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle : Icons.play_circle,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded: $createdAt',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.mic, color: Colors.blue),
            ],
          ),
          if (prompt.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reference Question/Prompt:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
