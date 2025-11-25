import 'package:flutter/material.dart';
import 'package:interbridge/admin/services/admin_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificateTile extends StatefulWidget {
  final Map cert;
  final AdminService service;
  final VoidCallback onChanged;
  const CertificateTile({
    super.key,
    required this.cert,
    required this.service,
    required this.onChanged,
  });

  @override
  State<CertificateTile> createState() => _CertificateTileState();
}

class _CertificateTileState extends State<CertificateTile> {
  bool _busy = false;

  Future<void> _view() async {
    setState(() => _busy = true);
    try {
      final id = widget.cert['id']?.toString();
      final url = await widget.service.getFreshCertificateUrl(
        certificateId: id,
      );
      if (url == null) throw Exception('No URL');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opening certificate...')));
      }
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.cert['status'] ?? '').toString();
    final verified = (widget.cert['is_verified'] ?? false) == true;
    final fileName = (widget.cert['file_name'] ?? '').toString();
    final type = (widget.cert['certificate_type'] ?? '').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName.isEmpty ? '(certificate)' : fileName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Type: $type • Status: $status • Verified: $verified'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _view,
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MainCertificateTile extends StatefulWidget {
  final String url;
  final AdminService service;
  const MainCertificateTile({
    super.key,
    required this.url,
    required this.service,
  });

  @override
  State<MainCertificateTile> createState() => _MainCertificateTileState();
}

class _MainCertificateTileState extends State<MainCertificateTile> {
  bool _busy = false;

  Future<void> _view() async {
    setState(() => _busy = true);
    try {
      final signedUrl = await widget.service.getFreshCertificateUrl(
        url: widget.url,
      );
      if (signedUrl == null) throw Exception('Could not sign URL');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opening certificate...')));
      }
      final uri = Uri.parse(signedUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.file_present),
        title: const Text('Onboarding Certificate'),
        subtitle: Text(widget.url.split('/').last),
        trailing: ElevatedButton(
          onPressed: _busy ? null : _view,
          child: const Text('View'),
        ),
      ),
    );
  }
}
