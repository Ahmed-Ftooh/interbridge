import 'package:flutter/material.dart';
import 'package:interbridge/admin/services/admin_service.dart';

class VerificationSection extends StatefulWidget {
  final String userId;
  final Map details;
  final String? interpreterEmail;
  final String? interpreterName;
  final VoidCallback onChanged;

  const VerificationSection({
    super.key,
    required this.userId,
    required this.details,
    this.interpreterEmail,
    this.interpreterName,
    required this.onChanged,
  });

  @override
  State<VerificationSection> createState() => _VerificationSectionState();
}

class _VerificationSectionState extends State<VerificationSection> {
  bool _busy = false;
  final _service = AdminService();

  Future<void> _toggle(bool value) async {
    // If rejecting, ask for confirmation
    if (!value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Revoke Verification'),
              content: const Text(
                'Are you sure you want to revoke verification for this interpreter? They will lose their verified badge.',
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
                  child: const Text('Revoke'),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    setState(() => _busy = true);
    try {
      await _service.setInterpreterVerification(widget.userId, verified: value);
      String? emailWarning;

      if (value) {
        final email = widget.interpreterEmail?.trim();
        try {
          await _service.sendVerificationEmail(
            userId: widget.userId,
            to: email,
            interpreterName:
                (widget.interpreterName?.trim().isNotEmpty ?? false)
                    ? widget.interpreterName!.trim()
                    : 'Interpreter',
          );
        } catch (e) {
          emailWarning = 'Interpreter verified, but email was not sent: $e';
        }
      }

      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Interpreter verified' : 'Verification revoked',
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
          ),
        );

        if (emailWarning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emailWarning),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = (widget.details['is_verified'] ?? false) == true;
    return Card(
      color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.warning_amber,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isVerified
                        ? 'This interpreter is VERIFIED'
                        : 'This interpreter is NOT verified',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isVerified)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _toggle(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Revoke Verification'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _toggle(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve & Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
