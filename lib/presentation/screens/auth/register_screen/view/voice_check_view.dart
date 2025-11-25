import 'package:flutter/material.dart';
import 'dart:io';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';

class VoiceCheckScreen extends StatefulWidget {
  const VoiceCheckScreen({super.key});

  @override
  State<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends State<VoiceCheckScreen> {
  File? _certificateFile;
  String? _certificatePath;
  AppError? _error;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _yearsController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void _continue() {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    if (_certificatePath == null) return;
    // Pass local paths to registration; uploads happen after signup
    args['certificatePath'] = _certificatePath;
    final bio = _bioController.text.trim();
    if (bio.isNotEmpty) {
      args['bio'] = bio;
    }
    final years = int.tryParse(_yearsController.text.trim());
    if (years != null) {
      args['yearsExperience'] = years;
    }
    Navigator.of(context).pushNamed(Routes.registerRoute, arguments: args);
  }

  Future<void> _pickCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _certificateFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.handleError(e, context: 'CertificateFilePick');
      });
    }
  }

  // Uploading is deferred until after signup

  @override
  void dispose() {
    _bioController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voice Check')),
        body: ErrorDisplayWidget(
          error: _error!,
          onRetry: () {
            setState(() => _error = null);
          },
          title: 'Voice Check Error',
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload your certification (required)',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Certificate (PDF or image)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _certificateFile != null
                                  ? 'Selected: ${_certificateFile!.path.split('/').last}'
                                  : 'No certificate selected',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickCertificate,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Choose'),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      if (_certificateFile == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Certificate is required to continue.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Professional Profile (optional)',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Short bio',
                          hintText: 'Tell requesters about your experience',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _yearsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Years of experience',
                          hintText: 'e.g., 3',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _certificateFile != null
                          ? () {
                            _certificatePath = _certificateFile!.path;
                            _continue();
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
