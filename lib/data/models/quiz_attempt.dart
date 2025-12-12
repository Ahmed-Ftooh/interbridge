class QuizAttempt {
  final String? id;
  final String userId;
  final String quizType;
  final String? medicalSection;
  final int totalQuestions;
  final int correctAnswers;
  final double scorePercentage;
  final int? timeTakenSeconds;
  final bool passed;
  final Map<String, dynamic>? answers;
  final DateTime? takenAt;

  QuizAttempt({
    this.id,
    required this.userId,
    required this.quizType,
    this.medicalSection,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.scorePercentage,
    this.timeTakenSeconds,
    required this.passed,
    this.answers,
    this.takenAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'quiz_type': quizType,
    if (medicalSection != null) 'medical_section': medicalSection,
    'total_questions': totalQuestions,
    'correct_answers': correctAnswers,
    'score_percentage': scorePercentage,
    if (timeTakenSeconds != null) 'time_taken_seconds': timeTakenSeconds,
    'passed': passed,
    if (answers != null) 'answers': answers,
    if (takenAt != null) 'taken_at': takenAt!.toIso8601String(),
  };

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
    id: json['id'] as String?,
    userId: json['user_id'] as String,
    quizType: json['quiz_type'] as String,
    medicalSection: json['medical_section'] as String?,
    totalQuestions: json['total_questions'] as int,
    correctAnswers: json['correct_answers'] as int,
    scorePercentage: (json['score_percentage'] as num).toDouble(),
    timeTakenSeconds: json['time_taken_seconds'] as int?,
    passed: json['passed'] as bool,
    answers: json['answers'] as Map<String, dynamic>?,
    takenAt:
        json['taken_at'] != null
            ? DateTime.parse(json['taken_at'] as String)
            : null,
  );
}
