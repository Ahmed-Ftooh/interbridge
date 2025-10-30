import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_translation_view.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'shared/shared_file_link_box.dart';

class InterpreterDocumentPreviewView extends StatefulWidget {
  final DocumentTranslationRequest request;

  const InterpreterDocumentPreviewView({super.key, required this.request});

  @override
  State<InterpreterDocumentPreviewView> createState() =>
      _InterpreterDocumentPreviewViewState();
}

class _InterpreterDocumentPreviewViewState
    extends State<InterpreterDocumentPreviewView> {
  bool _isLoading = false;

  // Using FileUtility methods for file operations

  Future<void> _acceptRequest() async {
    setState(() => _isLoading = true);
    try {
      await instance<DocumentTranslationService>().acceptRequest(
        widget.request.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate directly to the translation interface
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) =>
                    InterpreterTranslationView(request: widget.request),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _declineRequest() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Decline Request'),
              content: const Text(
                'Are you sure you want to decline this translation request?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Decline'),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        setState(() => _isLoading = true);
        await instance<InterpreterJobService>().declineJob(widget.request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request declined'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Preview'), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language pair and specialization header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: ColorManager.primary2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSize.s12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.translate,
                              color: ColorManager.primary2,
                              size: AppSize.s20,
                            ),
                            const SizedBox(width: AppSize.s8),
                            Text(
                              _getLanguageDisplayText(
                                widget.request.fromLanguage,
                                widget.request.toLanguage,
                              ),
                              style: TextStyle(
                                fontSize: AppSize.s14,
                                fontWeight: FontWeight.bold,
                                color: ColorManager.primary2,
                              ),
                            ),
                          ],
                        ),
                        if (widget.request.specialization != null) ...[
                          const SizedBox(height: AppSize.s8),
                          Row(
                            children: [
                              Icon(
                                Icons.category,
                                color: ColorManager.primary2,
                                size: AppSize.s20,
                              ),
                              const SizedBox(width: AppSize.s8),
                              Text(
                                widget.request.specialization!,
                                style: TextStyle(
                                  fontSize: AppSize.s14,
                                  color: ColorManager.primary2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSize.s24),
                  // Document content
                  Padding(
                    padding: const EdgeInsets.all(AppSize.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.request.text != null &&
                            widget.request.text!.isNotEmpty) ...[
                          Text(
                            'Document Content:',
                            style: TextStyle(
                              fontSize: AppSize.s18,
                              fontWeight: FontWeight.bold,
                              color: ColorManager.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSize.s16),
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
                                color: ColorManager.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSize.s24),
                        ],

                        if (widget.request.fileUrl != null) ...[
                          Text(
                            'Attached File:',
                            style: TextStyle(
                              fontSize: AppSize.s18,
                              fontWeight: FontWeight.bold,
                              color: ColorManager.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSize.s16),
                          SharedFileLinkBox(
                            context: context,
                            fileUrl: widget.request.fileUrl!,
                            fileName: widget.request.fileName,
                            method: widget.request.translationMethod,
                            isOriginal: true,
                          ),
                          const SizedBox(height: AppSize.s24),
                        ],

                        // Instructions for interpreter
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
                                    'Instructions',
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
                                'Please review the document content above. If you accept this request, you will be able to translate the content and submit it back to the requester.',
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
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(AppSize.s20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: ColorManager.greyMedium, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _declineRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSize.s16,
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: AppSize.s16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSize.s16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _acceptRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primary2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSize.s16,
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: AppSize.s20,
                              width: AppSize.s20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: AppSize.s16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
