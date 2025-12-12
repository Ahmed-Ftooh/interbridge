import 'package:interbridge/data/models/interpreter_level.dart';
import 'package:interbridge/data/models/interpreter_shift.dart';
import 'package:interbridge/data/models/interpreter_track.dart';

class InterpreterApplication {
  final int experienceYears;
  final InterpreterLevel level;
  final InterpreterTrack track;
  final String? generalCertificatePath;
  final String? voiceSamplePath;
  final String? medicalCertificatePath;
  final Set<InterpreterShift> shifts;
  final bool generalQuizPassed;
  final bool medicalTestPassed;
  final int? medicalTestScore;
  final Duration? medicalTestDuration;
  final Set<String>
  medicalSectionsPassed; // Track which medical sections earned badges

  const InterpreterApplication({
    required this.experienceYears,
    required this.level,
    required this.track,
    required this.generalCertificatePath,
    required this.voiceSamplePath,
    this.medicalCertificatePath,
    this.shifts = const {},
    this.generalQuizPassed = false,
    this.medicalTestPassed = false,
    this.medicalTestScore,
    this.medicalTestDuration,
    this.medicalSectionsPassed = const {},
  });

  InterpreterApplication copyWith({
    int? experienceYears,
    InterpreterLevel? level,
    InterpreterTrack? track,
    String? generalCertificatePath,
    String? voiceSamplePath,
    String? medicalCertificatePath,
    Set<InterpreterShift>? shifts,
    bool? generalQuizPassed,
    bool? medicalTestPassed,
    int? medicalTestScore,
    Duration? medicalTestDuration,
    Set<String>? medicalSectionsPassed,
  }) {
    return InterpreterApplication(
      experienceYears: experienceYears ?? this.experienceYears,
      level: level ?? this.level,
      track: track ?? this.track,
      generalCertificatePath:
          generalCertificatePath ?? this.generalCertificatePath,
      voiceSamplePath: voiceSamplePath ?? this.voiceSamplePath,
      medicalCertificatePath:
          medicalCertificatePath ?? this.medicalCertificatePath,
      shifts: shifts ?? this.shifts,
      generalQuizPassed: generalQuizPassed ?? this.generalQuizPassed,
      medicalTestPassed: medicalTestPassed ?? this.medicalTestPassed,
      medicalTestScore: medicalTestScore ?? this.medicalTestScore,
      medicalTestDuration: medicalTestDuration ?? this.medicalTestDuration,
      medicalSectionsPassed:
          medicalSectionsPassed ?? this.medicalSectionsPassed,
    );
  }

  bool get requiresMedicalDocs => level.requiresMedicalCredentials;
  bool get hasGeneralCertificate => (generalCertificatePath ?? '').isNotEmpty;
  bool get hasVoiceSample => (voiceSamplePath ?? '').isNotEmpty;
  bool get hasMedicalCertificate =>
      !requiresMedicalDocs || (medicalCertificatePath ?? '').isNotEmpty;
  bool get hasShifts => shifts.isNotEmpty;

  // General quiz required for ALL (volunteer + paid)
  bool get isGeneralQuizReady => generalQuizPassed;

  // Medical sections required for PAID track only
  bool get isMedicalQuizReady =>
      track == InterpreterTrack.volunteer || medicalSectionsPassed.isNotEmpty;
}
