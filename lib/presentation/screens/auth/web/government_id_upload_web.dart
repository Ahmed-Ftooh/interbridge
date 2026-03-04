import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';

/// Web government ID upload screen — Step 2 of interpreter onboarding.
/// Allows uploading a photo of a government-issued ID for manual review.
class GovernmentIdUploadWebScreen extends StatefulWidget {
  const GovernmentIdUploadWebScreen({super.key});

  @override
  State<GovernmentIdUploadWebScreen> createState() =>
      _GovernmentIdUploadWebScreenState();
}

class _GovernmentIdUploadWebScreenState
    extends State<GovernmentIdUploadWebScreen> {
  Uint8List? _idBytes;
  String? _fileName;
  String _selectedIdType = 'national_id';
  bool _isUploading = false;

  static const _idTypes = [
    ('national_id', 'National ID'),
    ('passport', 'Passport'),
    ('drivers_license', "Driver's License"),
    ('residence_permit', 'Residence Permit'),
  ];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // Validate file size (max 10 MB)
          if (file.bytes!.lengthInBytes > 10 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File too large. Maximum size is 10 MB.'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            }
            return;
          }
          setState(() {
            _idBytes = file.bytes;
            _fileName = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _removeFile() {
    setState(() {
      _idBytes = null;
      _fileName = null;
    });
  }

  void _continue() {
    if (_idBytes == null) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    args['governmentIdBytes'] = _idBytes;
    args['governmentIdFileName'] = _fileName;
    args['governmentIdType'] = _selectedIdType;

    Navigator.of(context).pushNamed(
      Routes.interpreterTrackSelection,
      arguments: args,
    );
  }

  void _skip() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    Navigator.of(context).pushNamed(
      Routes.interpreterTrackSelection,
      arguments: args,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Identity verification',
      subtitle:
          'Upload a government-issued ID for verification. This helps us keep the platform safe.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(2, 9),
          const SizedBox(height: 28),

          // ID Type selector
          const Text(
            'Document type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedIdType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFF64748B)),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
                items: _idTypes
                    .map(
                      (t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedIdType = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Upload area
          if (_idBytes == null) ...[
            _buildUploadArea(),
          ] else ...[
            _buildPreview(),
          ],

          const SizedBox(height: 12),

          // Guidelines
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF3B82F6)),
                    SizedBox(width: 8),
                    Text(
                      'Photo guidelines',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...[
                  'Make sure the entire document is visible',
                  'Photo should be clear and well-lit',
                  'All text must be readable',
                  'Maximum file size: 10 MB',
                ].map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('  •  ',
                            style: TextStyle(
                                color: Color(0xFF3B82F6), fontSize: 12)),
                        Expanded(
                          child: Text(
                            g,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Continue button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _idBytes != null && !_isUploading ? _continue : null,
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
              child: _isUploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip
          Center(
            child: TextButton(
              onPressed: _skip,
              child: const Text(
                'Skip for now',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style:
                  TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickFile,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              style: BorderStyle.solid,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined,
                  size: 40, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'Click to upload your ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'PNG, JPG or WEBP up to 10 MB',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(11)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Image.memory(
                _idBytes!,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF22C55E), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fileName ?? 'ID uploaded',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _removeFile,
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444), size: 20),
                  tooltip: 'Remove and re-upload',
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              color: isCurrent
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
