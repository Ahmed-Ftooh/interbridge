import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/app/di.dart';
import 'package:flutter/services.dart';

class InterpreterTranslationView extends StatefulWidget {
  final DocumentTranslationRequest request;

  const InterpreterTranslationView({super.key, required this.request});

  @override
  State<InterpreterTranslationView> createState() =>
      _InterpreterTranslationViewState();
}

class _InterpreterTranslationViewState
    extends State<InterpreterTranslationView> {
  final TextEditingController _translatedTextController =
      TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with original text for reference
    if (widget.request.text != null && widget.request.text!.isNotEmpty) {
      _translatedTextController.text = widget.request.text!;
    }
  }

  Future<void> _submitTranslation() async {
    if (_translatedTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide translated text'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await instance<DocumentTranslationService>().completeRequest(
        requestId: widget.request.id,
        translatedText: _translatedTextController.text.trim(),
      );

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate Document'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        actions: [
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
              color: ColorManager.primary2.withValues(alpha: 0.1),
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
                  child: Text(
                    '${widget.request.fromLanguage} → ${widget.request.toLanguage}',
                    style: TextStyle(
                      fontSize: AppSize.s20,
                      fontWeight: FontWeight.bold,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                ),
                if (widget.request.specialization != null) ...[
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
                          color: ColorManager.textSecondary,
                        ),
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
                    },
                  ),
                  const SizedBox(height: AppSize.s20),

                  const SizedBox(height: AppSize.s24),

                  // Instructions
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
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: AppSize.s20,
                              width: AppSize.s20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: AppSize.s12),
                            Text(
                              'Submitting...',
                              style: TextStyle(
                                fontSize: AppSize.s16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    _translatedTextController.dispose();
    super.dispose();
  }
}
