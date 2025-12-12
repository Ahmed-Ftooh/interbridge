// Future<void> _navigateToQuiz() async {
//   final args =
//       ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

//   // Launch general quiz
//   final result = await Navigator.of(context).push<Map<String, dynamic>>(
//     MaterialPageRoute(
//       builder: (_) => const QuizScreen(quizType: 'general', isRequired: true),
//     ),
//   );

//   if (!mounted) return;

//   // Update args based on result
//   if (result != null && result['passed'] == true) {
//     args['generalQuizPassed'] = true;
//     args['generalQuizScore'] = result['score'];

//     // Continue flow based on track
//     final isPaid =
//         args['requiresMedicalDocs'] == true ||
//         args['interpreterTrack'] == 'paid';

//     if (isPaid) {
//       // Paid: continue to medical sections
//       Navigator.of(
//         context,
//       ).pushReplacementNamed(Routes.medicalSectionsRoute, arguments: args);
//     } else {
//       // Volunteer: continue to success
//       Navigator.of(
//         context,
//       ).pushReplacementNamed(Routes.volunteerSuccessRoute, arguments: args);
//     }
//   } else {
//     // Failed quiz - go back
//     Navigator.of(context).pop();
//   }
// }
