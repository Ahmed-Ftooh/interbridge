import 'package:flutter/material.dart';

/// Stub for QuizWebScreen on non-web platforms.
/// The real implementation uses dart:html/dart:js which are web-only.
class QuizWebScreen extends StatelessWidget {
  final String quizType;
  final String? medicalSection;
  final bool isRequired;

  const QuizWebScreen({
    super.key,
    required this.quizType,
    this.medicalSection,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: const Center(
        child: Text(
          'Quizzes are only available on the web version.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
