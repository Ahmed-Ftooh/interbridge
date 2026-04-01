import 'dart:async'; // Add this
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/incoming_call_service.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Add this

// Events
abstract class InterpreterJobEvent {}

class LoadAvailableJobs extends InterpreterJobEvent {}

class AcceptJob extends InterpreterJobEvent {
  final String requestId;
  AcceptJob(this.requestId);
}

class DeclineJob extends InterpreterJobEvent {
  final String requestId;
  DeclineJob(this.requestId);
}

class RefreshJobs extends InterpreterJobEvent {}

// States
abstract class InterpreterJobState {}

class InterpreterJobInitial extends InterpreterJobState {}

class InterpreterJobLoading extends InterpreterJobState {}

class InterpreterJobAccepted extends InterpreterJobState {
  final InterpreterRequest request;
  InterpreterJobAccepted(this.request);
}

class InterpreterJobLoaded extends InterpreterJobState {
  final List<InterpreterRequest> jobs;
  final int totalJobs;

  InterpreterJobLoaded({required this.jobs, required this.totalJobs});
}

class InterpreterJobError extends InterpreterJobState {
  final String message;

  InterpreterJobError(this.message);
}

// Bloc
class InterpreterJobBloc
    extends Bloc<InterpreterJobEvent, InterpreterJobState> {
  final InterpreterJobService _jobService = InterpreterJobService();
  final IncomingCallService _incomingCallService = IncomingCallService();
  RealtimeChannel? _subscription;

  InterpreterJobBloc() : super(InterpreterJobInitial()) {
    on<LoadAvailableJobs>(_onLoadAvailableJobs);
    on<AcceptJob>(_onAcceptJob);
    on<DeclineJob>(_onDeclineJob);
    on<RefreshJobs>(_onRefreshJobs);

    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    _subscription =
        Supabase.instance.client
            .channel('public:interpreter_requests')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'interpreter_requests',
              callback: (payload) {
                log('Realtime update received for interpreter_requests');
                add(LoadAvailableJobs());
              },
            )
            .subscribe();
  }

  @override
  Future<void> close() {
    _subscription?.unsubscribe();
    return super.close();
  }

  Future<void> _onLoadAvailableJobs(
    LoadAvailableJobs event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      emit(InterpreterJobLoading());

      final jobs = await _jobService.getAvailableJobs();

      emit(InterpreterJobLoaded(jobs: jobs, totalJobs: jobs.length));
      unawaited(_incomingCallService.syncFromAvailableJobs(jobs));
    } catch (e) {
      emit(InterpreterJobError(e.toString()));
    }
  }

  Future<void> _onAcceptJob(
    AcceptJob event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      final request = await _jobService.acceptJob(event.requestId);

      if (request != null) {
        emit(InterpreterJobAccepted(request));
      }

      // Reload jobs after acceptance (successful or not, to keep list fresh)
      add(LoadAvailableJobs());
    } catch (e) {
      emit(InterpreterJobError(e.toString()));
      // Also reload on error (e.g. if job was already taken)
      add(LoadAvailableJobs());
    }
  }

  Future<void> _onDeclineJob(
    DeclineJob event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      await _jobService.declineJob(event.requestId);

      // Reload jobs after declining
      add(LoadAvailableJobs());
    } catch (e) {
      emit(InterpreterJobError(e.toString()));
      add(LoadAvailableJobs());
    }
  }

  Future<void> _onRefreshJobs(
    RefreshJobs event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      log('Refreshing jobs...');
      final jobs = await _jobService.getAvailableJobs();
      log('Refreshed jobs: ${jobs.length} found');

      emit(InterpreterJobLoaded(jobs: jobs, totalJobs: jobs.length));
      unawaited(_incomingCallService.syncFromAvailableJobs(jobs));
    } catch (e) {
      log('Error refreshing jobs: $e');
      emit(InterpreterJobError(e.toString()));
    }
  }
}
