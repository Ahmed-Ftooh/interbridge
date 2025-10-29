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
  // Removed unused _fileType field

  // Other state
  bool _isLoading = false;
  DateTime? _lastSubmitAt;
  List<DocumentTranslationRequest> _userRequests = [];
  List<Language> _languages = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLanguages();
    _loadUserRequests();
  }

  Future<void> _loadLanguages() async {
    try {
      final languagesList = await instance<SupabaseService>().getLanguages();
      setState(() {
        _languages = languagesList;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadUserRequests() async {
    try {
      final requests =
          await instance<DocumentTranslationService>().getUserRequests();
      final hiddenIds = await HiddenItemsService().getUserHiddenRequestIds();
      if (mounted) {
        setState(() {
          _userRequests =
              requests.where((r) => !hiddenIds.contains(r.id)).toList();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _selectedFromLanguage;
      _selectedFromLanguage = _selectedToLanguage;
      _selectedToLanguage = temp;
    });
  }

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
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewRequestTab(), _buildRequestsTab()],
      ),
    );
  }

  Widget _buildNewRequestTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Translation method selector
            _buildMethodSelector(),
            const SizedBox(height: AppSize.s24),

            // Language selection
            _buildLanguageSelection(),
            const SizedBox(height: AppSize.s24),

            // Content input (changes based on method)
            _buildContentInput(),
            const SizedBox(height: AppSize.s24),

            // Additional options
            _buildAdditionalOptions(),
            const SizedBox(height: AppSize.s32),

            // Submit button
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
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(AppSize.s12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 72) / 2,
        padding: const EdgeInsets.all(AppSize.s16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? ColorManager.primary2.withValues(alpha: 0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(AppSize.s12),
          border: Border.all(
            color: isSelected ? ColorManager.primary2 : ColorManager.greyMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icons[method],
              color:
                  isSelected
                      ? ColorManager.primary2
                      : ColorManager.textSecondary,
              size: 32,
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              labels[method]!,
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
        side: BorderSide(color: ColorManager.greyMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          children: [
            // From Language
            InkWell(
              onTap: () => _showLanguagePicker(true),
              child: Container(
                padding: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorManager.greyMedium),
                  borderRadius: BorderRadius.circular(AppSize.s12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, color: ColorManager.primary2),
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
                          const SizedBox(height: 4),
                          Text(
                            _selectedFromLanguage?.name ?? 'Select language',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
            const SizedBox(height: AppSize.s16),

            // Swap Button
            IconButton(
              onPressed: _swapLanguages,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorManager.primary2.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.swap_vert, color: ColorManager.primary2),
              ),
            ),
            const SizedBox(height: AppSize.s16),

            // To Language
            InkWell(
              onTap: () => _showLanguagePicker(false),
              child: Container(
                padding: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorManager.greyMedium),
                  borderRadius: BorderRadius.circular(AppSize.s12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, color: ColorManager.primary2),
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
                          const SizedBox(height: 4),
                          Text(
                            _selectedToLanguage?.name ?? 'Select language',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
          side: BorderSide(color: ColorManager.greyMedium),
        ),
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
                decoration: InputDecoration(
                  hintText: 'Type or paste your text here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                  ),
                  contentPadding: const EdgeInsets.all(AppSize.s16),
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
        side: BorderSide(color: ColorManager.greyMedium),
      ),
      child:
          _pickedFileName != null
              ? _buildFilePreview()
              : InkWell(
                onTap: () => _pickFile(),
                borderRadius: BorderRadius.circular(AppSize.s16),
                child: Padding(
                  padding: const EdgeInsets.all(AppSize.s32),
                  child: Column(
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
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildFilePreview() {
    return Padding(
      padding: const EdgeInsets.all(AppSize.s20),
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
            icon: const Icon(Icons.close),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  IconData _getFileTypeIcon() {
    switch (_selectedMethod) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'voice':
        return Icons.mic;
      default:
        return Icons.attach_file;
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'voice':
        return Icons.mic;
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.attach_file;
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
        return 'PDF files only';
      case 'image':
        return 'JPG, PNG, WEBP';
      case 'voice':
        return 'MP3, WAV, M4A';
      default:
        return 'Select a file';
    }
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        // Title
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title (Optional)',
            hintText: 'Give your request a title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
            ),
            prefixIcon: const Icon(Icons.title),
          ),
        ),
        const SizedBox(height: AppSize.s16),

        // Specialization
        _buildSpecializationChips(),
        const SizedBox(height: AppSize.s16),

        // Comment for interpreter
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Note to Interpreter (Optional)',
            hintText: 'Add any specific instructions...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSize.s12),
            ),
            prefixIcon: const Icon(Icons.note_outlined),
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
          spacing: AppSize.s12,
          runSpacing: AppSize.s12,
          children:
              _specializations.map((specialization) {
                final isSelected =
                    _selectedSpecialization == specialization['label'];
                return ChoiceChip(
                  label: Text(specialization['label'] as String),
                  avatar: Icon(
                    specialization['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : ColorManager.primary2,
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSpecialization =
                            specialization['label'] as String;
                      } else {
                        _selectedSpecialization = null;
                      }
                    });
                  },
                  selectedColor: ColorManager.primary2,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : ColorManager.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSize.s20),
                    side: BorderSide(
                      color:
                          isSelected
                              ? ColorManager.primary2
                              : ColorManager.greyMedium,
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.primary2,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          elevation: 0,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text(
                  'Submit Translation Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: ColorManager.textSecondary,
            ),
            const SizedBox(height: AppSize.s24),
            const Text(
              'No translation requests yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              'Your translation requests will appear here',
              style: TextStyle(color: ColorManager.textSecondary),
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSize.s12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(AppSize.s16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSize.s16),
            border: Border.all(
              color: _getStatusColor(request.status).withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        request.title ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (request.translationMethod != null &&
                              request.translationMethod != 'text')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorManager.primary2.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSize.s12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getMethodIcon(request.translationMethod!),
                                    size: 12,
                                    color: ColorManager.primary2,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    request.translationMethod!.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: ColorManager.primary2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSize.s12,
                              vertical: AppSize.s6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                request.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSize.s20),
                            ),
                            child: Text(
                              request.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(request.status),
                              ),
                            ),
                          ),
                          if (request.status == 'pending' ||
                              request.status == 'completed')
                            IconButton(
                              tooltip: 'Delete request',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: const Text('Delete request?'),
                                        content: const Text(
                                          'This will permanently remove the request.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm != true) return;
                                try {
                                  await instance<DocumentTranslationService>()
                                      .deleteRequest(request.id);
                                  await _loadUserRequests();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Request deleted'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                            )
                          else
                            IconButton(
                              tooltip: 'Remove from My Requests',
                              onPressed: () async {
                                await HiddenItemsService().hideUserRequest(
                                  request.id,
                                );
                                await _loadUserRequests();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Removed from My Requests'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSize.s12),
                Row(
                  children: [
                    Icon(
                      Icons.language,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSize.s16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: ColorManager.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(request.createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: ColorManager.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (request.specialization != null) ...[
                  const SizedBox(height: AppSize.s8),
                  Row(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 16,
                        color: ColorManager.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.specialization!,
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorManager.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showLanguagePicker(bool isFromLanguage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSize.s20),
                  topRight: Radius.circular(AppSize.s20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: AppSize.s12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ColorManager.greyMedium,
                      borderRadius: BorderRadius.circular(AppSize.s2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSize.s20),
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
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _languages.length,
                      itemBuilder: (context, index) {
                        final language = _languages[index];
                        final isSelected =
                            isFromLanguage
                                ? _selectedFromLanguage?.id == language.id
                                : _selectedToLanguage?.id == language.id;

                        return ListTile(
                          leading: Icon(
                            Icons.language,
                            color:
                                isSelected
                                    ? ColorManager.primary2
                                    : ColorManager.textSecondary,
                          ),
                          title: Text(
                            language.name,
                            style: TextStyle(
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              color:
                                  isSelected
                                      ? ColorManager.primary2
                                      : ColorManager.textPrimary,
                            ),
                          ),
                          trailing:
                              isSelected
                                  ? Icon(
                                    Icons.check,
                                    color: ColorManager.primary2,
                                  )
                                  : null,
                          onTap: () {
                            setState(() {
                              if (isFromLanguage) {
                                _selectedFromLanguage = language;
                              } else {
                                _selectedToLanguage = language;
                              }
                            });
                            Navigator.of(context).pop();
                          },
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
  }

  Future<void> _pickFile() async {
    FileType fileType;
    List<String> extensions;

    switch (_selectedMethod) {
      case 'pdf':
        fileType = FileType.custom;
        extensions = ['pdf'];
        break;
      case 'image':
        fileType = FileType.image;
        extensions = [];
        break;
      case 'voice':
        fileType = FileType.audio;
        extensions = [];
        break;
      default:
        fileType = FileType.any;
        extensions = [];
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: extensions.isEmpty ? null : extensions,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final localFile = File(file.path!);
        final fileSize = await localFile.length();

        setState(() {
          _pickedFilePath = file.path;
          _pickedFileName = file.name;
          _pickedFileSize = fileSize;
          // file type stored implicitly by selected method
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
    // Validation
    final now = DateTime.now();
    if (_lastSubmitAt != null &&
        now.difference(_lastSubmitAt!).inSeconds < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a few seconds before submitting again.'),
        ),
      );
      return;
    }
    if (_selectedFromLanguage == null || _selectedToLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both languages')),
      );
      return;
    }

    if (_selectedMethod == 'text' && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to translate')),
      );
      return;
    }

    if (_selectedMethod != 'text' && _pickedFilePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please upload a file')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      _lastSubmitAt = now;
      // Upload file if needed
      String? fileUrl;
      if (_selectedMethod != 'text' && _pickedFilePath != null) {
        fileUrl = await _uploadFile(_pickedFilePath!, _pickedFileName);
      }

      // Ensure voice filename has extension and derive fileType
      final adjustedFileName = await _ensureVoiceFilenameWithExt(
        _pickedFileName,
        _pickedFilePath,
      );
      final fileTypeForRequest =
          _selectedMethod != 'text'
              ? (adjustedFileName != null && adjustedFileName.contains('.')
                  ? adjustedFileName.split('.').last.toLowerCase()
                  : _selectedMethod)
              : null;

      // Create request
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
        fileUrl: fileUrl,
        fileType: fileTypeForRequest,
        fileName: adjustedFileName ?? _pickedFileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _clearForm();

        // Reload requests
        await _loadUserRequests();

        // Switch to requests tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting request: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _uploadFile(String path, String? fileName) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final file = File(path);
    if (!await file.exists()) throw Exception('File not found');

    final bytes = await file.readAsBytes();
    String originalName = fileName ?? path.split('/').last;
    // Ensure extension for voice uploads if missing by sniffing bytes
    if (_selectedMethod == 'voice' && !originalName.contains('.')) {
      final inferred = _inferAudioExtension(bytes) ?? 'm4a';
      originalName = '${originalName}.${inferred}';
    }
    final name = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
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
      case 'aac':
        contentType = 'audio/aac';
        break;
      case 'ogg':
        contentType = 'audio/ogg';
        break;
      case 'm3u8':
        contentType = 'application/vnd.apple.mpegurl';
        break;
      case 'm4a':
        contentType = 'audio/mp4';

        break;
      default:
        // Sensible default for voice without detected ext
        contentType =
            _selectedMethod == 'voice'
                ? 'audio/mp4'
                : 'application/octet-stream';
    }
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final objectPath =
        'requests/${user.id}/$dateStr/${DateTime.now().millisecondsSinceEpoch}_$name';

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
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
    return client.storage.from(bucket).getPublicUrl(objectPath);
  }

  // Heuristic: infer audio extension from magic bytes
  String? _inferAudioExtension(Uint8List bytes) {
    if (bytes.length >= 12) {
      // WAV: 'RIFF....WAVE'
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x41 &&
          bytes[10] == 0x56 &&
          bytes[11] == 0x45) {
        return 'wav';
      }
      // MP3: 'ID3' tag
      if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        return 'mp3';
      }
      // MP3 without ID3: frame sync 0xFFEx (E0..EF)
      if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
        return 'mp3';
      }
      // M4A/MP4: 'ftyp' at bytes 4..7
      if (bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) {
        return 'm4a';
      }
    }
    return null;
  }

  Future<String?> _ensureVoiceFilenameWithExt(
    String? fileName,
    String? path,
  ) async {
    if (_selectedMethod != 'voice') return fileName;
    final baseName = fileName ?? path?.split('/').last;
    if (baseName == null) return fileName;
    if (baseName.contains('.')) return baseName;
    if (path == null) return '${baseName}.m4a';
    try {
      final file = File(path);
      if (!await file.exists()) return '${baseName}.m4a';
      final bytes = await file.readAsBytes();
      final inferred = _inferAudioExtension(bytes) ?? 'm4a';
      return '${baseName}.${inferred}';
    } catch (_) {
      return '${baseName}.m4a';
    }
  }

  void _clearForm() {
    _titleController.clear();
    _textController.clear();
    _commentController.clear();
    _selectedFromLanguage = null;
    _selectedToLanguage = null;
    _selectedSpecialization = null;
    _selectedMethod = 'text';
    _pickedFilePath = null;
    _pickedFileName = null;
    _pickedFileSize = null;
  }

  void _showRequestDetails(DocumentTranslationRequest request) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(request.title ?? 'Translation Request'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSize.s12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getStatusIcon(request.status),
                          color: _getStatusColor(request.status),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          request.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(request.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.language,
                    '${request.fromLanguage} → ${request.toLanguage}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time,
                    _formatDate(request.createdAt),
                  ),
                  if (request.specialization != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.work_outline, request.specialization!),
                  ],
                  if (request.text != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Original Text:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      child: SelectableText(request.text!),
                    ),
                  ],
                  // Show attached file if any
                  if (request.fileUrl != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.attach_file, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'File attached: ${request.translationMethod ?? 'file'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Show translated file if available
                  if (request.translatedFileUrl != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Translated File:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Translation completed')),
                          TextButton(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: request.translatedFileUrl!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Download link copied to clipboard',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Copy Download Link'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (request.translatedText != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Translation:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      child: SelectableText(request.translatedText!),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: request.translatedText!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Translation'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (request.status == 'pending')
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
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ColorManager.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'accepted':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.info;
    }
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
        await _loadUserRequests();
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
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _textController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}
