import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAvailableRequests();
  }

  Future<void> _loadAvailableRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests =
          await DocumentTranslationService().getAvailableRequests();
      setState(() {
        _availableRequests = requests;
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

  Future<void> _acceptRequest(String requestId) async {
    try {
      await DocumentTranslationService().acceptRequest(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted successfully!')),
        );

        // Reload requests
        await _loadAvailableRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error accepting request: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Translation Requests'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableRequests,
          ),
        ],
      ),
      body: _buildBody(),
    );
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.fromLanguage} → ${request.toLanguage}',
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
                  child: Text(
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
              Text(
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
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: AppSize.s16),
            ],

            if (request.fileUrl != null) ...[
              Text(
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
                child: Row(
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

            Text(
              'Requested: ${request.createdAt.toString().split('.')[0]}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: AppSize.s16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptRequest(request.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primary2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSize.s12),
                ),
                child: Text(
                  'Accept Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
