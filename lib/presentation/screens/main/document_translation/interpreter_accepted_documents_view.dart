import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_translation_view.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:interbridge/data/services/hidden_items_service.dart';
import 'shared/shared_file_link_box.dart';

class InterpreterAcceptedDocumentsView extends StatefulWidget {
  const InterpreterAcceptedDocumentsView({super.key});

  @override
  State<InterpreterAcceptedDocumentsView> createState() =>
      _InterpreterAcceptedDocumentsViewState();
}

class _InterpreterAcceptedDocumentsViewState
    extends State<InterpreterAcceptedDocumentsView> {
  List<DocumentTranslationRequest> _acceptedRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAcceptedRequests();
  }

  Future<void> _loadAcceptedRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests =
          await instance<DocumentTranslationService>().getAcceptedRequests();
      final hidden =
          await HiddenItemsService().getInterpreterHiddenAcceptedIds();
      setState(() {
        _acceptedRequests =
            requests.where((r) => !hidden.contains(r.id)).toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading requests: $e';
      });
    }
  }

  void _startTranslation(DocumentTranslationRequest request) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => InterpreterTranslationView(request: request),
          ),
        )
        .then((_) {
          // Reload requests when returning from translation view
          _loadAcceptedRequests();
        });
  }

  void _showOptionsDialog(DocumentTranslationRequest request) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Request Options'),
            content: const Text('What would you like to do with this request?'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteRequest(request);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteRequest(DocumentTranslationRequest request) async {
    try {
      await instance<DocumentTranslationService>().deleteRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadAcceptedRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
              onPressed: _loadAcceptedRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_acceptedRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: AppSize.s16),
            Text(
              'No Accepted Translations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: AppSize.s8),
            Text(
              'You have no accepted document translation requests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAcceptedRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSize.s16),
        itemCount: _acceptedRequests.length,
        itemBuilder: (context, index) {
          final request = _acceptedRequests[index];
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
            GestureDetector(
              onLongPress: () => _showOptionsDialog(request),
              child: Row(
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
                              color: ColorManager.primary2.withOpacity(0.1),
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
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSize.s8,
                vertical: AppSize.s4,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSize.s8),
              ),
              child: const Text(
                'Accepted',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove from My Tasks',
              onPressed: () async {
                await HiddenItemsService().hideInterpreterAccepted(request.id);
                await _loadAcceptedRequests();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from My Tasks')),
                  );
                }
              },
              icon: const Icon(Icons.delete_outline, size: 18),
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
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSize.s8),
                ),
                child: Text(
                  request.text!,
                  style: const TextStyle(fontSize: 14),
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
              SharedFileLinkBox(
                context: context,
                fileUrl: request.fileUrl!,
                fileName: request.fileName,
                method: request.translationMethod,
                isOriginal: true,
              ),
              const SizedBox(height: AppSize.s16),
            ],

            Text(
              'Accepted: ${request.acceptedAt?.toString().split('.')[0] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: AppSize.s16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startTranslation(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSize.s12),
                ),
                child: const Text(
                  'Start Translation',
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
