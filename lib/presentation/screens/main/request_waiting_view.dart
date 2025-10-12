import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/data/services/interpreter_request_service.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';

class RequestWaitingView extends StatefulWidget {
  final String fromLanguageId;
  final String toLanguageId;
  final String? specialization;
  final String urgency;
  final String? description;

  const RequestWaitingView({
    super.key,
    required this.fromLanguageId,
    required this.toLanguageId,
    required this.specialization,
    required this.urgency,
    this.description,
  });

  @override
  State<RequestWaitingView> createState() => _RequestWaitingViewState();
}

class _RequestWaitingViewState extends State<RequestWaitingView> {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  InterpreterRequest? _request;
  bool _isCreating = true;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    try {
      // 1) Create the request
      final request = await InterpreterRequestService().createRequest(
        fromLanguage: widget.fromLanguageId,
        toLanguage: widget.toLanguageId,
        specialization: widget.specialization,
        urgency: widget.urgency,
        description: widget.description,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _isCreating = false;
      });

      // 2) Subscribe to updates for this request (Supabase v2 API)
      _channel =
          _client.channel('rq_${request.id}')
            ..onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'interpreter_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: request.id,
              ),
              callback: (payload) {
                final newRow = payload.newRecord;
                final status = newRow['status']?.toString();
                if (status == 'accepted') {
                  final interpreterId = newRow['accepted_by'].toString();
                  final requesterId = newRow['requester_id'].toString();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BlocProvider(
                              create: (_) => ChatBloc(service: ChatService()),
                              child: ChatView(
                                requestId: request.id,
                                requesterId: requesterId,
                                interpreterId: interpreterId,
                              ),
                            ),
                      ),
                      (route) => false,
                    );
                  }
                }
              },
            )
            ..subscribe();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create request: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel?.unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSize.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Lottie.asset(
                    JsonAssets.loading,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppSize.s16),
                Text(
                  _isCreating
                      ? 'Creating your request...'
                      : 'Waiting for an interpreter to accept...'
                          '\nWe\'ll notify you as soon as someone accepts.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: AppSize.s24),
                if (_request != null)
                  Text(
                    'Request ID: ${_request!.id.substring(0, 8)}...'
                    '\nUrgency: ${_request!.urgency}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ColorManager.grey),
                  ),
                const SizedBox(height: AppSize.s24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
