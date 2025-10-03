import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_translation_view.dart';

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
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Translation Preview'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with language pair and specialization
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSize.s20),
            decoration: BoxDecoration(
              color: ColorManager.primary2.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(color: ColorManager.greyMedium, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: ColorManager.primary2,
                      size: AppSize.s24,
                    ),
                    const SizedBox(width: AppSize.s12),
                    Expanded(
                      child: Text(
                        '${widget.request.fromLanguage} → ${widget.request.toLanguage}',
                        style: TextStyle(
                          fontSize: AppSize.s20,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.request.specialization != null) ...[
                  const SizedBox(height: AppSize.s12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s12,
                      vertical: AppSize.s6,
                    ),
                    decoration: BoxDecoration(
                      color: ColorManager.primary2,
                      borderRadius: BorderRadius.circular(AppSize.s16),
                    ),
                    child: Text(
                      widget.request.specialization!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppSize.s12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSize.s12),
                Text(
                  'Requested: ${widget.request.createdAt.toString().split('.')[0]}',
                  style: TextStyle(
                    color: ColorManager.textSecondary,
                    fontSize: AppSize.s12,
                  ),
                ),
              ],
            ),
          ),

          // Document content
          Expanded(
            child: SingleChildScrollView(
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
                        color: Colors.grey.withValues(alpha: 0.05),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSize.s16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.attach_file,
                            color: Colors.blue,
                            size: AppSize.s24,
                          ),
                          const SizedBox(width: AppSize.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Document file',
                                  style: const TextStyle(
                                    fontSize: AppSize.s14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: AppSize.s4),
                                Text(
                                  'Click to view or download',
                                  style: TextStyle(
                                    fontSize: AppSize.s12,
                                    color: Colors.blue.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // TODO: Open file viewer
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('File viewer coming soon!'),
                                ),
                              );
                            },
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

                  // Instructions for interpreter
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
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
                              'Accept & Translate',
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
}
