// lib/presentation/screens/main/document_translation/document_translation_view.dart
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/app/di.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:interbridge/data/services/hidden_items_service.dart';
import 'package:interbridge/core/file_utility.dart'; // Import FileUtility for preview

class DocumentTranslationView extends StatefulWidget {
  const DocumentTranslationView({super.key});

  @override
  State<DocumentTranslationView> createState() =>
      _DocumentTranslationViewState();
}

class _DocumentTranslationViewState extends State<DocumentTranslationView>
    with SingleTickerProviderStateMixin {
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  // Language selection
  Language? _selectedFromLanguage;
  Language? _selectedToLanguage;

  // Translation method
  String _selectedMethod = 'text';
  final List<String> _methods = ['text', 'pdf', 'image', 'voice'];

  // Specialization
  String? _selectedSpecialization;
  final List<Map<String, dynamic>> _specializations = [
    {'label': 'Medical', 'icon': Icons.medical_services_outlined},
    {'label': 'Legal', 'icon': Icons.gavel_outlined},
    {'label': 'Education', 'icon': Icons.school_outlined},
    {'label': 'Documentation', 'icon': Icons.description_outlined},
    {'label': 'Emergency Response', 'icon': Icons.emergency_outlined},
    {'label': 'Social Services', 'icon': Icons.group_outlined},
    {'label': 'Mental Health', 'icon': Icons.psychology_outlined},
  ];

  // File upload state
  String? _pickedFilePath;
  String? _pickedFileName;
  int? _pickedFileSize;

  // Other state
  bool _isLoading = false;
  bool _isSubmitting = false;
  DateTime? _lastSubmitAt;
  List<DocumentTranslationRequest> _userRequests = [];
  List<Language> _languages = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _languages = await instance<SupabaseService>().getLanguages();
      await _loadUserRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading initial data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final languagesList = await instance<SupabaseService>().getLanguages();
      if (mounted) {
        setState(() {
          _languages = languagesList;
        });
      }
    } catch (e) {
      if (mounted) {
        // Optional error message
      }
    }
  }

  Future<void> _loadUserRequests() async {
    if (!mounted) return;
    if (!_isLoading) setState(() => _isLoading = true);
    try {
      final requests =
          await instance<DocumentTranslationService>().getUserRequests();
      final hiddenIds = await HiddenItemsService().getUserHiddenRequestIds();
      if (mounted) {
        setState(() {
          _userRequests =
              requests.where((r) => !hiddenIds.contains(r.id)).toList();
          _userRequests.sort((a, b) {
            if (a.status == 'pending' && b.status != 'pending') return -1;
            if (a.status != 'pending' && b.status == 'pending') return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _selectedFromLanguage;
      _selectedFromLanguage = _selectedToLanguage;
      _selectedToLanguage = temp;
    });
  }

  // --- *** ADDED: Missing helper function *** ---
  String _getTranslationMethodLabel(String? method) {
    switch (method?.toLowerCase()) {
      // Use lowerCase for safety
      case 'text':
        return 'Text';
      case 'pdf': // Still show PDF in UI for clarity
        return 'PDF';
      case 'document': // This is what might be stored if 'pdf' was chosen
        return 'Document';
      case 'image':
        return 'Image';
      case 'voice':
        return 'Voice'; // Added voice
      default:
        return 'File'; // Fallback
    }
  }
  // --- *** END ADDED FUNCTION *** ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.documentTranslation),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'New Request'), Tab(text: 'My Requests')],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewRequestTab(), _buildRequestsTab()],
      ),
    );
  }

  Widget _buildNewRequestTab() {
    // ... (rest of the build methods remain the same as previous correct version)
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMethodSelector(),
            const SizedBox(height: AppSize.s24),
            _buildLanguageSelection(),
            const SizedBox(height: AppSize.s24),
            _buildContentInput(),
            const SizedBox(height: AppSize.s24),
            _buildAdditionalOptions(),
            const SizedBox(height: AppSize.s32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What would you like to translate?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSize.s16),
        Wrap(
          spacing: AppSize.s12,
          runSpacing: AppSize.s12,
          children: _methods.map((method) => _buildMethodCard(method)).toList(),
        ),
      ],
    );
  }

  Widget _buildMethodCard(String method) {
    final isSelected = _selectedMethod == method;
    final icons = {
      'text': Icons.text_fields,
      'pdf': Icons.picture_as_pdf,
      'image': Icons.image,
      'voice': Icons.mic,
    };
    final labels = {
      'text': 'Text',
      'pdf': 'PDF',
      'image': 'Image',
      'voice': 'Voice',
    };

    return InkWell(
      onTap: () {
        if (_selectedMethod != method) {
          setState(() {
            _selectedMethod = method;
            if (method == 'text' || _pickedFilePath != null) {
              _pickedFilePath = null;
              _pickedFileName = null;
              _pickedFileSize = null;
            }
            if (method != 'text') {
              _textController.clear();
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(AppSize.s12),
      child: Container(
        width:
            (MediaQuery.of(context).size.width -
                (AppSize.s20 * 2) -
                (AppSize.s12 * (_methods.length / 2 - 1))) /
            2,
        padding: const EdgeInsets.all(AppSize.s16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? ColorManager.primary2.withOpacity(0.1)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppSize.s12),
          border: Border.all(
            color: isSelected ? ColorManager.primary2 : ColorManager.greyMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icons[method] ?? Icons.help_outline,
              color:
                  isSelected
                      ? ColorManager.primary2
                      : ColorManager.textSecondary,
              size: 32,
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              labels[method] ?? 'Unknown',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color:
                    isSelected
                        ? ColorManager.primary2
                        : ColorManager.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
        side: BorderSide(color: ColorManager.greyLight),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          children: [
            InkWell(
              onTap: () => _showLanguagePicker(true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.s16,
                  vertical: AppSize.s12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorManager.greyMedium),
                  borderRadius: BorderRadius.circular(AppSize.s12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: ColorManager.primary2,
                      size: 20,
                    ),
                    const SizedBox(width: AppSize.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorManager.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedFromLanguage?.name ?? 'Select language',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  _selectedFromLanguage != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              color:
                                  _selectedFromLanguage != null
                                      ? ColorManager.textPrimary
                                      : ColorManager.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: ColorManager.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSize.s8),
              child: Center(
                child: IconButton(
                  onPressed:
                      (_selectedFromLanguage != null ||
                              _selectedToLanguage != null)
                          ? _swapLanguages
                          : null,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorManager.primary2.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swap_vert,
                      color: ColorManager.primary2,
                      size: 24,
                    ),
                  ),
                  tooltip: 'Swap Languages',
                ),
              ),
            ),
            InkWell(
              onTap: () => _showLanguagePicker(false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.s16,
                  vertical: AppSize.s12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorManager.greyMedium),
                  borderRadius: BorderRadius.circular(AppSize.s12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: ColorManager.primary2,
                      size: 20,
                    ),
                    const SizedBox(width: AppSize.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorManager.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedToLanguage?.name ?? 'Select language',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  _selectedToLanguage != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              color:
                                  _selectedToLanguage != null
                                      ? ColorManager.textPrimary
                                      : ColorManager.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: ColorManager.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentInput() {
    if (_selectedMethod == 'text') {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSize.s16),
          side: BorderSide(color: ColorManager.greyLight),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSize.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Text to Translate',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSize.s16),
              TextField(
                controller: _textController,
                maxLines: 8,
                minLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type or paste your text here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    borderSide: BorderSide(color: ColorManager.greyMedium),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    borderSide: BorderSide(color: ColorManager.greyMedium),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    borderSide: BorderSide(
                      color: ColorManager.primary2,
                      width: 2.0,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(AppSize.s16),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return _buildFileUploadCard();
    }
  }

  Widget _buildFileUploadCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
        side: BorderSide(color: ColorManager.greyLight),
      ),
      color: Colors.white,
      child:
          _pickedFileName != null
              ? _buildFilePreview()
              : InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(AppSize.s16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSize.s32,
                    horizontal: AppSize.s20,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSize.s16),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileTypeIcon(),
                        size: 64,
                        color: ColorManager.primary2,
                      ),
                      const SizedBox(height: AppSize.s16),
                      const Text(
                        'Tap to upload file',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSize.s8),
                      Text(
                        _getFileTypeHint(),
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorManager.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSize.s16),
        color: Colors.grey.shade50,
        border: Border.all(color: ColorManager.greyLight),
      ),
      child: Row(
        children: [
          Icon(
            _getMethodIcon(_selectedMethod),
            size: 48,
            color: ColorManager.primary2,
          ),
          const SizedBox(width: AppSize.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickedFileName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_pickedFileSize != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatFileSize(_pickedFileSize!),
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed:
                () => setState(() {
                  _pickedFilePath = null;
                  _pickedFileName = null;
                  _pickedFileSize = null;
                }),
            icon: const Icon(Icons.close_rounded),
            color: Colors.red.shade700,
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }

  IconData _getFileTypeIcon() {
    switch (_selectedMethod) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'voice':
        return Icons.mic_none_outlined;
      default:
        return Icons.attach_file_outlined;
    }
  }

  IconData _getMethodIcon(String? method) {
    // Make method nullable
    switch (method?.toLowerCase()) {
      // Use null-safe lowercase
      case 'pdf':
      case 'document': // Treat document like pdf for icon
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'voice':
        return Icons.mic;
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.attach_file; // Default file icon
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String _getFileTypeHint() {
    switch (_selectedMethod) {
      case 'pdf':
        return 'Allowed formats: .pdf (Max 25MB)'; // Example size limit
      case 'image':
        return 'Allowed formats: .jpg, .png, .webp (Max 10MB)';
      case 'voice':
        return 'Allowed formats: .mp3, .wav, .m4a (Max 15MB)';
      default:
        return 'Select a file';
    }
  }

  Widget _buildAdditionalOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Title (Optional)',
            hintText: 'Give your request a short title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.greyMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.greyMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.primary2, width: 2.0),
            ),
            prefixIcon: const Icon(Icons.title_outlined), // Use outlined icon
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSize.s16,
              vertical: AppSize.s12,
            ),
          ),
        ),
        const SizedBox(height: AppSize.s24),
        _buildSpecializationChips(),
        const SizedBox(height: AppSize.s24),
        TextField(
          controller: _commentController,
          maxLines: 3,
          minLines: 2,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Note to Interpreter (Optional)',
            hintText: 'Add any specific instructions or context...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.greyMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.greyMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
              borderSide: BorderSide(color: ColorManager.primary2, width: 2.0),
            ),
            prefixIcon: const Align(
              widthFactor: 1.0,
              heightFactor: 1.0,
              alignment: Alignment.topLeft, // Align icon top-left
              child: Padding(
                padding: EdgeInsets.only(top: AppSize.s12, left: AppSize.s12),
                child: Icon(Icons.note_alt_outlined),
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(AppSize.s16),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecializationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialization (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s12),
        Wrap(
          spacing: AppSize.s8,
          runSpacing: AppSize.s8,
          children:
              _specializations.map((specialization) {
                final String label = specialization['label'] as String;
                final IconData icon = specialization['icon'] as IconData;
                final bool isSelected = _selectedSpecialization == label;

                return ChoiceChip(
                  label: Text(label),
                  avatar: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : ColorManager.primary2,
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedSpecialization = selected ? label : null;
                    });
                  },
                  selectedColor: ColorManager.primary2,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : ColorManager.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSize.s10,
                    vertical: AppSize.s6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSize.s20),
                    side: BorderSide(
                      color:
                          isSelected
                              ? ColorManager.primary2
                              : ColorManager.greyMedium,
                    ),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.primary2,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          elevation: 2,
        ),
        icon:
            _isSubmitting
                ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Icon(
                  Icons.send_outlined,
                  size: 20,
                ), // Adjusted icon size
        label: Text(
          _isSubmitting ? 'Submitting...' : 'Submit Translation Request',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading && _userRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadUserRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: ColorManager.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppSize.s24),
                  const Text(
                    'No translation requests yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: AppSize.s8),
                  Text(
                    'Your submitted requests will appear here.\nPull down to refresh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ColorManager.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSize.s16),
        itemCount: _userRequests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(_userRequests[index]);
        },
      ),
    );
  }

  Widget _buildRequestCard(DocumentTranslationRequest request) {
    final statusColor = _getStatusColor(request.status);
    final statusIcon = _getStatusIcon(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSize.s12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(AppSize.s12),
        child: Padding(
          padding: const EdgeInsets.all(AppSize.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title ?? 'Untitled Request',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSize.s8),
                        Row(
                          children: [
                            Icon(
                              Icons.translate,
                              size: 16,
                              color: ColorManager.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${request.fromLanguage} → ${request.toLanguage}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ColorManager.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSize.s12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.s10,
                      vertical: AppSize.s4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSize.s20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          request.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSize.s12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: AppSize.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Center items vertically
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMethodIcon(
                          request.translationMethod,
                        ), // Use updated helper
                        size: 16,
                        color: ColorManager.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        // Use the label function here
                        _getTranslationMethodLabel(request.translationMethod),
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorManager.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  if (request.specialization != null &&
                      request.specialization!.isNotEmpty)
                    Flexible(
                      child: Padding(
                        // Add padding to separate specialization if needed
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center, // Center if space allows
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 16,
                              color: ColorManager.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                request.specialization!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ColorManager.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: ColorManager.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(request.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorManager.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade700;
      case 'accepted':
        return Colors.blue.shade700;
      case 'pending':
        return Colors.orange.shade800;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'accepted':
        return Icons.hourglass_bottom_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showLanguagePicker(bool isFromLanguage) {
    if (_languages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Languages not loaded yet.')),
      );
      _loadLanguages();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            String searchQuery = '';
            List<Language> filteredLanguages =
                _languages.where((lang) {
                  return lang.name.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
                }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSize.s20),
                      topRight: Radius.circular(AppSize.s20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(
                          top: AppSize.s12,
                          bottom: AppSize.s8,
                        ),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ColorManager.greyMedium,
                          borderRadius: BorderRadius.circular(AppSize.s2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSize.s20,
                          AppSize.s8,
                          AppSize.s8,
                          AppSize.s12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select ${isFromLanguage ? "Source" : "Target"} Language',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSize.s20,
                          vertical: AppSize.s8,
                        ),
                        child: TextField(
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                              filteredLanguages =
                                  _languages.where((lang) {
                                    return lang.name.toLowerCase().contains(
                                      searchQuery.toLowerCase(),
                                    );
                                  }).toList();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search language...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              borderSide: BorderSide(
                                color: ColorManager.greyMedium,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              borderSide: BorderSide(
                                color: ColorManager.greyMedium,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              borderSide: BorderSide(
                                color: ColorManager.primary2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSize.s16,
                              vertical: AppSize.s10,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      Expanded(
                        child:
                            filteredLanguages.isEmpty
                                ? Center(
                                  child: Text(
                                    'No languages found for "$searchQuery"',
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filteredLanguages.length,
                                  itemBuilder: (context, index) {
                                    final language = filteredLanguages[index];
                                    final bool isCurrentlySelected =
                                        isFromLanguage
                                            ? _selectedFromLanguage?.id ==
                                                language.id
                                            : _selectedToLanguage?.id ==
                                                language.id;

                                    return ListTile(
                                      leading: Icon(
                                        Icons.language,
                                        color:
                                            isCurrentlySelected
                                                ? ColorManager.primary2
                                                : ColorManager.textSecondary,
                                      ),
                                      title: Text(
                                        language.name,
                                        style: TextStyle(
                                          fontWeight:
                                              isCurrentlySelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color:
                                              isCurrentlySelected
                                                  ? ColorManager.primary2
                                                  : ColorManager.textPrimary,
                                        ),
                                      ),
                                      trailing:
                                          isCurrentlySelected
                                              ? Icon(
                                                Icons.check_circle,
                                                color: ColorManager.primary2,
                                                size: 20,
                                              )
                                              : null,
                                      onTap: () {
                                        setState(() {
                                          if (isFromLanguage) {
                                            _selectedFromLanguage = language;
                                            if (_selectedToLanguage?.id ==
                                                language.id) {
                                              _selectedToLanguage = null;
                                            }
                                          } else {
                                            _selectedToLanguage = language;
                                            if (_selectedFromLanguage?.id ==
                                                language.id) {
                                              _selectedFromLanguage = null;
                                            }
                                          }
                                        });
                                        Navigator.of(context).pop();
                                      },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSize.s24,
                                          ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickFile() async {
    FileType fileType;
    List<String>? allowedExtensions;

    switch (_selectedMethod) {
      case 'pdf':
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
        break;
      case 'image':
        fileType = FileType.image;
        allowedExtensions = null;
        break;
      case 'voice':
        fileType = FileType.audio;
        allowedExtensions = null;
        break;
      default:
        fileType = FileType.any;
        allowedExtensions = null;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final localFile = File(file.path!);
        final fileSize = await localFile.length();

        // Add size validation based on type
        int maxSize;
        String typeLabel;
        switch (_selectedMethod) {
          case 'pdf':
            maxSize = 25 * 1024 * 1024;
            typeLabel = 'PDF';
            break; // 25MB
          case 'image':
            maxSize = 10 * 1024 * 1024;
            typeLabel = 'Image';
            break; // 10MB
          case 'voice':
            maxSize = 15 * 1024 * 1024;
            typeLabel = 'Voice';
            break; // 15MB
          default:
            maxSize = 25 * 1024 * 1024;
            typeLabel = 'File'; // Default limit
        }

        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$typeLabel exceeds maximum size (${(maxSize / (1024 * 1024)).toStringAsFixed(0)} MB)',
                ),
              ),
            );
          }
          return; // Stop processing if file is too large
        }

        setState(() {
          _pickedFilePath = file.path;
          _pickedFileName = file.name;
          _pickedFileSize = fileSize;
        });
      } else {
        if (mounted) {
          // User cancelled
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    final now = DateTime.now();
    if (_lastSubmitAt != null && now.difference(_lastSubmitAt!).inSeconds < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before submitting again.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_selectedFromLanguage == null || _selectedToLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both source and target languages.'),
        ),
      );
      return;
    }

    bool hasContent = false;
    if (_selectedMethod == 'text') {
      if (_textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the text you want to translate.'),
          ),
        );
        return;
      }
      hasContent = true;
    } else {
      if (_pickedFilePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please upload a $_selectedMethod file to translate.',
            ),
          ),
        );
        return;
      }
      hasContent = true;
    }

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide content (text or file) to translate.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      _lastSubmitAt = now;
      String? uploadedFileUrl;

      if (_selectedMethod != 'text' && _pickedFilePath != null) {
        uploadedFileUrl = await _uploadFile(_pickedFilePath!, _pickedFileName);
        if (uploadedFileUrl == null && mounted) {
          throw Exception('File upload failed. Please try again.');
        }
      }

      await instance<DocumentTranslationService>().createRequest(
        fromLanguage: _selectedFromLanguage!.name,
        toLanguage: _selectedToLanguage!.name,
        specialization: _selectedSpecialization,
        text: _selectedMethod == 'text' ? _textController.text.trim() : null,
        title:
            _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
        comment:
            _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
        translationMethod: _selectedMethod,
        fileUrl: uploadedFileUrl,
        fileType: null,
        fileName: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
        await _loadUserRequests();
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: ${e.toString()}'),
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

  Future<String?> _uploadFile(String path, String? fileName) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final file = File(path);
      if (!await file.exists())
        throw Exception('File not found at path: $path');

      final bytes = await file.readAsBytes();
      final originalName = fileName ?? path.split(Platform.pathSeparator).last;
      final safeName = originalName.replaceAll(RegExp(r'[^\w\.-]+'), '_');

      final ext = safeName.split('.').last.toLowerCase();
      String contentType = _getMimeTypeFromExtension(ext);

      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final objectPath =
          'requests/${user.id}/$dateStr/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      String bucket = 'doucment';
      String fallbackBucket = 'documents';

      try {
        await client.storage
            .from(bucket)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(upsert: false, contentType: contentType),
            );
        return client.storage.from(bucket).getPublicUrl(objectPath);
      } catch (e) {
        print(
          'Error uploading to primary bucket ($bucket): $e. Trying fallback ($fallbackBucket)...',
        );
        try {
          await client.storage
              .from(fallbackBucket)
              .uploadBinary(
                objectPath,
                bytes,
                fileOptions: FileOptions(
                  upsert: false,
                  contentType: contentType,
                ),
              );
          return client.storage.from(fallbackBucket).getPublicUrl(objectPath);
        } catch (e2) {
          print('Error uploading to fallback bucket ($fallbackBucket): $e2');
          throw Exception(
            'Failed to upload file to both primary and fallback storage buckets.',
          );
        }
      }
    } catch (e) {
      print('Error preparing file upload: $e');
      return null;
    }
  }

  String _getMimeTypeFromExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'heic':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }

  void _clearForm() {
    _titleController.clear();
    _textController.clear();
    _commentController.clear();
    if (mounted) {
      setState(() {
        _selectedFromLanguage = null;
        _selectedToLanguage = null;
        _selectedSpecialization = null;
        _selectedMethod = 'text';
        _pickedFilePath = null;
        _pickedFileName = null;
        _pickedFileSize = null;
      });
    }
  }

  void _showRequestDetails(DocumentTranslationRequest request) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(request.title ?? 'Translation Request Details'),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(request.status),
                            color: _getStatusColor(request.status),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            request.status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(request.status),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 16),

                  _buildDetailRow(
                    Icons.translate_outlined,
                    'Language Pair',
                    '${request.fromLanguage} → ${request.toLanguage}',
                  ),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Requested On',
                    _formatDate(request.createdAt),
                  ),
                  if (request.specialization != null)
                    _buildDetailRow(
                      Icons.work_outline_rounded,
                      'Specialization',
                      request.specialization!,
                    ),
                  if (request.comment != null && request.comment!.isNotEmpty)
                    _buildDetailRow(
                      Icons.note_alt_outlined,
                      'Note',
                      request.comment!,
                    ),

                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 16),

                  const Text(
                    "Original Content",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (request.text != null && request.text!.isNotEmpty)
                    _buildSelectableTextBox(request.text!, isOriginal: true),
                  if (request.fileUrl != null)
                    _buildFileLinkBox(
                      context: context,
                      fileUrl: request.fileUrl!,
                      fileName: request.fileName,
                      method: request.translationMethod,
                      isOriginal: true,
                    ),

                  if (request.status == 'completed') ...[
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      "Translation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (request.translatedText != null &&
                        request.translatedText!.isNotEmpty)
                      _buildSelectableTextBox(
                        request.translatedText!,
                        isOriginal: false,
                      ),
                    if (request.translatedFileUrl != null)
                      _buildFileLinkBox(
                        context: context,
                        fileUrl: request.translatedFileUrl!,
                        fileName: "Translated File",
                        method:
                            null, // Method might not apply to translated file type
                        isOriginal: false,
                      ),
                    if ((request.translatedText == null ||
                            request.translatedText!.isEmpty) &&
                        request.translatedFileUrl == null)
                      const Padding(
                        // Add padding for better spacing
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "No translation content provided.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
            actions: [
              // Delete Button (Conditionally Shown)
              if (request.status == 'pending' || request.status == 'completed')
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _confirmAndDeleteRequest(request);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              // Close Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
            buttonPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            actionsAlignment: MainAxisAlignment.end,
          ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6.0,
      ), // Increased vertical padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ColorManager.textSecondary),
          const SizedBox(width: 12),
          // Use SizedBox for consistent label width (optional, adjust width as needed)
          SizedBox(
            width: 100, // Adjust width as needed for alignment
            child: Text(
              '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorManager.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, height: 1.3),
            ),
          ), // Improve line spacing for value
        ],
      ),
    );
  }

  Widget _buildSelectableTextBox(String text, {required bool isOriginal}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOriginal ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(AppSize.s8),
        border: Border.all(
          color: isOriginal ? Colors.grey.shade300 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(text, style: const TextStyle(height: 1.4)),
          if (!isOriginal)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Translation copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileLinkBox({
    required BuildContext context,
    required String fileUrl,
    String? fileName,
    String? method,
    required bool isOriginal,
  }) {
    // --- **FIX:** Use _getMethodIcon to get the icon based on method string ---
    IconData fileIcon = _getMethodIcon(method);
    // -------------------------------------------------------------------------
    Color fileColor = isOriginal ? Colors.blue.shade700 : Colors.green.shade700;
    String defaultLabel =
        isOriginal
            ? _getTranslationMethodLabel(method)
            : "Translated File"; // Use label function

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: fileColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSize.s8),
        border: Border.all(color: fileColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(fileIcon, color: fileColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName ??
                  defaultLabel, // Use filename if available, else the generated label
              style: TextStyle(fontWeight: FontWeight.w500, color: fileColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
              foregroundColor: fileColor,
            ),
            onPressed: () {
              FileUtility.openFilePreview(
                context,
                fileUrl,
                method,
                fileName,
                null,
              );
            },
            child: Text(
              isOriginal ? 'View' : 'Open',
            ), // Changed 'Download' to 'Open' for clarity
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteRequest(
    DocumentTranslationRequest request,
  ) async {
    if (!mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete the request "${request.title ?? 'Untitled Request'}"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteRequest(request);
    }
  }

  Future<void> _deleteRequest(DocumentTranslationRequest request) async {
    if (!mounted) return;

    try {
      await instance<DocumentTranslationService>().deleteRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request "${request.title ?? 'Untitled Request'}" deleted.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // No need to manually remove, _loadUserRequests will refresh the list from DB
        await _loadUserRequests(); // Refresh list after deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _textController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}
