import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/data/services/supabase_service.dart';

class InterpreterLoginComplianceScreen extends StatefulWidget {
  const InterpreterLoginComplianceScreen({super.key});

  @override
  State<InterpreterLoginComplianceScreen> createState() =>
      _InterpreterLoginComplianceScreenState();
}

class _InterpreterLoginComplianceScreenState
    extends State<InterpreterLoginComplianceScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _photoBytes;
  bool _isUploading = false;

  Future<void> _capturePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _photoBytes = bytes;
      });
    } catch (e) {
      log('InterpreterLoginComplianceScreen: mobile capture failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open your camera. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitPhoto() async {
    if (_photoBytes == null || _photoBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A compliance photo is required before you continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await _supabaseService.uploadInterpreterLoginCompliancePhoto(
        _photoBytes!,
        fileName: 'login_compliance.jpg',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      log('InterpreterLoginComplianceScreen: mobile upload failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload compliance photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Interpreter startup check'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Before starting work, confirm the required setup:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const _InstructionItem(
                  icon: Icons.lock_outline,
                  text: 'Private room only (no one else visible).',
                ),
                const _InstructionItem(
                  icon: Icons.wallpaper_outlined,
                  text: 'Use a plain white or gray background.',
                ),
                const _InstructionItem(
                  icon: Icons.checkroom_outlined,
                  text: 'Wear blue clothing.',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.shade50,
                  ),
                  child: const Text(
                    'A compliance photo is required on every interpreter login. Photos are automatically deleted after 7 days.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _capturePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take compliance selfie'),
                  ),
                ),
                const SizedBox(height: 14),
                if (_photoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytes!,
                      height: 240,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 170,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text('No photo captured yet.'),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitPhoto,
                    child:
                        _isUploading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Submit and continue'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      _isUploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  const _InstructionItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
