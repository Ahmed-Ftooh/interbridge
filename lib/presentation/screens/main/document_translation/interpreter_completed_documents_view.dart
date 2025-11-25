import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/language_mapping_utility.dart';
import 'package:interbridge/data/services/hidden_items_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InterpreterCompletedDocumentsView extends StatefulWidget {
  const InterpreterCompletedDocumentsView({super.key});

  @override
  State<InterpreterCompletedDocumentsView> createState() =>
      _InterpreterCompletedDocumentsViewState();
}

class _InterpreterCompletedDocumentsViewState
    extends State<InterpreterCompletedDocumentsView> {
  List<DocumentTranslationRequest> _completedRequests = [];
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadCompletedRequests();
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
            .channel('public:document_translation_requests:completed')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'document_translation_requests',
              callback: (payload) {
                _loadCompletedRequests();
              },
            )
            .subscribe();
  }

  Future<void> _loadCompletedRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests =
          await instance<DocumentTranslationService>().getCompletedRequests();
      final hidden =
          await HiddenItemsService().getInterpreterHiddenCompletedIds();
      setState(() {
        _completedRequests =
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
              onPressed: _loadCompletedRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_completedRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: AppSize.s16),
            Text(
              'No Completed Translations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: AppSize.s8),
            Text(
              'You have no completed document translation requests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCompletedRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSize.s16),
        itemCount: _completedRequests.length,
        itemBuilder: (context, index) {
          final request = _completedRequests[index];
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSize.s8),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove from Completed',
                  onPressed: () async {
                    await HiddenItemsService().hideInterpreterCompleted(
                      request.id,
                    );
                    await _loadCompletedRequests();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from Completed')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s16),
            Text(
              'Completed: ${request.completedAt?.toString().split('.')[0] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageDisplayText(String fromLanguage, String toLanguage) {
    final fromLanguageId = int.tryParse(fromLanguage) ?? 0;
    final toLanguageId = int.tryParse(toLanguage) ?? 0;
    final fromLanguageName = LanguageMappingUtility.getLanguageName(
      fromLanguageId,
    );
    final toLanguageName = LanguageMappingUtility.getLanguageName(toLanguageId);

    if (fromLanguageName.isNotEmpty && toLanguageName.isNotEmpty) {
      return '$fromLanguageName → $toLanguageName';
    } else {
      return '$fromLanguage → $toLanguage';
    }
  }
}
