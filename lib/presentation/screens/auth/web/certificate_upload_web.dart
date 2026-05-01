import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Professional web certificate upload screen for interpreter onboarding
class CertificateUploadWebScreen extends StatefulWidget {
  const CertificateUploadWebScreen({super.key});

  @override
  State<CertificateUploadWebScreen> createState() =>
      _CertificateUploadWebScreenState();
}

class _CertificateUploadWebScreenState
    extends State<CertificateUploadWebScreen> {
      @override
void initState() {
  super.initState();
  
  // Add this block to catch browser refreshes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) {
      // The user refreshed the page and lost their session arguments.
      // Send them to the dashboard gate, which will re-fetch their progress
      // from Supabase and route them back here with the correct args!
      Navigator.of(context).pushReplacementNamed(Routes.interpreterPortalDashboardRoute);
    }
  });
}
  PlatformFile? _trainingCertificate;
  PlatformFile? _medicalCertificate;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _yearsController = TextEditingController();
  bool _isSaving = false;
  @override
  void dispose() {
    _bioController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({required bool isMedical}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: kIsWeb, // Load bytes on web
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          if (isMedical) {
            _medicalCertificate = result.files.first;
          } else {
            _trainingCertificate = result.files.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _continue() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final isPaid = _isPaidTrack(args);

    if (_trainingCertificate == null) return;

    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      if (userId == null) throw Exception("User not logged in");

      // Upload Training Certificate
      if (_trainingCertificate!.bytes != null) {
        final path =
            '$userId/training_${DateTime.now().millisecondsSinceEpoch}_${_trainingCertificate!.name}';
        await Supabase.instance.client.storage
            .from('interpreter_certificates')
            .uploadBinary(path, _trainingCertificate!.bytes!);
        final url = Supabase.instance.client.storage
            .from('interpreter_certificates')
            .getPublicUrl(path);

        await Supabase.instance.client.from('interpreter_certificates').insert({
          'user_id': userId,
          'url': url,
          'storage_path': path,
          'file_name': _trainingCertificate!.name,
          'file_size': _trainingCertificate!.size,
          'certificate_type': 'training',
        });
      }

      // Upload Medical Certificate
      if (isPaid &&
          _medicalCertificate != null &&
          _medicalCertificate!.bytes != null) {
        final path =
            '$userId/medical_${DateTime.now().millisecondsSinceEpoch}_${_medicalCertificate!.name}';
        await Supabase.instance.client.storage
            .from('interpreter_certificates')
            .uploadBinary(path, _medicalCertificate!.bytes!);
        final url = Supabase.instance.client.storage
            .from('interpreter_certificates')
            .getPublicUrl(path);

        await Supabase.instance.client.from('interpreter_certificates').insert({
          'user_id': userId,
          'url': url,
          'storage_path': path,
          'file_name': _medicalCertificate!.name,
          'file_size': _medicalCertificate!.size,
          'certificate_type': 'medical',
        });
      }

      final bio = _bioController.text.trim();
      final years = int.tryParse(_yearsController.text.trim());

      final updateData = <String, dynamic>{
        // Certificates are submitted; quiz completion is still required.
        'onboarding_status': 'document_uploaded',
      };
      if (bio.isNotEmpty) updateData['bio'] = bio;
      if (years != null) updateData['years_experience'] = years;

      await Supabase.instance.client
          .from('interpreter_details')
          .update(updateData)
          .eq('user_id', userId);

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.interpreterQuizHubRoute,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to upload certificates: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final isPaid = _isPaidTrack(args);
    final fullScreenResume = args['authContinuationFullScreen'] == true;

    return AuthWebWrapper(
      fullScreen: fullScreenResume,
      title: isPaid ? 'Certification' : 'Training certificate',
      subtitle:
          isPaid
              ? 'Upload your medical interpreter credentials'
              : 'Upload any relevant training certificates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(9, 9),
          const SizedBox(height: 24),

          // Training certificate
          _buildUploadCard(
            title: isPaid ? 'Training certificate' : 'Certificate (required)',
            description:
                'PDF, JPG, or PNG (max 5MB). Accredited coursework, ATA/ACTFL exams, or college transcripts.',
            file: _trainingCertificate,
            onPick: () => _pickFile(isMedical: false),
          ),

          if (isPaid) ...[
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'Medical credential (Optional)',
              description: 'National medical interpreter certificate\nCHI/CMI.',
              file: _medicalCertificate,
              onPick: () => _pickFile(isMedical: true),
            ),
            const SizedBox(height: 24),

            // Professional details
             const Text(
              'Professional details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _bioController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText:
                      'Tell us about your medical interpreting experience...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _yearsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Years of experience (e.g. 5)',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(
                    Icons.work_outline,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _canContinue(isPaid) && !_isSaving ? _continue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Text(
                        isPaid ? 'Continue to registration' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String description,
    required PlatformFile? file,
    required VoidCallback onPick,
  }) {
    final hasFile = file != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasFile
                ? Icons.check_circle_outline_rounded
                : Icons.cloud_upload_outlined,
            size: 36,
            color: hasFile ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            hasFile ? file.name : title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  hasFile ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hasFile
                ? '${(file.size / 1024).toStringAsFixed(1)} KB'
                : description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: onPick,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(
                hasFile ? 'Change file' : 'Select file',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canContinue(bool isPaid) {
    return _trainingCertificate != null;
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCurrent
                      ? const Color(0xFF3B82F6)
                      : isActive
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

bool _isPaidTrack(Map<String, dynamic> args) {
  final trackValue =
      args['track'] ??
      args['interpreterTrack'] ??
      args['interpreterLevel'] ??
      args['interpreter_level'];
  if (trackValue is String) {
    final normalized = trackValue.toLowerCase();
    if (normalized.contains('paid') || normalized.contains('pro')) return true;
  }
  if (args['requiresMedicalDocs'] == true) return true;
  return false;
}
