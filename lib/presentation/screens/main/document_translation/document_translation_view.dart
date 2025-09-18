import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/language.dart';

class DocumentTranslationView extends StatefulWidget {
  const DocumentTranslationView({super.key});

  @override
  State<DocumentTranslationView> createState() =>
      _DocumentTranslationViewState();
}

class _DocumentTranslationViewState extends State<DocumentTranslationView> {
  final TextEditingController _textController = TextEditingController();
  File? _selectedFile;
  Language? _selectedFromLanguage;
  Language? _selectedToLanguage;
  String? _selectedSpecialization;
  bool _isLoading = false;
  List<DocumentTranslationRequest> _userRequests = [];

  // Language selection variables
  List<Language> _languages = [];
  bool _isLoadingLanguages = true;

  final List<String> _specializations = [
    'Medical',
    'Legal',
    'Education',
    'Documentation',
    'Emergency Response',
    'Social Services',
    'Mental Health',
    'None of the Above',
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguages();
    _loadUserRequests();
  }

  Future<void> _loadLanguages() async {
    try {
      final languagesList = await SupabaseService().getLanguages();
      setState(() {
        _languages = languagesList;
        _isLoadingLanguages = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLanguages = false;
      });
    }
  }

  Future<void> _loadUserRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await DocumentTranslationService().getUserRequests();
      setState(() {
        _userRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedFromLanguage == null || _selectedToLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both languages')),
      );
      return;
    }

    if (_textController.text.trim().isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide text or upload a file')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DocumentTranslationService().createRequest(
        fromLanguage: _selectedFromLanguage!.name,
        toLanguage: _selectedToLanguage!.name,
        specialization: _selectedSpecialization,
        text: _textController.text.trim(),
        file: _selectedFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation request submitted successfully!'),
          ),
        );

        // Clear form
        _textController.clear();
        setState(() {
          _selectedFile = null;
          _selectedFromLanguage = null;
          _selectedToLanguage = null;
          _selectedSpecialization = null;
        });

        // Reload requests
        await _loadUserRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting request: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Translation'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSize.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language Selection
            _buildLanguageSelection(),
            const SizedBox(height: AppSize.s16),

            // Specialization Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSize.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Specialization (Optional)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Specialization',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedSpecialization,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No Specialization Required'),
                        ),
                        ..._specializations.map((spec) {
                          return DropdownMenuItem(
                            value: spec,
                            child: Text(spec),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSpecialization = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSize.s16),

            // Text Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSize.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Text to Translate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    TextField(
                      controller: _textController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Enter text to translate...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSize.s16),

            // File Upload
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSize.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Or Upload File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primary2,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: AppSize.s8),
                      Text(
                        'Selected: ${_selectedFile!.path.split('/').last}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSize.s16),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        'Submit Translation Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
            const SizedBox(height: AppSize.s24),

            // User Requests
            const Text(
              'Your Translation Requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSize.s16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_userRequests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSize.s16),
                  child: Text(
                    'No translation requests yet. Submit your first request above!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              ..._userRequests.map((request) => _buildRequestCard(request)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(DocumentTranslationRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSize.s8),
      child: ListTile(
        title: Text('${request.fromLanguage} → ${request.toLanguage}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${request.status}'),
            if (request.specialization != null)
              Text('Specialization: ${request.specialization}'),
            Text('Created: ${request.createdAt.toString().split('.')[0]}'),
          ],
        ),
        trailing: _getStatusIcon(request.status),
        onTap: () {
          // Navigate to chat view if accepted
          if (request.status == 'accepted') {
            // TODO: Navigate to chat view
          }
        },
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.schedule, color: Colors.orange);
      case 'accepted':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'completed':
        return const Icon(Icons.done_all, color: Colors.blue);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  Widget _buildLanguageSelection() {
    if (_isLoadingLanguages) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSize.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Language Pair',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSize.s16),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language Pair',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSize.s16),
            Column(
              children: [
                // From Language
                GestureDetector(
                  onTap: () => _showLanguageBottomSheet(true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: ColorManager.greyMedium,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              size: AppSize.s16,
                              color: ColorManager.primary2,
                            ),
                            const SizedBox(width: AppSize.s8),
                            Text(
                              'From',
                              style: TextStyle(
                                fontSize: AppSize.s12,
                                fontWeight: FontWeight.w500,
                                color: ColorManager.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSize.s8),
                        Text(
                          _selectedFromLanguage?.name ?? 'Select language',
                          style: TextStyle(
                            fontSize: AppSize.s14,
                            fontWeight: FontWeight.w600,
                            color:
                                _selectedFromLanguage != null
                                    ? ColorManager.textPrimary
                                    : ColorManager.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSize.s12),
                // Arrow
                Center(
                  child: Icon(
                    Icons.arrow_downward,
                    color: ColorManager.primary2,
                    size: AppSize.s20,
                  ),
                ),
                const SizedBox(height: AppSize.s12),
                // To Language
                GestureDetector(
                  onTap: () => _showLanguageBottomSheet(false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: ColorManager.greyMedium,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              size: AppSize.s16,
                              color: ColorManager.primary2,
                            ),
                            const SizedBox(width: AppSize.s8),
                            Text(
                              'To',
                              style: TextStyle(
                                fontSize: AppSize.s12,
                                fontWeight: FontWeight.w500,
                                color: ColorManager.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSize.s8),
                        Text(
                          _selectedToLanguage?.name ?? 'Select language',
                          style: TextStyle(
                            fontSize: AppSize.s14,
                            fontWeight: FontWeight.w600,
                            color:
                                _selectedToLanguage != null
                                    ? ColorManager.textPrimary
                                    : ColorManager.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(bool isFromLanguage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: ColorManager.backgroundPrimary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSize.s20),
              topRight: Radius.circular(AppSize.s20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppSize.s12),
                width: AppSize.s40,
                height: AppSize.s4,
                decoration: BoxDecoration(
                  color: ColorManager.greyMedium,
                  borderRadius: BorderRadius.circular(AppSize.s2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSize.s20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select ${isFromLanguage ? 'From' : 'To'} Language',
                      style: TextStyle(
                        fontSize: AppSize.s22,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: ColorManager.textSecondary,
                        size: AppSize.s24,
                      ),
                    ),
                  ],
                ),
              ),
              // Language Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSize.s20),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSize.s12,
                          mainAxisSpacing: AppSize.s12,
                          childAspectRatio: 2.5,
                        ),
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final language = _languages[index];
                      final isSelected =
                          isFromLanguage
                              ? _selectedFromLanguage?.id == language.id
                              : _selectedToLanguage?.id == language.id;

                      return GestureDetector(
                        onTap: () {
                          if (isFromLanguage) {
                            setState(() {
                              _selectedFromLanguage = language;
                            });
                          } else {
                            setState(() {
                              _selectedToLanguage = language;
                            });
                          }
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSize.s16,
                            vertical: AppSize.s12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? ColorManager.primary2
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(AppSize.s12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? ColorManager.primary2
                                      : ColorManager.greyMedium,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: AppSize.s8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.language,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : ColorManager.textSecondary,
                                size: AppSize.s18,
                              ),
                              const SizedBox(width: AppSize.s8),
                              Expanded(
                                child: Text(
                                  language.name,
                                  style: TextStyle(
                                    fontSize: AppSize.s10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : ColorManager.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
