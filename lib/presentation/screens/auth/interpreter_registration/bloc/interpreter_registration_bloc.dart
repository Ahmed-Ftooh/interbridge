import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/models/interpreter_application.dart';
import 'package:interbridge/data/models/interpreter_level.dart';
import 'package:interbridge/data/models/interpreter_shift.dart';
import 'package:interbridge/data/models/interpreter_track.dart';

part 'interpreter_registration_event.dart';
part 'interpreter_registration_state.dart';

class InterpreterRegistrationBloc
    extends Bloc<InterpreterRegistrationEvent, InterpreterRegistrationState> {
  InterpreterRegistrationBloc()
    : super(InterpreterRegistrationState.initial()) {
    on<InterpreterExperienceUpdated>(_onExperienceUpdated);
    on<InterpreterTrackSelected>(_onTrackSelected);
    on<InterpreterVoiceSamplePicked>(_onVoiceSamplePicked);
    on<InterpreterGeneralCertificatePicked>(_onGeneralCertificatePicked);
    on<InterpreterMedicalCertificatePicked>(_onMedicalCertificatePicked);
    on<InterpreterShiftAvailabilityUpdated>(_onShiftAvailabilityUpdated);
    on<InterpreterMedicalTestCompleted>(_onMedicalTestCompleted);
    on<InterpreterGeneralQuizCompleted>(_onGeneralQuizCompleted);
    on<InterpreterMedicalSectionCompleted>(_onMedicalSectionCompleted);
    on<InterpreterRegistrationStepAdvanced>(_onStepAdvanced);
    on<InterpreterRegistrationStepBack>(_onStepBack);
    on<InterpreterRegistrationSubmitted>(_onSubmit);

    // Legacy event handlers for deprecated UI
    on<ExperienceSubmitted>(_onLegacyExperienceSubmitted);
    on<DocumentsSubmitted>(_onLegacyDocumentsSubmitted);
    on<ShiftsSubmitted>(_onLegacyShiftsSubmitted);
    on<MedicalTestStarted>(_onLegacyMedicalTestStarted);
    on<RegistrationFinalized>(_onLegacyRegistrationFinalized);
  }

  void _onExperienceUpdated(
    InterpreterExperienceUpdated event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    final years = event.years.clamp(0, 50);
    // Level is now selected explicitly, so we just update years
    // Default to volunteer if years < 1, else keep current or default

    emit(
      state.copyWith(
        application: state.application.copyWith(experienceYears: years),
      ),
    );
  }

  void _onTrackSelected(
    InterpreterTrackSelected event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(track: event.track),
      ),
    );
  }

  void _onVoiceSamplePicked(
    InterpreterVoiceSamplePicked event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(voiceSamplePath: event.path),
      ),
    );
  }

  void _onGeneralCertificatePicked(
    InterpreterGeneralCertificatePicked event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(
          generalCertificatePath: event.path,
        ),
      ),
    );
  }

  void _onMedicalCertificatePicked(
    InterpreterMedicalCertificatePicked event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(
          medicalCertificatePath: event.path,
        ),
      ),
    );
  }

  void _onShiftAvailabilityUpdated(
    InterpreterShiftAvailabilityUpdated event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(shifts: event.shifts),
      ),
    );
  }

  void _onMedicalTestCompleted(
    InterpreterMedicalTestCompleted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(
          medicalTestPassed: event.score >= 70,
          medicalTestScore: event.score,
          medicalTestDuration: event.duration,
        ),
      ),
    );
  }

  void _onGeneralQuizCompleted(
    InterpreterGeneralQuizCompleted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(
      state.copyWith(
        application: state.application.copyWith(
          generalQuizPassed: event.passed,
        ),
      ),
    );
  }

  void _onMedicalSectionCompleted(
    InterpreterMedicalSectionCompleted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    if (event.passed) {
      final updated = {
        ...state.application.medicalSectionsPassed,
        event.sectionId,
      };
      emit(
        state.copyWith(
          application: state.application.copyWith(
            medicalSectionsPassed: updated,
          ),
        ),
      );
    }
  }

  void _onStepAdvanced(
    InterpreterRegistrationStepAdvanced event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(state.copyWith(currentStep: state.currentStep + 1));
  }

  void _onStepBack(
    InterpreterRegistrationStepBack event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    emit(state.copyWith(currentStep: (state.currentStep - 1).clamp(0, 10)));
  }

  Future<void> _onSubmit(
    InterpreterRegistrationSubmitted event,
    Emitter<InterpreterRegistrationState> emit,
  ) async {
    if (!state.canSubmit) {
      emit(
        state.copyWith(
          errorMessage: 'Please complete all required steps before submitting.',
        ),
      );
      return;
    }

    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    emit(
      state.copyWith(
        isSubmitting: false,
        submitSuccess: true,
        errorMessage: null,
      ),
    );
  }

  void _onLegacyExperienceSubmitted(
    ExperienceSubmitted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    _onExperienceUpdated(InterpreterExperienceUpdated(event.years), emit);
    _onStepAdvanced(const InterpreterRegistrationStepAdvanced(), emit);
  }

  void _onLegacyDocumentsSubmitted(
    DocumentsSubmitted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    _onStepAdvanced(const InterpreterRegistrationStepAdvanced(), emit);
  }

  void _onLegacyShiftsSubmitted(
    ShiftsSubmitted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    final mappedShifts =
        event.shifts
            .map(_shiftFromLegacyId)
            .whereType<InterpreterShift>()
            .toSet();
    emit(
      state.copyWith(
        application: state.application.copyWith(shifts: mappedShifts),
      ),
    );
    _onStepAdvanced(const InterpreterRegistrationStepAdvanced(), emit);
  }

  void _onLegacyMedicalTestStarted(
    MedicalTestStarted event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    _onStepAdvanced(const InterpreterRegistrationStepAdvanced(), emit);
  }

  void _onLegacyRegistrationFinalized(
    RegistrationFinalized event,
    Emitter<InterpreterRegistrationState> emit,
  ) {
    _onSubmit(const InterpreterRegistrationSubmitted(), emit);
  }

  InterpreterShift? _shiftFromLegacyId(String id) {
    switch (id.toLowerCase()) {
      case 'morning':
        return InterpreterShift.morning;
      case 'night':
        return InterpreterShift.night;
      case 'emergency':
        return InterpreterShift.emergency;
      default:
        return null;
    }
  }
}
