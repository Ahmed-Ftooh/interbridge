import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/models/interpreter_request.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';

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

  InterpreterJobBloc() : super(InterpreterJobInitial()) {
    on<LoadAvailableJobs>(_onLoadAvailableJobs);
    on<AcceptJob>(_onAcceptJob);
    on<DeclineJob>(_onDeclineJob);
    on<RefreshJobs>(_onRefreshJobs);
  }

  Future<void> _onLoadAvailableJobs(
    LoadAvailableJobs event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      emit(InterpreterJobLoading());

      final jobs = await _jobService.getAvailableJobs();

      emit(InterpreterJobLoaded(jobs: jobs, totalJobs: jobs.length));
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

      // Optionally reload jobs after acceptance
      final jobs = await _jobService.getAvailableJobs();
      emit(InterpreterJobLoaded(jobs: jobs, totalJobs: jobs.length));
    } catch (e) {
      emit(InterpreterJobError(e.toString()));
    }
  }

  Future<void> _onDeclineJob(
    DeclineJob event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      await _jobService.declineJob(event.requestId);

      // Reload jobs after declining
      final jobs = await _jobService.getAvailableJobs();

      emit(InterpreterJobLoaded(jobs: jobs, totalJobs: jobs.length));
    } catch (e) {
      emit(InterpreterJobError(e.toString()));
    }
  }

  Future<void> _onRefreshJobs(
    RefreshJobs event,
    Emitter<InterpreterJobState> emit,
  ) async {
    try {
      final jobs = await _jobService.getAvailableJobs();

      emit(InterpreterJobLoaded(jobs: jobs, totalJobs: jobs.length));
    } catch (e) {
      emit(InterpreterJobError(e.toString()));
    }
  }
}
