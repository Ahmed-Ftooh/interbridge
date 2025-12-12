part of 'interpreter_registration_bloc.dart';

abstract class InterpreterRegistrationEvent extends Equatable {
  const InterpreterRegistrationEvent();

  @override
  List<Object?> get props => [];
}

class InterpreterExperienceUpdated extends InterpreterRegistrationEvent {
  final int years;
  const InterpreterExperienceUpdated(this.years);

  @override
  List<Object?> get props => [years];
}

class InterpreterTrackSelected extends InterpreterRegistrationEvent {
  final InterpreterTrack track;
  const InterpreterTrackSelected(this.track);

  @override
  List<Object?> get props => [track];
}

class InterpreterVoiceSamplePicked extends InterpreterRegistrationEvent {
  final String path;
  const InterpreterVoiceSamplePicked(this.path);

  @override
  List<Object?> get props => [path];
}

class InterpreterGeneralCertificatePicked extends InterpreterRegistrationEvent {
  final String path;
  const InterpreterGeneralCertificatePicked(this.path);

  @override
  List<Object?> get props => [path];
}

class InterpreterMedicalCertificatePicked extends InterpreterRegistrationEvent {
  final String? path;
  const InterpreterMedicalCertificatePicked(this.path);

  @override
  List<Object?> get props => [path];
}

class InterpreterShiftAvailabilityUpdated extends InterpreterRegistrationEvent {
  final Set<InterpreterShift> shifts;
  const InterpreterShiftAvailabilityUpdated(this.shifts);

  @override
  List<Object?> get props => [shifts];
}

class InterpreterMedicalTestCompleted extends InterpreterRegistrationEvent {
  final int score;
  final Duration duration;
  const InterpreterMedicalTestCompleted({
    required this.score,
    required this.duration,
  });

  @override
  List<Object?> get props => [score, duration];
}

class InterpreterGeneralQuizCompleted extends InterpreterRegistrationEvent {
  final bool passed;
  const InterpreterGeneralQuizCompleted(this.passed);

  @override
  List<Object?> get props => [passed];
}

class InterpreterMedicalSectionCompleted extends InterpreterRegistrationEvent {
  final String sectionId;
  final bool passed;
  const InterpreterMedicalSectionCompleted({
    required this.sectionId,
    required this.passed,
  });

  @override
  List<Object?> get props => [sectionId, passed];
}

class InterpreterRegistrationStepAdvanced extends InterpreterRegistrationEvent {
  const InterpreterRegistrationStepAdvanced();
}

class InterpreterRegistrationStepBack extends InterpreterRegistrationEvent {
  const InterpreterRegistrationStepBack();
}

class InterpreterRegistrationSubmitted extends InterpreterRegistrationEvent {
  const InterpreterRegistrationSubmitted();
}

// ---------------------------------------------------------------------------
// Legacy events kept for backward compatibility with the old registration UI.
// They proxy into the new event model inside the bloc.

class ExperienceSubmitted extends InterpreterRegistrationEvent {
  final int years;
  const ExperienceSubmitted(this.years);

  @override
  List<Object?> get props => [years];
}

class DocumentsSubmitted extends InterpreterRegistrationEvent {
  const DocumentsSubmitted();
}

class ShiftsSubmitted extends InterpreterRegistrationEvent {
  final List<String> shifts;
  const ShiftsSubmitted(this.shifts);

  @override
  List<Object?> get props => [shifts];
}

class MedicalTestStarted extends InterpreterRegistrationEvent {
  const MedicalTestStarted();
}

class RegistrationFinalized extends InterpreterRegistrationEvent {
  const RegistrationFinalized();
}
