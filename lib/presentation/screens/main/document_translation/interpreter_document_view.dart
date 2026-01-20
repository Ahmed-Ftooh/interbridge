import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_document_preview_view.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Add this
import 'dart:developer'; // Add this

class InterpreterDocumentView extends StatefulWidget {
  const InterpreterDocumentView({super.key});

  @override
  State<InterpreterDocumentView> createState() =>
      _InterpreterDocumentViewState();
}

class _InterpreterDocumentViewState extends State<InterpreterDocumentView> {
  List<DocumentTranslationRequest> _availableRequests = [];
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadAvailableRequests();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _subscribeToRealtime() {
    _subscription =
        Supabase.instance.client
            .channel('public:document_translation_requests')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'document_translation_requests',
              callback: (payload) {
                log(
                  'Realtime update received for document_translation_requests',
                );
                if (mounted) {
                  _loadAvailableRequests();
                }
              },
            )
            .subscribe();
  }

  Future<void> _loadAvailableRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final requests =
          await instance<DocumentTranslationService>().getAvailableRequests();
      if (!mounted) return;
      setState(() {
        _availableRequests = requests;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading requests: $e';
      });
    }
  }

  void _previewRequest(DocumentTranslationRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InterpreterDocumentPreviewView(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ColorManager.error),
            const SizedBox(height: AppSize.s16),
            Text(
              'Error Loading Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorManager.textPrimary,
              ),
            ),
            const SizedBox(height: AppSize.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorManager.textSecondary),
              ),
            ),
            const SizedBox(height: AppSize.s16),
            ElevatedButton(
              onPressed: _loadAvailableRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_availableRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: AppSize.s16),
            Text(
              'No Available Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: AppSize.s8),
            Text(
              'There are currently no document translation requests available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSize.s16),
        itemCount: _availableRequests.length,
        itemBuilder: (context, index) {
          final request = _availableRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(DocumentTranslationRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSize.s16),
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request.title != null && request.title!.isNotEmpty) ...[
              Text(
                request.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSize.s12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLanguageDisplayText(
                          request.fromLanguage,
                          request.toLanguage,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (request.specialization != null) ...[
                        const SizedBox(height: AppSize.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSize.s8,
                            vertical: AppSize.s4,
                          ),
                          decoration: BoxDecoration(
                            color: ColorManager.primary2.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSize.s8),
                          ),
                          child: Text(
                            request.specialization!,
                            style: TextStyle(
                              color: ColorManager.primary2,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSize.s8,
                    vertical: AppSize.s4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSize.s8),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s16),

            if (request.text != null && request.text!.isNotEmpty) ...[
              const Text(
                'Text to Translate:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSize.s8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSize.s12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s8),
                ),
                child: Text(
                  request.text!,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3, // Limit to 3 lines
                  overflow: TextOverflow.ellipsis, // Show ellipsis if truncated
                ),
              ),
              const SizedBox(height: AppSize.s16),
            ],

            if (request.fileUrl != null) ...[
              const Text(
                'File Attached:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSize.s8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSize.s12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.blue),
                    SizedBox(width: AppSize.s8),
                    Expanded(
                      child: Text(
                        'Document file',
                        style: TextStyle(color: Colors.blue, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSize.s16),
            ],

            if (request.comment != null && request.comment!.isNotEmpty) ...[
              const Text(
                'Requester note:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSize.s8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSize.s12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSize.s8),
                ),
                child: Text(
                  request.comment!,
                  style: TextStyle(color: ColorManager.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSize.s16),
            ],

            Text(
              'Requested: ${request.createdAt.toString().split('.')[0]}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: AppSize.s16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _previewRequest(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primary2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSize.s12),
                ),
                child: const Text(
                  'Preview & Accept',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to convert language IDs to display names
  String _getLanguageDisplayText(String fromLanguage, String toLanguage) {
    final fromLanguageId = int.tryParse(fromLanguage) ?? 0;
    final toLanguageId = int.tryParse(toLanguage) ?? 0;
    final fromLanguageName = LanguageMappingUtility.getLanguageName(
      fromLanguageId,
    );
    final toLanguageName = LanguageMappingUtility.getLanguageName(toLanguageId);

    // Use language names if available, otherwise fallback to IDs
    if (fromLanguageName.isNotEmpty && toLanguageName.isNotEmpty) {
      return '$fromLanguageName → $toLanguageName';
    } else {
      return '$fromLanguage → $toLanguage';
    }
  }
}
