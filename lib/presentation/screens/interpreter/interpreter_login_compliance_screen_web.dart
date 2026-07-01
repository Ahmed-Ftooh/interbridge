import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart'; // Needed for Session Memory
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/data/services/compliance_storage.dart';
import 'package:interbridge/data/services/compliance_storage.dart';

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
        'audio': true, 
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
            ..style.borderRadius = '16px'
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
      log('InterpreterLoginComplianceScreen: web camera/mic start failed: $e');
      if (!mounted) return;
      setState(() {
        _cameraError =
            'Could not access your camera or microphone. Please click the lock icon in your browser URL bar, allow Camera & Microphone, and refresh the page.';
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
    if (!_cameraReady || _videoElement == null) return;

    try {
      final int width = _videoElement!.videoWidth > 0 ? _videoElement!.videoWidth : 1280;
      final int height = _videoElement!.videoHeight > 0 ? _videoElement!.videoHeight : 720;

      final canvas = html.CanvasElement(width: width, height: height)..style.display = 'none';
      final context = canvas.context2D;
      context.imageSmoothingEnabled = true;
      context.imageSmoothingQuality = 'high';
      context.drawImageScaled(_videoElement!, 0, 0, width.toDouble(), height.toDouble());

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.98);
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) throw Exception('Failed to capture camera frame.');

      final base64Payload = dataUrl.substring(commaIndex + 1);
      final bytes = base64Decode(base64Payload);

      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (e) {
      log('InterpreterLoginComplianceScreen: web capture failed: $e');
    }
  }

  Future<void> _submitPhoto() async {
    if (!_instructionCheck1 || !_instructionCheck2 || !_instructionCheck3 || !_instructionCheck4) return;
    if (_photoBytes == null || _photoBytes!.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      await _supabaseService.uploadInterpreterLoginCompliancePhoto(
        _photoBytes!,
        fileName: 'login_compliance.jpg',
      );

      // --- CRITICAL FIX: MARK SESSION AS COMPLIANT SECURELY ---
      await ComplianceStorage.markCompliancePassed();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.interpreterPortalDashboardRoute, 
        (route) => false,
      );
      
    } catch (e) {
      log('InterpreterLoginComplianceScreen: web upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canCapture = !_isUploading && _cameraReady && !_cameraStarting;
    final bool allChecked = _instructionCheck1 && _instructionCheck2 && _instructionCheck3 && _instructionCheck4;
    final bool canSubmit = allChecked && _photoBytes != null && !_isUploading;

    return AuthWebWrapper(
      maxWidth: 900, 
      title: 'Pre-Shift System Check',
      subtitle: 'For security and compliance, verify your hardware and environment before entering the dashboard.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_cameraError != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      border: Border.all(color: const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _cameraError!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AuthWebPalette.border, width: 2),
                      color: const Color(0xFF0F172A),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _photoBytes != null
                        ? Image.memory(
                            _photoBytes!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          )
                        : Stack(
                            children: [
                              Positioned.fill(
                                child: _cameraStarting
                                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                    : (_cameraReady && _videoElement != null)
                                        ? HtmlElementView(viewType: _webcamViewId)
                                        : const Center(
                                            child: Text('Camera preview unavailable', style: TextStyle(color: Colors.white70)),
                                          ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _cameraReady ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _cameraReady ? 'Mic & Camera Active' : 'Connecting...',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading 
                        ? null 
                        : (_photoBytes == null 
                            ? (canCapture ? _capturePhoto : null) 
                            : () => setState(() => _photoBytes = null)),
                    icon: Icon(_photoBytes == null ? Icons.camera_alt_rounded : Icons.refresh_rounded),
                    label: Text(_photoBytes == null ? 'Capture Compliance Photo' : 'Retake Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _photoBytes == null ? AuthWebPalette.primary : Colors.white,
                      foregroundColor: _photoBytes == null ? Colors.white : AuthWebPalette.textPrimary,
                      elevation: 0,
                      side: BorderSide(
                        color: _photoBytes == null ? Colors.transparent : AuthWebPalette.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 48),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Shift Requirements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AuthWebPalette.textPrimary),
                ),
                const SizedBox(height: 16),
                
                _PremiumCheckItem(
                  icon: Icons.lock_outline,
                  title: 'Secure & Private Location',
                  subtitle: 'Zero foot traffic and absolute privacy.',
                  value: _instructionCheck1,
                  onTap: () => setState(() => _instructionCheck1 = !_instructionCheck1),
                ),
                const SizedBox(height: 12),
                _PremiumCheckItem(
                  icon: Icons.wallpaper_outlined,
                  title: 'Professional Backdrop',
                  subtitle: 'Solid neutral background (White or Light Grey).',
                  value: _instructionCheck2,
                  onTap: () => setState(() => _instructionCheck2 = !_instructionCheck2),
                ),
                const SizedBox(height: 12),
                _PremiumCheckItem(
                  icon: Icons.checkroom_outlined,
                  title: 'Corporate Attire',
                  subtitle: 'InterBridge navy blue uniform or formal wear.',
                  value: _instructionCheck3,
                  onTap: () => setState(() => _instructionCheck3 = !_instructionCheck3),
                ),
                const SizedBox(height: 12),
                _PremiumCheckItem(
                  icon: Icons.headphones_outlined,
                  title: 'Technical Readiness',
                  subtitle: 'Headset connected, internet verified.',
                  value: _instructionCheck4,
                  onTap: () => setState(() => _instructionCheck4 = !_instructionCheck4),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submitPhoto : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthWebPalette.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Enter Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isUploading ? null : () async {
                      setState(() => _isUploading = true);
                      try {
                        await ComplianceStorage.clearCompliance(); // REMOVE FLAG ON LOGOUT!
                        await Supabase.instance.client.auth.signOut();
                      } catch (_) {}
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.splashRoute, 
                          (route) => false,
                        );
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: AuthWebPalette.textSecondary),
                    child: const Text('Cancel & Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCheckItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;

  const _PremiumCheckItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? AuthWebPalette.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? AuthWebPalette.primary : AuthWebPalette.border,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: value ? AuthWebPalette.primary : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: value ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value ? AuthWebPalette.primary : AuthWebPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AuthWebPalette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: value ? AuthWebPalette.primary : const Color(0xFFCBD5E1),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}