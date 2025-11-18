// lib/presentation/screens/main/document_translation/document_translation_view.dart
import 'dart:async';
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
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
// Import FileUtility for preview
import 'package:flutter_bloc/flutter_bloc.dart'; // <-- Add bloc import
import 'bloc/document_translation_bloc.dart';
import 'bloc/document_translation_event.dart';
import 'bloc/document_translation_state.dart';
import 'shared/helpers.dart';
import 'shared/shared_file_link_box.dart';
import 'package:interbridge/presentation/widgets/language_pair_selector.dart';

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
  bool _isUploading = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _recordedFilePath;
  String? _currentRecordingPath;

  // Other state
  DateTime? _lastSubmitAt;
  List<DocumentTranslationRequest> _userRequests = [];
  List<Language> _languages = [];

  late TabController _tabController;
  late DocumentTranslationBloc _bloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bloc = DocumentTranslationBloc(
      translationService: instance<DocumentTranslationService>(),
      supabaseService: instance<SupabaseService>(),
    );
    _bloc.add(LoadLanguages());
    _bloc.add(LoadUserRequests());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<DocumentTranslationBloc, DocumentTranslationState>(
        listener: (context, state) {
          if (state is DocumentTranslationOperationSuccess) {
            _clearForm();
            _bloc.add(LoadUserRequests());
            _tabController.animateTo(1);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Operation successful'),
                backgroundColor: Colors.green,
              ),
            );
          }
          if (state is DocumentTranslationOperationFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          bool isLoading = state is DocumentTranslationLoading;
          List<Language> langs =
              state is DocumentTranslationLoadSuccess
                  ? state.languages
                  : _languages;
          List<DocumentTranslationRequest> requests =
              state is DocumentTranslationLoadSuccess
                  ? state.requests
                  : _userRequests;

          // Fallback to controller state ONLY if bloc not yet loaded.
          if (state is DocumentTranslationLoadSuccess) {
            _languages = langs;
            _userRequests = requests;
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text(AppStrings.documentTranslation),
              backgroundColor: ColorManager.primary2,
              foregroundColor: Colors.white,
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'New Request'),
                  Tab(text: 'My Requests'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildNewRequestTab(isLoading: isLoading, langs: langs),
                _buildRequestsTab(isLoading: isLoading, requests: requests),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewRequestTab({
    bool isLoading = false,
    required List<Language> langs,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMethodSelector(),
            const SizedBox(height: AppSize.s24),
            _buildLanguageSelection(langs: langs),
            const SizedBox(height: AppSize.s24),
            _buildContentInput(),
            const SizedBox(height: AppSize.s24),
            _buildAdditionalOptions(),
            const SizedBox(height: AppSize.s32),
            _buildSubmitButton(isLoading: isLoading || _isUploading),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMethodSelection(String method) async {
    if (_selectedMethod == method) return;
    if (_selectedMethod == 'voice') {
      await _stopRecording(saveClip: false);
      _clearRecordedClip();
    }
    if (_isRecording) {
      await _stopRecording(saveClip: false);
    }
    setState(() {
      _selectedMethod = method;
      if (method == 'text') {
        _clearSelectedFile();
      } else {
        _textController.clear();
        _clearSelectedFile();
      }
    });
  }

  void _clearSelectedFile() {
    _pickedFilePath = null;
    _pickedFileName = null;
    _pickedFileSize = null;
    _recordedFilePath = null;
  }

  void _clearRecordedClip() {
    _recordedFilePath = null;
    _currentRecordingPath = null;
    _recordDuration = Duration.zero;
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          _showSnackBar('Microphone permission required to record audio.');
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/translation_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = path;
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {
          _recordDuration += const Duration(seconds: 1);
        }),
      );
    } catch (e) {
      _showSnackBar('Unable to start recording: $e', isError: true);
    }
  }

  Future<void> _stopRecording({bool saveClip = true}) async {
    final stillRecording = await _audioRecorder.isRecording();
    if (!_isRecording && !stillRecording) {
      return;
    }
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      final resolvedPath = path ?? _currentRecordingPath;
      if (!mounted) return;
      if (!saveClip) {
        if (resolvedPath != null) {
          final file = File(resolvedPath);
          if (await file.exists()) await file.delete();
        }
        setState(() {
          _isRecording = false;
          _recordDuration = Duration.zero;
          _currentRecordingPath = null;
        });
        return;
      }
      if (resolvedPath == null) {
        setState(() {
          _isRecording = false;
          _recordDuration = Duration.zero;
          _currentRecordingPath = null;
        });
        return;
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        setState(() {
          _isRecording = false;
          _recordDuration = Duration.zero;
          _currentRecordingPath = null;
        });
        return;
      }

      final size = await file.length();
      setState(() {
        _pickedFilePath = resolvedPath;
        _pickedFileName = resolvedPath.split(Platform.pathSeparator).last;
        _pickedFileSize = size;
        _recordedFilePath = resolvedPath;
        _isRecording = false;
        _recordDuration = Duration.zero;
        _currentRecordingPath = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
        _currentRecordingPath = null;
      });
      _showSnackBar('Unable to stop recording: $e', isError: true);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
      onTap: () => _handleMethodSelection(method),
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

  Widget _buildLanguageSelection({required List<Language> langs}) {
    return LanguagePairSelector(
      languages: langs,
      fromLanguage: _selectedFromLanguage,
      toLanguage: _selectedToLanguage,
      onFromChanged: (lang) => setState(() => _selectedFromLanguage = lang),
      onToChanged: (lang) => setState(() => _selectedToLanguage = lang),
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
    }

    if (_selectedMethod == 'voice') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVoiceRecorderCard(),
          const SizedBox(height: AppSize.s16),
          _buildFileUploadCard(),
        ],
      );
    }

    return _buildFileUploadCard();
  }

  Widget _buildVoiceRecorderCard() {
    final hasRecordedClip =
        _recordedFilePath != null && _recordedFilePath == _pickedFilePath;
    final isRecording = _isRecording;

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
            Row(
              children: [
                Icon(Icons.mic_none_outlined, color: ColorManager.primary2),
                const SizedBox(width: AppSize.s12),
                Expanded(
                  child: Text(
                    'Record a voice note',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s12),
            Text(
              'Capture up to a few minutes of audio without leaving the app. Tap stop to attach the clip automatically.',
              style: TextStyle(color: ColorManager.textSecondary),
            ),
            const SizedBox(height: AppSize.s16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isRecording
                            ? () => _stopRecording(saveClip: true)
                            : _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isRecording ? Colors.red : ColorManager.primary2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSize.s14,
                      ),
                    ),
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    label: Text(
                      isRecording ? 'Stop & attach' : 'Start recording',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                if (hasRecordedClip)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSize.s12),
                    child: Icon(
                      Icons.check_circle,
                      color: ColorManager.primary2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              isRecording
                  ? 'Recording… ${_formatDuration(_recordDuration)}'
                  : hasRecordedClip
                  ? 'Recorded clip ready—see the file preview below.'
                  : 'No recording yet. You can also upload an existing audio file.',
              style: TextStyle(
                color:
                    isRecording
                        ? Colors.red.shade600
                        : ColorManager.textSecondary,
                fontWeight: isRecording ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasRecordedClip)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _clearSelectedFile();
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard recording'),
                ),
              ),
          ],
        ),
      ),
    );
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
                  _recordedFilePath = null;
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

  Widget _buildSubmitButton({bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _submitRequest,
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
            isLoading
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
          isLoading || _isUploading
              ? _isUploading
                  ? 'Uploading...'
                  : 'Submitting...'
              : 'Submit Translation Request',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : ColorManager.primary2,
      ),
    );
  }

  Widget _buildRequestsTab({
    bool isLoading = false,
    List<DocumentTranslationRequest> requests = const [],
  }) {
    if (isLoading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          _bloc.add(LoadUserRequests());
        },
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
      onRefresh: () async {
        _bloc.add(LoadUserRequests());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSize.s16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(requests[index]);
        },
      ),
    );
  }

  Widget _buildRequestCard(DocumentTranslationRequest request) {
    final statusColor = getStatusColor(request.status);
    final statusIcon = getStatusIcon(request.status);

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
                        getTranslationMethodLabel(request.translationMethod),
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
                        formatDt(request.createdAt),
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

  // Legacy picker method removed in favor of reusable LanguagePairSelector.

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
      if (_isRecording) {
        await _stopRecording(saveClip: false);
      }
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
          _recordedFilePath = null;
          _currentRecordingPath = null;
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
    if (_isRecording) {
      _showSnackBar('Please stop the recording before submitting.');
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
    String? uploadedUrl;
    String? mimeType;
    if (_pickedFilePath != null) {
      setState(() => _isUploading = true);
      try {
        uploadedUrl = await _uploadFile(_pickedFilePath!, _pickedFileName);
        if (_pickedFileName != null) {
          mimeType = _getMimeTypeFromExtension(
            _pickedFileName!.split('.').last,
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
    _bloc.add(
      SubmitRequest(
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
        fileUrl: uploadedUrl,
        fileType: mimeType,
        fileName: _pickedFileName,
      ),
    );
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

      String bucket = 'documents';
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
    _recordTimer?.cancel();
    _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _selectedFromLanguage = null;
        _selectedToLanguage = null;
        _selectedSpecialization = null;
        _selectedMethod = 'text';
        _pickedFilePath = null;
        _pickedFileName = null;
        _pickedFileSize = null;
        _recordedFilePath = null;
        _currentRecordingPath = null;
        _isRecording = false;
        _recordDuration = Duration.zero;
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
                        color: getStatusColor(request.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getStatusIcon(request.status),
                            color: getStatusColor(request.status),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            request.status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: getStatusColor(request.status),
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
                    formatDt(request.createdAt),
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
                    SharedFileLinkBox(
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
                      SharedFileLinkBox(
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
      _bloc.add(DeleteRequest(request.id));
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _tabController.dispose();
    _titleController.dispose();
    _textController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}
