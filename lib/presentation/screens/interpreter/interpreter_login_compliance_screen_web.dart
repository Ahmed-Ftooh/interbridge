import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';

class InterpreterLoginComplianceScreen extends StatefulWidget {
  const InterpreterLoginComplianceScreen({super.key});

  @override
  State<InterpreterLoginComplianceScreen> createState() =>
      _InterpreterLoginComplianceScreenState();
}

class _InterpreterLoginComplianceScreenState
    extends State<InterpreterLoginComplianceScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  final String _webcamViewId =
      'interpreter-compliance-webcam-${DateTime.now().millisecondsSinceEpoch}';

  html.MediaStream? _cameraStream;
  html.VideoElement? _videoElement;

  Uint8List? _photoBytes;
  bool _isUploading = false;
  bool _cameraReady = false;
  bool _cameraStarting = false;
  String? _cameraError;
  bool _instructionCheck1 = false;
  bool _instructionCheck2 = false;
  bool _instructionCheck3 = false;
  bool _instructionCheck4 = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _startCamera() async {
    setState(() {
      _cameraStarting = true;
      _cameraError = null;
    });

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Camera API is not available in this browser.');
      }

      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
          'frameRate': {'ideal': 30},
        },
        'audio': false,
      });

      _cameraStream = stream;

      _videoElement =
          html.VideoElement()
            ..srcObject = stream
            ..autoplay = true
            ..muted = true
            ..setAttribute('playsinline', 'true')
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover'
            ..style.borderRadius = '12px'
            ..style.transform = 'scaleX(-1)';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _webcamViewId,
        (int viewId) => _videoElement!,
      );

      await _videoElement!.play();

      if (!mounted) return;
      setState(() {
        _cameraReady = true;
      });
    } catch (e) {
      log('InterpreterLoginComplianceScreen: web camera start failed: $e');
      if (!mounted) return;
      setState(() {
        _cameraError =
            'Could not access your camera. Please allow camera access and refresh this page.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cameraStarting = false;
        });
      }
    }
  }

  void _stopCamera() {
    if (_cameraStream != null) {
      for (final track in _cameraStream!.getTracks()) {
        track.stop();
      }
      _cameraStream = null;
    }
    _videoElement = null;
  }

  Future<void> _capturePhoto() async {
    if (!_cameraReady || _videoElement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is not ready yet. Please wait a moment.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final int width =
          _videoElement!.videoWidth > 0 ? _videoElement!.videoWidth : 1280;
      final int height =
          _videoElement!.videoHeight > 0 ? _videoElement!.videoHeight : 720;

      final canvas = html.CanvasElement(width: width, height: height)
        ..style.display = 'none';
      final context = canvas.context2D;
      context.imageSmoothingEnabled = true;
      context.imageSmoothingQuality = 'high';
      context.drawImageScaled(
        _videoElement!,
        0,
        0,
        width.toDouble(),
        height.toDouble(),
      );

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.98);
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) {
        throw Exception('Failed to capture camera frame.');
      }

      final base64Payload = dataUrl.substring(commaIndex + 1);
      final bytes = base64Decode(base64Payload);

      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
      });
    } catch (e) {
      log('InterpreterLoginComplianceScreen: web capture failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not capture selfie from camera. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitPhoto() async {
    if (!_instructionCheck1 || !_instructionCheck2 || !_instructionCheck3 || !_instructionCheck4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm all compliance checks before submitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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
      log('InterpreterLoginComplianceScreen: web upload failed: $e');
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
    final bool canCapture = !_isUploading && _cameraReady && !_cameraStarting;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool compactHeight = screenHeight <= 850;
    final double previewMaxWidth =
        compactHeight
            ? (screenWidth >= 1200 ? 760 : 620)
            : (screenWidth >= 1200 ? 920 : 760);
    const double previewAspectRatio = 16 / 9;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Pre-Session Compliance Check'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: compactHeight ? 14 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'before starting work, confirm the required setup:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700 ,color: ColorManager.primary),
                ),
                const SizedBox(height: 16),
                 _InstructionItem(
                  icon: Icons.lock_outline,
                  text: 'Secure & Private Location: Ensure zero foot traffic and absolute privacy for HIPAA compliance.',
                   value: _instructionCheck1, onChanged: (bool? p1) { 
                      setState(() {
                        _instructionCheck1 = p1 ?? false;
                      });
                    },

                ),
                 _InstructionItem(
                  icon: Icons.wallpaper_outlined,
                  text: 'Professional Backdrop: A solid neutral background (White or Light Grey) is required to minimize distractions',
                   value: _instructionCheck2, onChanged: (bool? p1) { 
                      setState(() {
                        _instructionCheck2 = p1 ?? false;
                      });
                    },
                ),
                 _InstructionItem(
                  icon: Icons.checkroom_outlined,
                  text: 'Corporate Attire Please ensure you are wearing the approved InterBridge navy blue uniform.Polo Shirt or Formal Shirt ',
                   value: _instructionCheck3, onChanged: (bool? p1) { 
                      setState(() {
                        _instructionCheck3 = p1 ?? false;
                      });
                    },
                ),
                 _InstructionItem(

                  icon: Icons.headphones_outlined,
                  text: 'Technical Readiness: Noise-canceling headset connected and high-speed internet verified.',
                   value: _instructionCheck4, onChanged: (bool? p1) { 
                      setState(() {
                        _instructionCheck4 = p1 ?? false;
                      });
                    },
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
                    'A compliance photo is required on every interpreter login.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
                SizedBox(height: compactHeight ? 14 : 20),
                if (_cameraError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _cameraError!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                
                // 1. The Main Display Area (Toggles between Live Camera and Captured Photo)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: previewMaxWidth),
                    child: AspectRatio(
                      aspectRatio: previewAspectRatio,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _photoBytes != null
                            // If we have a photo, show the captured image
                            ? Image.memory(
                                _photoBytes!,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                gaplessPlayback: true,
                              )
                            // If we don't have a photo, show the live camera feed
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: _cameraStarting
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : (_cameraReady && _videoElement != null)
                                            ? HtmlElementView(viewType: _webcamViewId)
                                            : const Center(
                                                child: Text(
                                                  'Camera preview unavailable',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.fiber_manual_record,
                                            color: Colors.redAccent,
                                            size: 12,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Live camera preview',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      color: Colors.black.withValues(alpha: 0.45),
                                      child: const Text(
                                        'Center your face and shoulders in this frame.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // 2. The Centered, Fixed-Width Action Button
                Center(
                  child: SizedBox(
                    height: 48,
                    width: 220, // Prevents the ugly web stretch
                    child: ElevatedButton.icon(
                      // If no photo: Capture it. If photo exists: clear it to retake.
                      onPressed: _isUploading 
                          ? null 
                          : (_photoBytes == null 
                              ? (canCapture ? _capturePhoto : null) 
                              : () => setState(() => _photoBytes = null)),
                      icon: Icon(_photoBytes == null ? Icons.camera_alt : Icons.refresh),
                      label: Text(_photoBytes == null ? 'Take Photo' : 'Retake Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _photoBytes == null ? Colors.blue.shade600 : Colors.grey.shade200,
                        foregroundColor: _photoBytes == null ? Colors.white : Colors.black87,
                        elevation: _photoBytes == null ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24), // Modern pill shape
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: compactHeight ? 14 : 32),

              // 3. The Submit Button
                Center(
                  child: SizedBox(
                    height: 48,
                    width: 280, // A bit wider than the capture button to show it's the final step
                    child: ElevatedButton(
                      onPressed:
                          (_isUploading || _photoBytes == null)
                              ? null
                              : _submitPhoto,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24), // Matches the pill shape!
                        ),
                      ),
                      child:
                          _isUploading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Text('Submit and continue', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // 4. The Sign Out Button
                Center(
                  child: TextButton(
                    onPressed:
                        _isUploading
                            ? null
                            : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600, // Makes it look less prominent than submit
                    ),
                    child: const Text('Sign out'),
                  ),
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
  const _InstructionItem({required this.icon, required this.text, required this.value,required this.onChanged});

  final IconData icon;
  final bool value ;
  final void Function(bool?) onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
            Checkbox(value: value, onChanged: onChanged,activeColor: Colors.blue.shade600,side: const BorderSide(color: Colors.black),),
         
          const SizedBox(width: 10),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(text, style: const TextStyle(fontSize: 15,fontWeight: FontWeight.bold)),
          )),


        ],
      ),
    );
  }
}