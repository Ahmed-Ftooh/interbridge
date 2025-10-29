import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/services/translation_cache_service.dart';
import 'package:interbridge/app/di.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:interbridge/core/file_utility.dart';

String _getTranslationMethodLabel(String? method) {
  switch (method) {
    case 'text':
      return 'Text';
    case 'document':
      return 'Document';
    case 'image':
      return 'Image';
    case 'voice':
      return 'Voice';
    default:
      return 'Unknown';
  }
}

class InterpreterTranslationView extends StatefulWidget {
  final DocumentTranslationRequest request;
  final String? cachedTranslationText;

  const InterpreterTranslationView({
    super.key,
    required this.request,
    this.cachedTranslationText,
  });

  @override
  State<InterpreterTranslationView> createState() =>
      _InterpreterTranslationViewState();
}

class _InterpreterTranslationViewState
    extends State<InterpreterTranslationView> {
  final TextEditingController _translatedTextController =
      TextEditingController();
  bool _isSubmitting = false;
  late TranslationCacheService _cacheService;
  String? _uploadedTranslatedFileUrl;

  @override
  void initState() {
    super.initState();
    _cacheService = instance<TranslationCacheService>();

    // Cache the active translation request
    _cacheActiveTranslation();

    // Load cached translation text if available, otherwise pre-fill with original text
    if (widget.cachedTranslationText != null &&
        widget.cachedTranslationText!.isNotEmpty) {
      _translatedTextController.text = widget.cachedTranslationText!;
    } else if (widget.request.text != null && widget.request.text!.isNotEmpty) {
      _translatedTextController.text = widget.request.text!;
    }
  }

  Future<void> _cacheActiveTranslation() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _cacheService.cacheActiveTranslation(
          request: widget.request,
          currentUserId: user.id,
          currentTranslationText: _translatedTextController.text,
        );
      }
    } catch (e) {
      log('Error caching active translation: $e');
    }
  }

  Future<void> _submitTranslation() async {
    if ((_translatedTextController.text.trim().isEmpty) &&
        (_uploadedTranslatedFileUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide translated text or upload a file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await instance<DocumentTranslationService>().completeRequest(
        requestId: widget.request.id,
        translatedText:
            _translatedTextController.text.trim().isNotEmpty
                ? _translatedTextController.text.trim()
                : null,
        translatedFileUrl: _uploadedTranslatedFileUrl,
      );

      if (mounted) {
        // Clear cache after successful submission
        await _cacheService.clearCache();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting translation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadTranslatedFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null || result.files.single.path == null) return;
      final path = result.files.single.path!;
      final file = File(path);
      final bytes = await file.readAsBytes();
      final originalFilename = result.files.single.name;
      final filename = originalFilename.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-.]'),
        '_',
      );
      final ext = filename.split('.').last.toLowerCase();
      String contentType;
      switch (ext) {
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'heic':
          contentType = 'image/heic';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        case 'mp3':
          contentType = 'audio/mpeg';
          break;
        case 'wav':
          contentType = 'audio/wav';
          break;
        case 'm4a':
          contentType = 'audio/mp4';
          break;
        default:
          contentType = 'application/octet-stream';
      }

      // Upload to Supabase storage in 'documents' bucket
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final objectPath =
          'translated/${user.id}/$dateStr/${DateTime.now().millisecondsSinceEpoch}_$filename';
      // Try preferred bucket, fallback to 'documents' if not found
      String bucket = 'documents';
      try {
        await client.storage
            .from(bucket)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: contentType),
            );
      } catch (_) {
        bucket = 'documents';
        await client.storage
            .from(bucket)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: contentType),
            );
      }
      final publicUrl = client.storage.from(bucket).getPublicUrl(objectPath);

      setState(() => _uploadedTranslatedFileUrl = publicUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translated file uploaded'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate Document'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Upload translated file',
            onPressed: _pickAndUploadTranslatedFile,
            icon: const Icon(Icons.cloud_upload),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitTranslation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with language pair
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSize.s20),
            decoration: BoxDecoration(
              color: ColorManager.primary2.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: ColorManager.greyMedium, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.translate,
                  color: ColorManager.primary2,
                  size: AppSize.s24,
                ),
                const SizedBox(width: AppSize.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.request.fromLanguage} → ${widget.request.toLanguage}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.request.title != null) ...[
                        const SizedBox(height: AppSize.s4),
                        Text(
                          widget.request.title!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSize.s4),
                      Text(
                        'Type: ${_getTranslationMethodLabel(widget.request.translationMethod)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorManager.textSecondary,
                        ),
                      ),
                      if (widget.request.fileUrl != null) ...[
                        const SizedBox(height: AppSize.s8),
                        GestureDetector(
                          onTap:
                              () => FileUtility.openFilePreview(
                                context,
                                widget.request.fileUrl!,
                                widget.request.translationMethod,
                                widget.request.fileName,
                                widget.request.fileType,
                              ),
                          child: Row(
                            children: [
                              FileUtility.getFileTypeIcon(
                                widget.request.translationMethod,
                              ),
                              const SizedBox(width: AppSize.s8),
                              const Text(
                                'View Original File',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original text section
                  if (widget.request.text != null &&
                      widget.request.text!.isNotEmpty) ...[
                    Text(
                      'Original Text (${widget.request.fromLanguage}):',
                      style: TextStyle(
                        fontSize: AppSize.s16,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSize.s12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSize.s16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                        border: Border.all(
                          color: ColorManager.greyMedium,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.request.text!,
                        style: TextStyle(
                          fontSize: AppSize.s14,
                          height: 1.5,
                          color: ColorManager.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSize.s24),
                  ],
                  // File preview section
                  if (widget.request.fileUrl != null &&
                      widget.request.translationMethod != 'text') ...[
                    Text(
                      'Original File:',
                      style: TextStyle(
                        fontSize: AppSize.s16,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSize.s12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSize.s16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          FileUtility.getFileTypeIcon(
                            widget.request.translationMethod,
                          ),
                          const SizedBox(width: AppSize.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTranslationMethodLabel(
                                    widget.request.translationMethod,
                                  ),
                                  style: const TextStyle(
                                    fontSize: AppSize.s14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                                if (widget.request.fileName != null) ...[
                                  const SizedBox(height: AppSize.s4),
                                  Text(
                                    widget.request.fileName!,
                                    style: TextStyle(
                                      fontSize: AppSize.s12,
                                      color: Colors.blue.withOpacity(0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed:
                                () => FileUtility.openFilePreview(
                                  context,
                                  widget.request.fileUrl!,
                                  widget.request.translationMethod,
                                  widget.request.fileName,
                                  widget.request.fileType,
                                ),
                            icon: const Icon(
                              Icons.open_in_new,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSize.s24),
                  ],
                  // Translation section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Translation (${widget.request.toLanguage}):',
                        style: TextStyle(
                          fontSize: AppSize.s16,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      if (_translatedTextController.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: _translatedTextController.text,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Translation copied to clipboard!',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: TextButton.styleFrom(
                            foregroundColor: ColorManager.primary2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSize.s12),
                  TextField(
                    controller: _translatedTextController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: 'Enter your translation here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSize.s12),
                        borderSide: BorderSide(
                          color: ColorManager.primary2,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {}); // Rebuild to show/hide copy button
                      // Cache the translation text as user types
                      _cacheService.updateTranslationText(value);
                    },
                  ),
                  const SizedBox(height: AppSize.s20),
                  if (_uploadedTranslatedFileUrl != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: AppSize.s8),
                        Expanded(
                          child: Text(
                            'Translated file attached',
                            style: TextStyle(color: ColorManager.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSize.s20),
                  ],
                  const SizedBox(height: AppSize.s24),
                  // Instructions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber[700],
                              size: AppSize.s20,
                            ),
                            const SizedBox(width: AppSize.s8),
                            Text(
                              'Translation Guidelines',
                              style: TextStyle(
                                fontSize: AppSize.s14,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSize.s8),
                        Text(
                          '• Provide accurate and natural translation\n'
                          '• Maintain the original meaning and tone\n'
                          '• Use appropriate terminology for the specialization\n'
                          '• You can provide text translation or upload a file',
                          style: TextStyle(
                            fontSize: AppSize.s12,
                            color: Colors.amber[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Submit button
          Container(
            padding: const EdgeInsets.all(AppSize.s20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: ColorManager.greyMedium, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTranslation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primary2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
                ),
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: AppSize.s20,
                          width: AppSize.s20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Submit Translation',
                          style: TextStyle(
                            fontSize: AppSize.s16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Save the current translation text before disposing
    _saveCurrentTranslation();
    _translatedTextController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentTranslation() async {
    try {
      if (_translatedTextController.text.isNotEmpty) {
        await _cacheService.updateTranslationText(
          _translatedTextController.text,
        );
      }
    } catch (e) {
      log('Error saving translation text: $e');
    }
  }
}
