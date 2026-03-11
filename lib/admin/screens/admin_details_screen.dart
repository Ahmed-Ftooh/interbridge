import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:interbridge/admin/services/admin_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:interbridge/admin/widgets/admin_stats_card.dart';
import 'package:interbridge/admin/widgets/certificate_tile.dart';
import 'package:interbridge/admin/widgets/verification_section.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDetailsScreen extends StatelessWidget {
  final String userId;
  const AdminDetailsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(
        onGenerateRoute:
            (settings) => MaterialPageRoute(
              builder: (_) => _AdminDetailsLoader(userId: userId),
            ),
      ),
    );
  }
}

class _AdminDetailsLoader extends StatefulWidget {
  final String userId;
  const _AdminDetailsLoader({required this.userId});

  @override
  State<_AdminDetailsLoader> createState() => _AdminDetailsLoaderState();
}

class _AdminDetailsLoaderState extends State<_AdminDetailsLoader> {
  final _service = AdminService();
  final _callService = instance<CallService>();

  Future<Map<String, dynamic>>? _future;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = Future.wait([
        _service.getInterpreterDetails(widget.userId),
        _callService.getCallStatistics(userId: widget.userId),
        _callService.getFeedbackStatistics(userId: widget.userId),
      ]).then((results) {
        final details = results[0];
        final callStats = results[1];
        final feedbackStats = results[2];

        _stats = {...callStats, ...feedbackStats};

        return details;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        final data = snapshot.data ?? {};
        final profile = (data['profile'] ?? {}) as Map;
        final details = (data['details'] ?? {}) as Map;
        final languages = (data['languages'] ?? []) as List;
        final skills = (data['skills'] ?? []) as List;
        final specializations = (data['specializations'] ?? []) as List;
        final certificates = (data['certificates'] ?? []) as List;
        final voiceSamples = (data['voiceSamples'] ?? []) as List;
        final quizAttempts = (data['quizAttempts'] ?? []) as List;
        final badges = (data['badges'] ?? []) as List;
        final governmentIds = (data['governmentIds'] ?? []) as List;
        final phoneVerification = data['phoneVerification'] as Map?;

        // Debug: Print voice samples data
        debugPrint('Voice Samples received: ${voiceSamples.length} items');
        if (voiceSamples.isNotEmpty) {
          debugPrint('First voice sample: ${voiceSamples.first}');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(profile['username']?.toString() ?? 'Details'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => _load(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Indicators
                  Row(
                    children: [
                      if (details['is_suspended'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block, size: 16, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                'SUSPENDED',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats Card
                  AdminStatsCard(
                    totalCalls: (_stats['total_calls'] as num?)?.toInt() ?? 0,
                    totalDurationSeconds:
                        (_stats['total_duration_seconds'] as num?)?.toInt() ??
                        0,
                    averageRating:
                        (_stats['average_rating'] as num?)?.toDouble() ?? 0.0,
                    totalFeedback:
                        (_stats['total_feedback'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(height: 16),

                  VerificationSection(
                    userId: widget.userId,
                    details: details,
                    onChanged: _load,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Basic Info'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow('User ID', profile['user_id']),
                          _buildInfoRow('Username', profile['username']),
                          _buildInfoRow('Role', profile['role']),
                          _buildInfoRow(
                            'Email',
                            profile['email'] ?? 'Not available',
                          ),
                          _buildInfoRow('Gender', profile['gender']),
                          _buildInfoRow(
                            'Country',
                            profile['country'] ?? 'Not set',
                          ),
                          _buildInfoRow(
                            'Employment Type',
                            (details['employment_type'] ?? 'Not set')
                                .toString()
                                .toUpperCase(),
                          ),
                          _buildInfoRow('Bio', details['bio']),
                          _buildInfoRow(
                            'Experience',
                            '${details['years_experience'] ?? 0} years',
                          ),
                          _buildInfoRow(
                            'Created At',
                            profile['created_at']?.toString().split('T')[0] ??
                                '-',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Expertise'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Languages',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                languages.isEmpty
                                    ? [const Text('No languages')]
                                    : languages
                                        .map(
                                          (e) => Chip(
                                            label: Text(
                                              e['languages']?['name']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                            backgroundColor:
                                                Colors.blue.shade50,
                                          ),
                                        )
                                        .toList(),
                          ),
                          const Divider(height: 24),
                          const Text(
                            'Specializations',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                specializations.isEmpty
                                    ? [const Text('No specializations')]
                                    : specializations
                                        .map(
                                          (e) => Chip(
                                            label: Text(
                                              e['specializations']?['name']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                            backgroundColor:
                                                Colors.purple.shade50,
                                          ),
                                        )
                                        .toList(),
                          ),
                          const Divider(height: 24),
                          const Text(
                            'Skills',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                skills.isEmpty
                                    ? [const Text('No skills')]
                                    : skills
                                        .map(
                                          (e) => Chip(
                                            label: Text(
                                              e['skills']?['name']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                            backgroundColor:
                                                Colors.orange.shade50,
                                          ),
                                        )
                                        .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    context,
                    'Voice Samples (${voiceSamples.length})',
                  ),
                  if (voiceSamples.isNotEmpty)
                    ...voiceSamples.map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _VoiceSampleTile(
                          voiceSample: v as Map,
                          service: _service,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No voice samples uploaded',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Documents'),
                  if (certificates.isNotEmpty)
                    ...certificates.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: CertificateTile(
                          cert: c,
                          service: _service,
                          onChanged: _load,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No certificates uploaded',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Phone Verification Section
                  _buildSectionTitle(context, 'Phone Verification'),
                  if (phoneVerification != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              phoneVerification['verified'] == true
                                  ? Icons.verified
                                  : Icons.phone_android,
                              color:
                                  phoneVerification['verified'] == true
                                      ? Colors.green
                                      : Colors.orange,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    phoneVerification['phone_number']
                                            ?.toString() ??
                                        'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (phoneVerification['verified'] == true &&
                                      phoneVerification['verified_at'] != null)
                                    Text(
                                      'Verified on ${phoneVerification['verified_at'].toString().split('T')[0]}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    phoneVerification['verified'] == true
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      phoneVerification['verified'] == true
                                          ? Colors.green
                                          : Colors.orange,
                                ),
                              ),
                              child: Text(
                                phoneVerification['verified'] == true
                                    ? 'VERIFIED'
                                    : 'UNVERIFIED',
                                style: TextStyle(
                                  color:
                                      phoneVerification['verified'] == true
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No phone verification data',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Government IDs Section
                  _buildSectionTitle(
                    context,
                    'Government IDs (${governmentIds.length})',
                  ),
                  if (governmentIds.isNotEmpty)
                    ...governmentIds.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _GovernmentIdTile(
                          govId: g as Map,
                          service: _service,
                          onChanged: _load,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No government IDs uploaded',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Badges Section
                  _buildSectionTitle(context, 'Earned Badges'),
                  if (badges.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              badges.map((badge) {
                                final badgeName =
                                    badge['badge']?.toString() ?? 'Unknown';
                                final score = badge['score']?.toString() ?? '0';
                                return Chip(
                                  avatar: const Icon(
                                    Icons.verified,
                                    size: 18,
                                    color: Colors.amber,
                                  ),
                                  label: Text('$badgeName ($score%)'),
                                  backgroundColor: Colors.amber.shade50,
                                );
                              }).toList(),
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No badges earned yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Quiz Results Section
                  _buildSectionTitle(context, 'Quiz Results'),
                  if (quizAttempts.isNotEmpty)
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: quizAttempts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final attempt = quizAttempts[index];
                          final quizType =
                              attempt['quiz_type']?.toString() ?? 'Unknown';
                          final section =
                              attempt['medical_section']?.toString();
                          final score =
                              attempt['score_percentage']?.toString() ?? '0';
                          final passed = attempt['passed'] == true;
                          final takenAt =
                              attempt['taken_at']?.toString().split('T')[0] ??
                              '';
                          final totalQ =
                              attempt['total_questions']?.toString() ?? '0';
                          final correctA =
                              attempt['correct_answers']?.toString() ?? '0';

                          String title =
                              quizType == 'medical' && section != null
                                  ? 'Medical - ${section.replaceAll('_', ' ').toUpperCase()}'
                                  : quizType.toUpperCase();

                          return ListTile(
                            leading: Icon(
                              passed ? Icons.check_circle : Icons.cancel,
                              color: passed ? Colors.green : Colors.red,
                            ),
                            title: Text(title),
                            subtitle: Text(
                              'Score: $correctA/$totalQ ($score%) • $takenAt',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    passed
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                passed ? 'PASSED' : 'FAILED',
                                style: TextStyle(
                                  color:
                                      passed
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No quiz attempts yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Account Actions'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            onPressed:
                                () => _showEditProfileDialog(
                                  context,
                                  widget.userId,
                                  details,
                                  profile,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: Icon(
                              details['is_suspended'] == true
                                  ? Icons.check_circle
                                  : Icons.block,
                            ),
                            label: Text(
                              details['is_suspended'] == true
                                  ? 'Activate Account'
                                  : 'Suspend Account',
                            ),
                            onPressed:
                                () => _toggleSuspendAccount(
                                  context,
                                  widget.userId,
                                  details['is_suspended'] == true,
                                ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  details['is_suspended'] == true
                                      ? Colors.green
                                      : Colors.orange,
                              side: BorderSide(
                                color:
                                    details['is_suspended'] == true
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Reset Password'),
                            onPressed:
                                () => _resetPassword(context, profile['email']),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Delete Account'),
                            onPressed:
                                () => _showDeleteAccountDialog(
                                  context,
                                  widget.userId,
                                  profile['username'],
                                ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to List'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    String userId,
    Map details,
    Map profile,
  ) async {
    final bioController = TextEditingController(text: details['bio']);
    final experienceController = TextEditingController(
      text: details['years_experience']?.toString() ?? '0',
    );
    final usernameController = TextEditingController(text: profile['username']);

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: experienceController,
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await Supabase.instance.client.functions.invoke(
                      'admin-update-profile',
                      body: {
                        'user_id': userId,
                        'username': usernameController.text,
                        'bio': bioController.text,
                        'years_experience':
                            int.tryParse(experienceController.text) ?? 0,
                      },
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _load();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _toggleSuspendAccount(
    BuildContext context,
    String userId,
    bool currentlySuspended,
  ) async {
    final action = currentlySuspended ? 'activate' : 'suspend';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '${action[0].toUpperCase()}${action.substring(1)} Account',
            ),
            content: Text('Are you sure you want to $action this account?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      currentlySuspended ? Colors.green : Colors.orange,
                ),
                child: Text(action[0].toUpperCase() + action.substring(1)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.functions.invoke(
          'admin-suspend-account',
          body: {'user_id': userId, 'suspend': !currentlySuspended},
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account ${currentlySuspended ? "activated" : "suspended"} successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _load();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _resetPassword(BuildContext context, String? email) async {
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not available for this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: Text('Send password reset email to $email?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(email);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    String userId,
    String? username,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
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
                Text('Delete account for: ${username ?? "Unknown"}?'),
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
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
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
          body: {'user_id': userId},
        );

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _VoiceSampleTile extends StatefulWidget {
  final Map voiceSample;
  final AdminService service;

  const _VoiceSampleTile({required this.voiceSample, required this.service});

  @override
  State<_VoiceSampleTile> createState() => _VoiceSampleTileState();
}

class _VoiceSampleTileState extends State<_VoiceSampleTile> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isLoading) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = widget.voiceSample['url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('No audio URL available');
      }

      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The filename format is: {date}_{sentenceType}_{prompt}_{timestamp}.m4a
    final fileName = widget.voiceSample['name']?.toString() ?? '';
    final createdAt =
        widget.voiceSample['created_at']?.toString().split('T')[0] ?? '';

    // Parse a readable name from filename
    String displayName = 'Voice Sample';
    if (fileName.isNotEmpty) {
      // Remove extension and parse
      final nameWithoutExt = fileName
          .replaceAll('.m4a', '')
          .replaceAll('.mp3', '');
      final parts = nameWithoutExt.split('_');
      if (parts.length >= 2) {
        // Try to get the sentence type (second part usually)
        final sentenceType =
            parts.length > 1 ? parts[1].replaceAll('_', ' ') : '';
        displayName =
            sentenceType.isNotEmpty
                ? sentenceType[0].toUpperCase() +
                    sentenceType.substring(1).replaceAll('_', ' ')
                : 'Voice Sample';
      }
    }

    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
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
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.blue,
                      size: 32,
                    ),
                  ),
        ),
        title: Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Uploaded: $createdAt',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Icon(Icons.mic, color: Colors.blue.shade300),
      ),
    );
  }
}

class _GovernmentIdTile extends StatefulWidget {
  final Map govId;
  final AdminService service;
  final VoidCallback onChanged;

  const _GovernmentIdTile({
    required this.govId,
    required this.service,
    required this.onChanged,
  });

  @override
  State<_GovernmentIdTile> createState() => _GovernmentIdTileState();
}

class _GovernmentIdTileState extends State<_GovernmentIdTile> {
  bool _busy = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _view() async {
    final url = widget.govId['file_url']?.toString();
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No file URL available')));
      }
      return;
    }
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _updateStatus(String status) async {
    final id = widget.govId['id']?.toString();
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await widget.service.updateGovernmentIdStatus(id, status: status);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.govId['status'] ?? 'pending').toString();
    final fileName = (widget.govId['file_name'] ?? '').toString();
    final uploadedAt =
        widget.govId['uploaded_at']?.toString().split('T')[0] ?? '';
    final reviewerNotes = widget.govId['reviewer_notes']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName.isEmpty ? 'Government ID' : fileName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (uploadedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Uploaded: $uploadedAt',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            if (reviewerNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Notes: $reviewerNotes',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _view,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (status != 'approved')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _updateStatus('approved'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                const SizedBox(width: 8),
                if (status != 'rejected')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _updateStatus('rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
