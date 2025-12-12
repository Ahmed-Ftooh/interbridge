class QuizQuestion {
  final String id;
  final String quizType; // 'general' | 'medical'
  final String? medicalSection;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // 'A' | 'B' | 'C' | 'D'
  final int difficulty;

  QuizQuestion({
    required this.id,
    required this.quizType,
    this.medicalSection,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.difficulty = 1,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String,
    quizType: json['quiz_type'] as String,
    medicalSection: json['medical_section'] as String?,
    questionText: json['question_text'] as String,
    optionA: json['option_a'] as String,
    optionB: json['option_b'] as String,
    optionC: json['option_c'] as String,
    optionD: json['option_d'] as String,
    correctOption: json['correct_option'] as String,
    difficulty: json['difficulty'] as int? ?? 1,
  );

  List<String> get options => [optionA, optionB, optionC, optionD];

  int get correctIndex => ['A', 'B', 'C', 'D'].indexOf(correctOption);
}
