import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
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
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;
  late String _prompt;
  File? _certificateFile;
  String? _certificatePath;
  AppError? _error;

  static const List<String> _sentences = [
    'As a professional interpreter, I understand the critical importance of accurate communication in medical settings where lives depend on precise translation.',
    'The patient requires immediate attention from the cardiology team, and we need to ensure all medical terminology is correctly interpreted for the family.',
    'Please speak clearly and at a moderate pace, as this recording will be used to assess your pronunciation, fluency, and professional speaking abilities.',
    'Medical interpretation requires not only language proficiency but also cultural sensitivity and understanding of healthcare terminology and procedures.',
    'In emergency situations, interpreters must remain calm, focused, and accurate while facilitating communication between healthcare providers and patients.',
    'Professional medical interpreters undergo extensive training to handle complex medical terminology, cultural nuances, and ethical considerations in healthcare settings.',
    'The interpretation process involves active listening, cultural mediation, and ensuring that both parties understand each other completely and accurately.',
    'Healthcare providers rely on qualified interpreters to bridge language barriers and ensure patient safety, informed consent, and quality care delivery.',
  ];

  @override
  void initState() {
    super.initState();
    _prompt = _sentences[Random().nextInt(_sentences.length)];
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _filePath = path;
      });
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }

    final canRecord = await _recorder.hasPermission();
    if (!canRecord) return;

    final dir = await getTemporaryDirectory();
    final output = File(
      '${dir.path}/voice_check_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: output.path,
    );
    setState(() {
      _isRecording = true;
      _filePath = null;
    });
  }

  void _regeneratePrompt() {
    setState(() {
      _prompt = _sentences[Random().nextInt(_sentences.length)];
    });
  }

  void _continue() {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    if (_filePath == null || _certificatePath == null) return;
    // Pass local paths to registration; uploads happen after signup
    args['voiceSamplePath'] = _filePath;
    args['voicePrompt'] = _prompt;
    args['certificatePath'] = _certificatePath;
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
    _recorder.dispose();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Check')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Read this comprehensive sentence naturally to verify your professional speaking ability:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: ColorManager.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prompt,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _regeneratePrompt,
                      child: const Text('New sentence'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleRecord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isRecording ? Colors.red : ColorManager.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                    ),
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_filePath != null)
                    const Text(
                      'Recorded. You can continue.',
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Certificate (required)',
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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _filePath != null && _certificateFile != null
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
    );
  }
}
