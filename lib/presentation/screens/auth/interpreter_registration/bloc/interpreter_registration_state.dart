part of 'interpreter_registration_bloc.dart';

class InterpreterRegistrationState extends Equatable {
  final InterpreterApplication application;
  final int currentStep;
  final bool isSubmitting;
  final bool submitSuccess;
  final String? errorMessage;

  const InterpreterRegistrationState({
    required this.application,
    this.currentStep = 0,
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.errorMessage,
  });

  factory InterpreterRegistrationState.initial() {
    final defaultLevel = InterpreterLevel.volunteer;
    return InterpreterRegistrationState(
      application: InterpreterApplication(
        experienceYears: 0,
        level: defaultLevel,
        track: InterpreterTrack.volunteer,
        generalCertificatePath: null,
        voiceSamplePath: null,
        shifts: {},
        medicalTestPassed: false,
      ),
    );
  }

  InterpreterRegistrationState copyWith({
    InterpreterApplication? application,
    int? currentStep,
    bool? isSubmitting,
    bool? submitSuccess,
    String? errorMessage,
  }) {
    return InterpreterRegistrationState(
      application: application ?? this.application,
      currentStep: currentStep ?? this.currentStep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess: submitSuccess ?? this.submitSuccess,
      errorMessage: errorMessage,
    );
  }

  // Legacy getters to keep older UI code compiling while new flow is adopted.
  bool get isSuccess => submitSuccess;
  String? get error => errorMessage;
  String get level => application.level.name;
  int get yearsExperience => application.experienceYears;
  List<String> get shifts =>
      application.shifts.map((shift) => shift.label).toList();
  int? get testScore => application.medicalTestScore;

  bool get isVolunteerFlow => application.track == InterpreterTrack.volunteer;

  bool get canSubmit {
    final app = application;
    final hasBasics =
        app.experienceYears >= 0 &&
        app.hasGeneralCertificate &&
        app.hasVoiceSample &&
        app.isGeneralQuizReady; // General quiz required for ALL

    if (app.track == InterpreterTrack.paid && app.requiresMedicalDocs) {
      // Paid track needs: medical cert, shifts, at least one medical section badge
      return hasBasics &&
          app.hasMedicalCertificate &&
          app.hasShifts &&
          app.isMedicalQuizReady;
    }

    // Volunteer track only needs basics + general quiz
    return hasBasics;
  }

  @override
  List<Object?> get props => [
    application,
    currentStep,
    isSubmitting,
    submitSuccess,
    errorMessage,
  ];
}
