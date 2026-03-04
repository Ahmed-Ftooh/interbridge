import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';

class CertificateUploadScreen extends StatefulWidget {
  const CertificateUploadScreen({super.key});

  @override
  State<CertificateUploadScreen> createState() =>
      _CertificateUploadScreenState();
}

class _CertificateUploadScreenState extends State<CertificateUploadScreen> {
  File? _trainingCertificateFile;
  String? _trainingCertificatePath;
  File? _medicalCertificateFile;
  String? _medicalCertificatePath;
  AppError? _error;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _yearsController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  void _continue() {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    final isPaid = _isPaidTrack(args);
    if (_trainingCertificatePath == null) return;

    args['certificatePath'] = _trainingCertificatePath;
    if (isPaid && _medicalCertificatePath != null) {
      args['medicalCertificatePath'] = _medicalCertificatePath;
    }
    final bio = _bioController.text.trim();
    if (bio.isNotEmpty) {
      args['bio'] = bio;
    }
    final years = int.tryParse(_yearsController.text.trim());
    if (years != null) {
      args['yearsExperience'] = years;
    }

    // Skip quiz during registration - go directly to register
    // Quiz will be shown on home screen after account creation
    if (isPaid) {
      // Paid track: go to register
      Navigator.of(context).pushNamed(Routes.registerRoute, arguments: args);
    } else {
      // Volunteer track: show success screen then register
      Navigator.of(
        context,
      ).pushNamed(Routes.volunteerSuccessRoute, arguments: args);
    }
  }

  Future<void> _pickCertificate({required bool isMedical}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          final file = File(result.files.single.path!);
          if (isMedical) {
            _medicalCertificateFile = file;
            _medicalCertificatePath = file.path;
          } else {
            _trainingCertificateFile = file;
            _trainingCertificatePath = file.path;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.handleError(e, context: 'CertificateFilePick');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Error')),
        body: ErrorDisplayWidget(
          error: _error!,
          onRetry: () {
            setState(() => _error = null);
          },
          title: 'Upload Error',
        ),
      );
    }

    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Get track info
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final isPaid = _isPaidTrack(args);

    final title = isPaid ? 'Medical Certification' : 'Training Certificate';
    final description =
        isPaid
            ? 'To join the Paid Professional track, please upload your medical interpreter certificate.'
            : 'Please upload any relevant training certificates or proof of language proficiency.';

    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Verification'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSize.s24,
            AppSize.s24,
            AppSize.s24,
            AppSize.s24 + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ColorManager.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              _UploadCard(
                title:
                    isPaid
                        ? 'Step 1 • Training certificate'
                        : 'Training certificate (required)',
                description:
                    'PDF, JPG, or PNG (max 5MB). Accredited coursework, ATA/ACTFL exams, or college transcripts accepted.',
                file: _trainingCertificateFile,
                onPick: () => _pickCertificate(isMedical: false),
              ),

              if (isPaid) ...[
                const SizedBox(height: 24),
                _UploadCard(
                  title: 'Step 2 • Medical credential (Optional)',
                  description:
                      'National medical interpreter certificate\n CHI/CMI.',
                  file: _medicalCertificateFile,
                  onPick: () => _pickCertificate(isMedical: true),
                ),
              ],

              if (isPaid) ...[
                const SizedBox(height: 32),
                Text(
                  'Professional Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Short Bio',
                    hintText: 'Tell us about your medical experience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _yearsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Years of Experience',
                    hintText: 'e.g. 5',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue(isPaid: isPaid) ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primary2,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Complete Registration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canContinue({required bool isPaid}) {
    final hasTraining = _trainingCertificateFile != null;
    return hasTraining;
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
    if (normalized.contains('paid') || normalized.contains('pro')) {
      return true;
    }
  }
  if (args['requiresMedicalDocs'] == true) return true;
  return false;
}

class _UploadCard extends StatelessWidget {
  final String title;
  final String description;
  final File? file;
  final VoidCallback onPick;

  const _UploadCard({
    required this.title,
    required this.description,
    required this.file,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = file != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFile ? ColorManager.success : ColorManager.greyLight,
          width: hasFile ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            hasFile ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
            size: 48,
            color: hasFile ? ColorManager.success : ColorManager.primary2,
          ),
          const SizedBox(height: 16),
          Text(
            hasFile ? 'File Selected' : title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasFile ? file!.path.split('/').last : description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ColorManager.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onPick,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorManager.primary2,
              side: BorderSide(color: ColorManager.primary2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(hasFile ? 'Change File' : 'Select File'),
          ),
        ],
      ),
    );
  }
}
