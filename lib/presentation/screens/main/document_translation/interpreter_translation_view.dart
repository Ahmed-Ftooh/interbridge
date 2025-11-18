// lib/presentation/screens/main/document_translation/interpreter_translation_view.dart
import 'dart:developer';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/services/translation_cache_service.dart';
import 'package:interbridge/app/di.dart';
import 'package:flutter/services.dart';
import 'package:interbridge/presentation/screens/main/preview/embedded_audio_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'shared/helpers.dart';
import 'shared/shared_file_link_box.dart';

// --- ADDED IMPORTS FOR IN-LINE VIEWERS ---
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// ------------------------------------------
import 'package:interbridge/data/services/translation_draft_repository.dart';
import 'bloc/interpreter_draft_cubit.dart';

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
  Timer? _debounce;
  late final InterpreterDraftCubit _draftCubit;
  // Focus handling to hide submit button while typing
  late FocusNode _translationFocusNode;
  bool _showSubmitButton = true;

  // --- ADDED: State for handling secure file URLs ---
  String? _resolvedFileUrl;
  bool _isLoadingUrl = true;
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();
    _cacheService = instance<TranslationCacheService>();
    _translatedTextController.addListener(_onTextChanged);
    final user = Supabase.instance.client.auth.currentUser;
    final repo = instance<TranslationDraftRepository>();
    _draftCubit = InterpreterDraftCubit(
      repo: repo,
      requestId: widget.request.id,
      interpreterId: user?.id ?? 'unknown',
    );
    _translationFocusNode = FocusNode();
    _translationFocusNode.addListener(_handleTranslationFocusChange);
    _initializeContent();
  }

  Future<void> _initializeContent() async {
    _cacheActiveTranslation();

    // Load cached text
    if (widget.cachedTranslationText != null &&
        widget.cachedTranslationText!.isNotEmpty) {
      _translatedTextController.text = widget.cachedTranslationText!;
    } else if (widget.request.text != null && widget.request.text!.isNotEmpty) {
      _translatedTextController.text = widget.request.text!;
    }

    // Load server draft and hydrate controller if available
    await _draftCubit.load();
    if (mounted && _draftCubit.state.text.isNotEmpty) {
      // Prefer server draft if it has content
      _translatedTextController.text = _draftCubit.state.text;
    }

    // --- NEW: Resolve the file URL (get a signed URL if needed) ---
    if (widget.request.fileUrl != null) {
      try {
        final url = await _resolveFileUrl(widget.request.fileUrl!);
        if (mounted) {
          setState(() {
            _resolvedFileUrl = url;
          });
        }
      } catch (e) {
        log("Error resolving file URL: $e");
        // Handle error (e.g., show a snackbar or set an error state)
      }
    }
    if (mounted) {
      setState(() => _isLoadingUrl = false);
    }
    // -------------------------------------------------------------
  }

  void _onTextChanged() {
    // Debounce autosave to reduce write pressure
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _cacheService.updateTranslationText(
          _translatedTextController.text,
        );
        // Also queue server autosave
        _draftCubit.queueAutosave(text: _translatedTextController.text);
      } catch (e) {
        log('Autosave failed: $e');
      }
    });
  }

  Future<void> _cacheActiveTranslation() async {
    // ... (This function remains unchanged)
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
    // ... (This function remains unchanged)
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
      // Clear server draft on submit
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await instance<TranslationDraftRepository>().clearDraft(
          requestId: widget.request.id,
          interpreterId: user.id,
        );
      }

      if (mounted) {
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickAndUploadTranslatedFile() async {
    // ... (This function remains unchanged)
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

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final objectPath =
          'translated/${user.id}/$dateStr/${DateTime.now().millisecondsSinceEpoch}_$filename';

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
      // Queue draft autosave with file URL
      _draftCubit.queueAutosave(
        text: _translatedTextController.text,
        fileUrl: publicUrl,
      );
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

  // --- ADDED: Helper method to resolve Supabase URL ---
  Future<String> _resolveFileUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // Check if it's a Supabase storage URL
      if (!uri.path.contains('/storage/v1/object/')) return url;

      final segments = uri.pathSegments;
      final objectIndex = segments.indexOf('object');
      if (objectIndex == -1 || objectIndex + 2 >= segments.length) return url;

      String bucket;
      List<String> pathParts;
      final visibilityOrBucket = segments[objectIndex + 1];

      if (visibilityOrBucket == 'public' || visibilityOrBucket == 'sign') {
        if (objectIndex + 3 >= segments.length) return url; // Invalid path
        bucket = segments[objectIndex + 2];
        pathParts = segments.sublist(objectIndex + 3);
      } else {
        bucket = visibilityOrBucket;
        pathParts = segments.sublist(objectIndex + 2);
      }

      if (bucket.isEmpty || pathParts.isEmpty) return url;
      final objectPath = pathParts.join('/');

      // Generate a short-lived signed URL
      final client = Supabase.instance.client;
      final res = await client.storage
          .from(bucket)
          .createSignedUrl(objectPath, const Duration(minutes: 60).inSeconds);
      return res;
    } catch (e) {
      log("Error signing URL: $e");
      return url; // Fallback to original URL
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.request.title ?? 'Translate Document'),
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
                        'Type: ${getTranslationMethodLabel(widget.request.translationMethod)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorManager.textSecondary,
                        ),
                      ),
                      // --- REMOVED: SharedFileLinkBox from header ---
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
                  // --- NEW: Source Content Viewer ---
                  _buildSourceContent(),
                  const SizedBox(height: AppSize.s24),
                  if (widget.request.comment != null &&
                      widget.request.comment!.isNotEmpty) ...[
                    _buildRequesterNote(),
                    const SizedBox(height: AppSize.s24),
                  ],

                  // --- Translation Input Area ---
                  _buildTranslationInput(),
                  const SizedBox(height: AppSize.s24),

                  // --- Instructions Area ---
                  _buildInstructions(),
                ],
              ),
            ),
          ),
          // Submit button
          if (_showSubmitButton) _buildSubmitButton(),
        ],
      ),
    );
  }

  // --- NEW: Helper for all source content (text, pdf, image, voice) ---
  Widget _buildSourceContent() {
    final bool hasText =
        widget.request.text != null && widget.request.text!.isNotEmpty;
    final bool hasFile =
        widget.request.fileUrl != null &&
        widget.request.translationMethod != 'text';

    if (!hasText && !hasFile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No source content provided for this request.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Original Text Section (if it exists)
        if (hasText) ...[
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
              border: Border.all(color: ColorManager.greyMedium, width: 1),
            ),
            child: SelectableText(
              widget.request.text!,
              style: TextStyle(
                fontSize: AppSize.s14,
                height: 1.5,
                color: ColorManager.textSecondary,
              ),
            ),
          ),
          if (hasFile) const SizedBox(height: AppSize.s24), // Spacer
        ],

        // 2. Original File Viewer Section (if it exists)
        if (hasFile) ...[
          Text(
            'Original File:',
            style: TextStyle(
              fontSize: AppSize.s16,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          const SizedBox(height: AppSize.s12),
          _buildSourceFileViewer(), // The actual file viewer
        ],
      ],
    );
  }

  // --- NEW: Helper widget to show the correct file viewer ---
  Widget _buildSourceFileViewer() {
    if (_isLoadingUrl) {
      return Container(
        height: 200, // Give some space for the loader
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSize.s12),
          border: Border.all(color: ColorManager.greyMedium, width: 1),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_resolvedFileUrl == null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSize.s12),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: const Center(
          child: Text(
            'Error: Could not load file URL.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final method = widget.request.translationMethod?.toLowerCase();

    // Constrain the height of visual viewers
    const double viewerHeight = 400;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AppSize.s12),
      border: Border.all(color: ColorManager.greyMedium, width: 1),
    );

    switch (method) {
      case 'voice':
        // Use your existing audio player
        return EmbeddedAudioPlayer(
          url: _resolvedFileUrl!, // Use the resolved URL
          fileName: widget.request.fileName,
        );

      case 'image':
        return Container(
          width: double.infinity,
          height: viewerHeight,
          decoration: decoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              AppSize.s12 - 1,
            ), // Clip to inner radius
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                _resolvedFileUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stack) {
                  return const Center(
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
        );

      case 'pdf':
      case 'document':
        return Container(
          width: double.infinity,
          height: viewerHeight,
          decoration: decoration,
          child: SfPdfViewer.network(
            _resolvedFileUrl!,
            canShowPageLoadingIndicator: true,
          ),
        );

      default:
        // Fallback for any other type, show the link box
        return SharedFileLinkBox(
          context: context,
          fileUrl: _resolvedFileUrl!,
          fileName: widget.request.fileName,
          method: widget.request.translationMethod,
          isOriginal: true,
        );
    }
  }

  // --- NEW: Helper for the translation input area ---
  Widget _buildTranslationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    ClipboardData(text: _translatedTextController.text),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Translation copied to clipboard!'),
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
          focusNode: _translationFocusNode,
          maxLines: 8,
          minLines: 5, // Give it a minimum size
          decoration: InputDecoration(
            hintText: 'Enter your translation here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.primary2, width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {}); // Rebuild to show/hide copy button
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
        ],
      ],
    );
  }

  // --- NEW: Helper for the instructions box ---
  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
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
    );
  }

  Widget _buildRequesterNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSize.s12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: Colors.blue),
              const SizedBox(width: AppSize.s8),
              Text(
                'Requester note',
                style: TextStyle(
                  fontSize: AppSize.s14,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            widget.request.comment!,
            style: TextStyle(
              fontSize: AppSize.s14,
              color: ColorManager.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Helper for the bottom submit button ---
  Widget _buildSubmitButton() {
    return Container(
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
    );
  }

  void _handleTranslationFocusChange() {
    // Hide the submit button when the translation field is focused
    if (!mounted) return;
    setState(() {
      _showSubmitButton = !_translationFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _translatedTextController.removeListener(_onTextChanged);
    _saveCurrentTranslation();
    _translatedTextController.dispose();
    _translationFocusNode.removeListener(_handleTranslationFocusChange);
    _translationFocusNode.dispose();
    _draftCubit.close();
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
