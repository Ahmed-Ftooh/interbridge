// import 'dart:async';
// import 'dart:io';
// import 'dart:math';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:interbridge/data/models/interpreter_level.dart';
// import 'package:interbridge/data/models/interpreter_shift.dart';
// import 'package:interbridge/data/models/interpreter_track.dart';
// import 'package:interbridge/data/services/supabase_service.dart';
// import 'package:interbridge/presentation/resources/color_manager.dart';
// import 'package:interbridge/presentation/resources/values_manager.dart';
// import 'package:interbridge/presentation/screens/auth/interpreter_registration/bloc/interpreter_registration_bloc.dart';
// import 'package:interbridge/presentation/screens/quiz/quiz_screen.dart';
// import 'package:interbridge/presentation/screens/quiz/medical_section_selector_screen.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';

// class InterpreterRegistrationFlow extends StatelessWidget {
//   const InterpreterRegistrationFlow({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (_) => InterpreterRegistrationBloc(),
//       child: const _InterpreterRegistrationBody(),
//     );
//   }
// }

// class _InterpreterRegistrationBody extends StatefulWidget {
//   const _InterpreterRegistrationBody();

//   @override
//   State<_InterpreterRegistrationBody> createState() =>
//       _InterpreterRegistrationBodyState();
// }

// class _InterpreterRegistrationBodyState
//     extends State<_InterpreterRegistrationBody> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Interpreter Application'),
//         backgroundColor: ColorManager.primary2,
//       ),
//       body: SafeArea(
//         child: BlocConsumer<
//           InterpreterRegistrationBloc,
//           InterpreterRegistrationState
//         >(
//           listenWhen:
//               (previous, current) =>
//                   previous.errorMessage != current.errorMessage ||
//                   previous.submitSuccess != current.submitSuccess,
//           listener: (context, state) {
//             if (state.errorMessage != null) {
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
//             }

//             if (state.submitSuccess) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Application draft saved. Pending submission.'),
//                 ),
//               );
//             }
//           },
//           builder: (context, state) {
//             final steps = _buildStepConfigs(context, state);
//             final visibleSteps =
//                 steps.where((config) => config.isVisible(state)).toList();
//             final currentIndex =
//                 visibleSteps.isEmpty
//                     ? 0
//                     : state.currentStep.clamp(0, visibleSteps.length - 1);

//             return Stepper(
//               key: ValueKey(
//                 'steps-${state.application.requiresMedicalDocs}-${visibleSteps.length}',
//               ),
//               type: StepperType.vertical,
//               currentStep: currentIndex,
//               controlsBuilder: (context, details) {
//                 if (visibleSteps.isEmpty) return const SizedBox.shrink();
//                 final config = visibleSteps[currentIndex];
//                 final isLastStep = currentIndex == visibleSteps.length - 1;
//                 final canProceed =
//                     config.canContinue(state) && !state.isSubmitting;

//                 return Padding(
//                   padding: const EdgeInsets.only(top: AppSize.s16),
//                   child: Row(
//                     children: [
//                       ElevatedButton(
//                         onPressed:
//                             canProceed
//                                 ? () {
//                                   if (isLastStep) {
//                                     context
//                                         .read<InterpreterRegistrationBloc>()
//                                         .add(
//                                           const InterpreterRegistrationSubmitted(),
//                                         );
//                                   } else {
//                                     context.read<InterpreterRegistrationBloc>().add(
//                                       const InterpreterRegistrationStepAdvanced(),
//                                     );
//                                   }
//                                 }
//                                 : null,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: ColorManager.primary2,
//                         ),
//                         child: Text(
//                           isLastStep ? 'Submit Application' : 'Next',
//                           style: const TextStyle(color: Colors.white),
//                         ),
//                       ),
//                       const SizedBox(width: AppSize.s12),
//                       if (currentIndex > 0)
//                         TextButton(
//                           onPressed:
//                               state.isSubmitting
//                                   ? null
//                                   : () => context
//                                       .read<InterpreterRegistrationBloc>()
//                                       .add(
//                                         const InterpreterRegistrationStepBack(),
//                                       ),
//                           child: const Text('Back'),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//               steps: List.generate(visibleSteps.length, (index) {
//                 final config = visibleSteps[index];
//                 return Step(
//                   title: Text(config.title),
//                   content: config.builder(context, state),
//                   isActive: currentIndex >= index,
//                   state:
//                       currentIndex > index
//                           ? StepState.complete
//                           : StepState.indexed,
//                 );
//               }),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   List<_StepConfig> _buildStepConfigs(
//     BuildContext context,
//     InterpreterRegistrationState state,
//   ) {
//     final registrationBloc = context.read<InterpreterRegistrationBloc>();
//     return [
//       _StepConfig(
//         title: 'Experience & Level',
//         builder:
//             (context, state) => _ExperienceStep(
//               selectedLevel: state.application.level,
//               experienceYears: state.application.experienceYears,
//               onTierSelected:
//                   (years) =>
//                       registrationBloc.add(InterpreterExperienceUpdated(years)),
//             ),
//         canContinue: (state) => state.application.experienceYears >= 0,
//         isVisible: (_) => true,
//       ),
//       _StepConfig(
//         title: 'Training Certificate',
//         builder:
//             (context, state) => _DocumentUploadTile(
//               title: 'Upload any accredited training certificate',
//               subtitle:
//                   'Accepted formats: PDF/JPG/PNG. Required for all interpreter tiers.',
//               filePath: state.application.generalCertificatePath,
//               onPick:
//                   () => _pickDocument(
//                     context,
//                     onSelected:
//                         (path) => registrationBloc.add(
//                           InterpreterGeneralCertificatePicked(path),
//                         ),
//                   ),
//             ),
//         canContinue: (state) => state.application.hasGeneralCertificate,
//         isVisible: (_) => true,
//       ),
//       _StepConfig(
//         title: 'Voice Sample',
//         builder:
//             (context, state) => _VoiceSampleStep(
//               filePath: state.application.voiceSamplePath,
//               onSampleReady:
//                   (path) =>
//                       registrationBloc.add(InterpreterVoiceSamplePicked(path)),
//             ),
//         canContinue: (state) => state.application.hasVoiceSample,
//         isVisible: (_) => true,
//       ),
//       _StepConfig(
//         title: 'Track Selection',
//         builder:
//             (context, state) => _TrackSelectionStep(
//               currentTrack: state.application.track,
//               isLevelLocked:
//                   state.application.level == InterpreterLevel.volunteer,
//               onTrackSelected:
//                   (track) =>
//                       registrationBloc.add(InterpreterTrackSelected(track)),
//             ),
//         canContinue: (_) => true,
//         isVisible: (_) => true,
//       ),
//       _StepConfig(
//         title: 'Medical Credentials',
//         builder:
//             (context, state) => _DocumentUploadTile(
//               title: 'Upload medical interpreter certificate or work reference',
//               subtitle:
//                   'Required for Junior/Professional tracks to unlock medical calls.',
//               filePath: state.application.medicalCertificatePath,
//               onPick:
//                   () => _pickDocument(
//                     context,
//                     onSelected:
//                         (path) => registrationBloc.add(
//                           InterpreterMedicalCertificatePicked(path),
//                         ),
//                   ),
//             ),
//         canContinue: (state) => state.application.hasMedicalCertificate,
//         isVisible: (state) => state.application.requiresMedicalDocs,
//       ),
//       _StepConfig(
//         title: 'Shift Availability',
//         builder:
//             (context, state) => _ShiftSelectionStep(
//               selected: state.application.shifts,
//               onToggle: (shift, isSelected) {
//                 final next = {...state.application.shifts};
//                 if (isSelected) {
//                   next.add(shift);
//                 } else {
//                   next.remove(shift);
//                 }
//                 registrationBloc.add(InterpreterShiftAvailabilityUpdated(next));
//               },
//             ),
//         canContinue: (state) => state.application.hasShifts,
//         isVisible:
//             (state) =>
//                 state.application.requiresMedicalDocs &&
//                 state.application.track == InterpreterTrack.paid,
//       ),
//       _StepConfig(
//         title: 'General Quiz',
//         builder:
//             (context, state) => _GeneralQuizStep(
//               passed: state.application.generalQuizPassed,
//               onLaunchQuiz: () => _launchGeneralQuiz(context, registrationBloc),
//             ),
//         canContinue: (state) => state.application.isGeneralQuizReady,
//         isVisible: (_) => true,
//       ),
//       _StepConfig(
//         title: 'Medical Specializations',
//         builder:
//             (context, state) => _MedicalSectionsStep(
//               sectionsCount: state.application.medicalSectionsPassed.length,
//               onLaunchSelector: () => _launchMedicalSections(context),
//             ),
//         canContinue: (state) => state.application.isMedicalQuizReady,
//         isVisible: (state) => state.application.track == InterpreterTrack.paid,
//       ),
//       _StepConfig(
//         title: 'Review & Submit',
//         builder: (context, state) => _ReviewSummary(state: state),
//         canContinue: (state) => state.canSubmit,
//         isVisible: (_) => true,
//       ),
//     ];
//   }

//   Future<void> _pickDocument(
//     BuildContext context, {
//     required ValueChanged<String> onSelected,
//   }) async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
//     );
//     final path = result?.files.single.path;
//     if (path != null) onSelected(path);
//   }

//   Future<void> _launchGeneralQuiz(
//     BuildContext context,
//     InterpreterRegistrationBloc bloc,
//   ) async {
//     final result = await Navigator.of(context).push<Map<String, dynamic>>(
//       MaterialPageRoute(
//         builder: (_) => const QuizScreen(
//           quizType: 'general',
//           isRequired: true,
//         ),
//       ),
//     );

//     if (result != null && result['passed'] == true) {
//       bloc.add(const InterpreterGeneralQuizCompleted(true));
//     }
//   }

//   Future<void> _launchMedicalSections(BuildContext context) async {
//     final bloc = context.read<InterpreterRegistrationBloc>();
//     await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => BlocProvider.value(
//           value: bloc,
//           child: const _MedicalSectionSelectorWrapper(),
//         ),
//       ),
//     );
//   }

//   void _simulateTest(InterpreterRegistrationBloc bloc) {
//     final randomScore = 70 + Random().nextInt(31); // 70-100
//     bloc.add(
//       InterpreterMedicalTestCompleted(
//         score: randomScore,
//         duration: const Duration(minutes: 8, seconds: 30),
//       ),
//     );
//   }
// }

// class _StepConfig {
//   final String title;
//   final Widget Function(BuildContext, InterpreterRegistrationState) builder;
//   final bool Function(InterpreterRegistrationState) canContinue;
//   final bool Function(InterpreterRegistrationState) isVisible;

//   const _StepConfig({
//     required this.title,
//     required this.builder,
//     required this.canContinue,
//     required this.isVisible,
//   });
// }

// class _ExperienceStep extends StatelessWidget {
//   final InterpreterLevel selectedLevel;
//   final int experienceYears;
//   final ValueChanged<int> onTierSelected;

//   const _ExperienceStep({
//     required this.selectedLevel,
//     required this.experienceYears,
//     required this.onTierSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final tiers = _ExperienceTierConfig.defaults;
//     final theme = Theme.of(context);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Choose the experience tier that best matches your background.',
//           style: theme.textTheme.titleMedium?.copyWith(
//             fontWeight: FontWeight.w600,
//             color: ColorManager.textPrimary,
//           ),
//         ),
//         const SizedBox(height: AppSize.s8),
//         Text(
//           'These cards mirror the same style as the role selector. Tap one to auto-set your level and unlock the right track.',
//           style: theme.textTheme.bodySmall?.copyWith(
//             color: ColorManager.textSecondary,
//           ),
//         ),
//         const SizedBox(height: AppSize.s16),
//         ...tiers.map(
//           (tier) => Padding(
//             padding: const EdgeInsets.only(bottom: AppSize.s12),
//             child: _ExperienceTierCard(
//               config: tier,
//               isSelected: tier.level == selectedLevel,
//               onTap: () => onTierSelected(tier.recommendedYears),
//             ),
//           ),
//         ),
//         const SizedBox(height: AppSize.s16),
//         _LevelBadge(level: selectedLevel),
//         const SizedBox(height: AppSize.s8),
//         Text(
//           'Logged experience: $experienceYears year${experienceYears == 1 ? '' : 's'}. Update documents anytime if you need to move tiers.',
//           style: theme.textTheme.bodySmall,
//         ),
//       ],
//     );
//   }
// }

// class _ExperienceTierConfig {
//   final InterpreterLevel level;
//   final String title;
//   final String range;
//   final String description;
//   final IconData icon;
//   final Color accent;
//   final int recommendedYears;

//   const _ExperienceTierConfig({
//     required this.level,
//     required this.title,
//     required this.range,
//     required this.description,
//     required this.icon,
//     required this.accent,
//     required this.recommendedYears,
//   });

//   static List<_ExperienceTierConfig> get defaults => [
//     _ExperienceTierConfig(
//       level: InterpreterLevel.volunteer,
//       title: 'Volunteer',
//       range: '0–1 year • Humanitarian calls',
//       description:
//           'Perfect for new interpreters building confidence through humanitarian requests.',
//       icon: Icons.volunteer_activism_rounded,
//       accent: ColorManager.primary2,
//       recommendedYears: 0,
//     ),
//     _ExperienceTierConfig(
//       level: InterpreterLevel.paid,
//       title: 'Paid Professional',
//       range: 'Certified • Medical calls',
//       description:
//           'For certified interpreters. Handle medical consultations with paid shifts.',
//       icon: Icons.medical_services_rounded,
//       accent: ColorManager.success,
//       recommendedYears: 3,
//     ),
//   ];
// }

// class _ExperienceTierCard extends StatelessWidget {
//   final _ExperienceTierConfig config;
//   final bool isSelected;
//   final VoidCallback onTap;

//   const _ExperienceTierCard({
//     required this.config,
//     required this.isSelected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final borderColor =
//         isSelected
//             ? config.accent
//             : ColorManager.primary.withValues(alpha: 0.15);

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(AppSize.s16),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.all(AppSize.s16),
//           decoration: BoxDecoration(
//             color:
//                 isSelected
//                     ? config.accent.withValues(alpha: 0.08)
//                     : ColorManager.backgroundCard,
//             borderRadius: BorderRadius.circular(AppSize.s16),
//             border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
//             boxShadow: [
//               BoxShadow(
//                 color: config.accent.withValues(
//                   alpha: isSelected ? 0.24 : 0.08,
//                 ),
//                 blurRadius: 12,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(AppSize.s16),
//                 decoration: BoxDecoration(
//                   color: config.accent.withValues(alpha: 0.12),
//                   borderRadius: BorderRadius.circular(AppSize.s12),
//                 ),
//                 child: Icon(
//                   config.icon,
//                   color: config.accent,
//                   size: AppSize.s28,
//                 ),
//               ),
//               const SizedBox(width: AppSize.s16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       config.title,
//                       style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                         color: ColorManager.textPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       config.range,
//                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                         color: ColorManager.textSecondary,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       config.description,
//                       style: Theme.of(context).textTheme.bodySmall,
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: AppSize.s12),
//               Icon(
//                 isSelected
//                     ? Icons.radio_button_checked
//                     : Icons.radio_button_off,
//                 color: isSelected ? config.accent : ColorManager.greyDark,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _LevelBadge extends StatelessWidget {
//   final InterpreterLevel level;
//   const _LevelBadge({required this.level});

//   @override
//   Widget build(BuildContext context) {
//     final color =
//         level == InterpreterLevel.paid ? Colors.green : Colors.blueGrey;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(AppSize.s12),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             level.label,
//             style: TextStyle(color: color, fontWeight: FontWeight.w600),
//           ),
//           Text(
//             level.badge,
//             style: Theme.of(context).textTheme.bodySmall?.copyWith(
//               color: color.withValues(alpha: 0.9),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _VoiceSampleStep extends StatefulWidget {
//   final String? filePath;
//   final ValueChanged<String> onSampleReady;

//   const _VoiceSampleStep({required this.filePath, required this.onSampleReady});

//   @override
//   State<_VoiceSampleStep> createState() => _VoiceSampleStepState();
// }

// class _VoiceSampleStepState extends State<_VoiceSampleStep> {
//   static const String _scriptPrompt =
//       '“My name is ________, and I confirm I can facilitate accurate medical interpretation between Arabic and English for InterBridge.”';

//   final AudioRecorder _recorder = AudioRecorder();
//   Timer? _ticker;
//   Duration _elapsed = Duration.zero;
//   bool _isRecording = false;
//   String? _draftPath;

//   @override
//   void dispose() {
//     _ticker?.cancel();
//     _recorder.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final String? selectedFileName = _fileName(widget.filePath);

//     return Card(
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(AppSize.s16),
//         side: BorderSide(color: ColorManager.primary.withValues(alpha: 0.2)),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(AppSize.s16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Voice Sample Studio',
//               style: theme.textTheme.titleMedium?.copyWith(
//                 fontWeight: FontWeight.w600,
//                 color: ColorManager.textPrimary,
//               ),
//             ),
//             const SizedBox(height: AppSize.s4),
//             Text(
//               'Record 10–20 seconds reading the prompt so our reviewers can check clarity.',
//               style: theme.textTheme.bodySmall?.copyWith(
//                 color: ColorManager.textSecondary,
//               ),
//             ),
//             const SizedBox(height: AppSize.s16),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(AppSize.s16),
//               decoration: BoxDecoration(
//                 color: ColorManager.primary2.withValues(alpha: 0.06),
//                 borderRadius: BorderRadius.circular(AppSize.s16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.article, color: ColorManager.primary2),
//                       const SizedBox(width: AppSize.s8),
//                       Text(
//                         'Read this sentence aloud',
//                         style: theme.textTheme.labelLarge?.copyWith(
//                           color: ColorManager.primary2,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: AppSize.s8),
//                   Text(
//                     _scriptPrompt,
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       fontStyle: FontStyle.italic,
//                       color: ColorManager.textPrimary,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (_isRecording) ...[
//               const SizedBox(height: AppSize.s16),
//               _RecordingIndicator(elapsed: _elapsed),
//             ],
//             const SizedBox(height: AppSize.s16),
//             ElevatedButton.icon(
//               onPressed:
//                   _isRecording
//                       ? () => _stopRecording(saveClip: true)
//                       : _startRecording,
//               icon: Icon(
//                 _isRecording ? Icons.stop_circle : Icons.mic,
//                 color: Colors.white,
//               ),
//               label: Text(
//                 _isRecording ? 'Stop & attach' : 'Start recording',
//                 style: const TextStyle(color: Colors.white),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     _isRecording ? ColorManager.error : ColorManager.primary2,
//                 padding: const EdgeInsets.symmetric(vertical: AppSize.s14),
//                 minimumSize: const Size.fromHeight(48),
//               ),
//             ),
//             if (_isRecording)
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton.icon(
//                   onPressed: () => _stopRecording(saveClip: false),
//                   icon: Icon(Icons.close, color: ColorManager.error),
//                   label: Text(
//                     'Discard take',
//                     style: TextStyle(color: ColorManager.error),
//                   ),
//                 ),
//               ),
//             if (selectedFileName != null) ...[
//               const SizedBox(height: AppSize.s20),
//               Container(
//                 padding: const EdgeInsets.all(AppSize.s16),
//                 decoration: BoxDecoration(
//                   color: ColorManager.success.withValues(alpha: 0.08),
//                   borderRadius: BorderRadius.circular(AppSize.s12),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.check_circle, color: ColorManager.success),
//                     const SizedBox(width: AppSize.s12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Voice sample attached',
//                             style: theme.textTheme.bodyMedium?.copyWith(
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Text(
//                             selectedFileName,
//                             style: theme.textTheme.bodySmall,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                     TextButton(
//                       onPressed: _isRecording ? null : _startRecording,
//                       child: const Text('Retake'),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _startRecording() async {
//     if (_isRecording) return;
//     try {
//       final hasPermission = await _recorder.hasPermission();
//       if (!hasPermission) {
//         _showSnackBar('Microphone permission is required to record.', true);
//         return;
//       }

//       final tempDir = await getTemporaryDirectory();
//       final path =
//           '${tempDir.path}/voice_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';

//       await _recorder.start(
//         const RecordConfig(
//           encoder: AudioEncoder.aacLc,
//           sampleRate: 44100,
//           bitRate: 128000,
//         ),
//         path: path,
//       );

//       setState(() {
//         _isRecording = true;
//         _elapsed = Duration.zero;
//         _draftPath = path;
//       });

//       _ticker?.cancel();
//       _ticker = Timer.periodic(
//         const Duration(seconds: 1),
//         (_) => setState(() {
//           _elapsed += const Duration(seconds: 1);
//         }),
//       );
//     } catch (e) {
//       _showSnackBar('Unable to start recording: $e', true);
//     }
//   }

//   Future<void> _stopRecording({required bool saveClip}) async {
//     try {
//       final isRecording = await _recorder.isRecording();
//       if (!isRecording) {
//         setState(() {
//           _isRecording = false;
//           _elapsed = Duration.zero;
//           _draftPath = null;
//         });
//         return;
//       }

//       final path = await _recorder.stop();
//       _ticker?.cancel();
//       final resolvedPath = path ?? _draftPath;

//       if (!mounted) return;
//       setState(() {
//         _isRecording = false;
//         _elapsed = Duration.zero;
//         _draftPath = null;
//       });

//       if (!saveClip) {
//         await _deleteIfExists(resolvedPath);
//         return;
//       }

//       if (resolvedPath == null) {
//         _showSnackBar('Recording not saved. Please try again.', true);
//         return;
//       }

//       final file = File(resolvedPath);
//       if (!await file.exists()) {
//         _showSnackBar('Audio file missing. Please record again.', true);
//         return;
//       }

//       widget.onSampleReady(resolvedPath);
//       _showSnackBar('Voice sample attached.');
//     } catch (e) {
//       if (!mounted) return;
//       _showSnackBar('Unable to finalize recording: $e', true);
//       setState(() {
//         _isRecording = false;
//         _elapsed = Duration.zero;
//         _draftPath = null;
//       });
//     }
//   }

//   Future<void> _deleteIfExists(String? path) async {
//     if (path == null) return;
//     final file = File(path);
//     if (await file.exists()) {
//       await file.delete();
//     }
//   }

//   void _showSnackBar(String message, [bool isError = false]) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? ColorManager.error : ColorManager.primary2,
//       ),
//     );
//   }

//   String? _fileName(String? path) {
//     if (path == null || path.isEmpty) return null;
//     final parts = path.split(RegExp(r'[\\/]'));
//     return parts.isNotEmpty ? parts.last : path;
//   }
// }

// class _RecordingIndicator extends StatelessWidget {
//   final Duration elapsed;

//   const _RecordingIndicator({required this.elapsed});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(AppSize.s12),
//       decoration: BoxDecoration(
//         color: ColorManager.error.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(AppSize.s12),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.fiber_manual_record, color: ColorManager.error),
//               const SizedBox(width: AppSize.s8),
//               const Text(
//                 'Recording...',
//                 style: TextStyle(fontWeight: FontWeight.w600),
//               ),
//             ],
//           ),
//           Text(_formatDuration(elapsed)),
//         ],
//       ),
//     );
//   }

//   String _formatDuration(Duration duration) {
//     final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final seconds = (duration.inSeconds.remainder(
//       60,
//     )).toString().padLeft(2, '0');
//     return '$minutes:$seconds';
//   }
// }

// class _DocumentUploadTile extends StatelessWidget {
//   final String title;
//   final String subtitle;
//   final String? filePath;
//   final VoidCallback onPick;

//   const _DocumentUploadTile({
//     required this.title,
//     required this.subtitle,
//     required this.filePath,
//     required this.onPick,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final fileName = _extractFileName(filePath);
//     return Card(
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(AppSize.s12),
//         side: BorderSide(color: ColorManager.primary.withValues(alpha: 0.2)),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(AppSize.s16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(title, style: Theme.of(context).textTheme.titleMedium),
//             const SizedBox(height: AppSize.s4),
//             Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
//             const SizedBox(height: AppSize.s12),
//             Row(
//               children: [
//                 Expanded(child: Text(fileName ?? 'No file selected yet')),
//                 ElevatedButton(
//                   onPressed: onPick,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: ColorManager.primary,
//                   ),
//                   child: const Text(
//                     'Upload',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String? _extractFileName(String? path) {
//     if (path == null || path.isEmpty) return null;
//     final segments = path.split(RegExp(r'[\\/]'));
//     return segments.isNotEmpty ? segments.last : path;
//   }
// }

// class _TrackSelectionStep extends StatelessWidget {
//   final InterpreterTrack currentTrack;
//   final bool isLevelLocked;
//   final ValueChanged<InterpreterTrack> onTrackSelected;

//   const _TrackSelectionStep({
//     required this.currentTrack,
//     required this.isLevelLocked,
//     required this.onTrackSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children:
//           InterpreterTrack.values.map((track) {
//             final isSelected = currentTrack == track;
//             final isDisabled = isLevelLocked && track == InterpreterTrack.paid;
//             return Card(
//               margin: const EdgeInsets.symmetric(vertical: 8),
//               child: ListTile(
//                 leading: Icon(
//                   track == InterpreterTrack.paid
//                       ? Icons.local_hospital
//                       : Icons.volunteer_activism,
//                   color:
//                       isSelected
//                           ? ColorManager.primary2
//                           : ColorManager.textPrimary,
//                 ),
//                 title: Text(track.label),
//                 subtitle: Text(
//                   track.description,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 trailing:
//                     isDisabled
//                         ? const Chip(label: Text('Beginner only'))
//                         : Radio<InterpreterTrack>(
//                           value: track,
//                           groupValue: currentTrack,
//                           onChanged:
//                               isDisabled
//                                   ? null
//                                   : (value) {
//                                     if (value != null) {
//                                       onTrackSelected(value);
//                                     }
//                                   },
//                         ),
//                 onTap: isDisabled ? null : () => onTrackSelected(track),
//               ),
//             );
//           }).toList(),
//     );
//   }
// }

// class _ShiftSelectionStep extends StatelessWidget {
//   final Set<InterpreterShift> selected;
//   final void Function(InterpreterShift shift, bool isSelected) onToggle;

//   const _ShiftSelectionStep({required this.selected, required this.onToggle});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Select at least one shift. Emergency adds 30% bonus.',
//           style: Theme.of(context).textTheme.bodySmall,
//         ),
//         const SizedBox(height: AppSize.s12),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children:
//               InterpreterShift.values.map((shift) {
//                 final isSelected = selected.contains(shift);
//                 return FilterChip(
//                   label: Text(shift.label),
//                   selected: isSelected,
//                   onSelected: (value) => onToggle(shift, value),
//                   tooltip: shift.description,
//                 );
//               }).toList(),
//         ),
//       ],
//     );
//   }
// }

// class _ReviewSummary extends StatelessWidget {
//   final InterpreterRegistrationState state;
//   const _ReviewSummary({required this.state});

//   @override
//   Widget build(BuildContext context) {
//     final app = state.application;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _SummaryRow(title: 'Level', value: app.level.label),
//         _SummaryRow(title: 'Track', value: app.track.label),
//         _SummaryRow(
//           title: 'Training Certificate',
//           value: app.hasGeneralCertificate ? 'Provided' : 'Missing',
//         ),
//         _SummaryRow(
//           title: 'Voice Sample',
//           value: app.hasVoiceSample ? 'Uploaded' : 'Missing',
//         ),
//         _SummaryRow(
//           title: 'General Quiz',
//           value: app.generalQuizPassed ? 'Passed ✓' : 'Not completed',
//         ),
//         if (app.track == InterpreterTrack.paid) ...[
//           _SummaryRow(
//             title: 'Medical Certificate',
//             value: app.hasMedicalCertificate ? 'Provided' : 'Missing',
//           ),
//           _SummaryRow(
//             title: 'Shift Availability',
//             value:
//                 app.shifts.isEmpty
//                     ? 'Not selected'
//                     : app.shifts.map((s) => s.label).join(', '),
//           ),
//           _SummaryRow(
//             title: 'Medical Badges',
//             value:
//                 app.medicalSectionsPassed.isEmpty
//                     ? 'None earned'
//                     : '${app.medicalSectionsPassed.length} earned',
//           ),
//         ],
//         const SizedBox(height: AppSize.s16),
//         Text(
//           state.canSubmit
//               ? 'Everything looks good. Submit to send for admin review.'
//               : 'Please complete the missing items above before submitting.',
//           style: Theme.of(context).textTheme.bodySmall,
//         ),
//       ],
//     );
//   }
// }

// class _SummaryRow extends StatelessWidget {
//   final String title;
//   final String value;

//   const _SummaryRow({required this.title, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               title,
//               style: Theme.of(
//                 context,
//               ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
//           ),
//         ],
//       ),
//     );
//   }
// }

//     );
//   }
// }

// class _MedicalSectionSelectorWrapper extends StatefulWidget {
//   const _MedicalSectionSelectorWrapper();

//   @override
//   State<_MedicalSectionSelectorWrapper> createState() =>
//       _MedicalSectionSelectorWrapperState();
// }

// class _MedicalSectionSelectorWrapperState
//     extends State<_MedicalSectionSelectorWrapper> {
//   final _supabase = SupabaseService();
//   final List<_MedicalSection> _sections = const [
//     _MedicalSection('neurology', 'Neurology', Icons.psychology),
//     _MedicalSection('cardiology', 'Cardiology', Icons.favorite),
//     _MedicalSection('respiratory', 'Respiratory', Icons.air),
//     _MedicalSection('gastrointestinal', 'Gastrointestinal', Icons.medication),
//     _MedicalSection('endocrinology', 'Endocrinology', Icons.water_drop),
//     _MedicalSection('renal', 'Renal System', Icons.opacity),
//     _MedicalSection('ob_gyn', 'OB/GYN', Icons.pregnant_woman),
//     _MedicalSection('oncology', 'Oncology', Icons.healing),
//     _MedicalSection('emergency', 'Emergency', Icons.emergency),
//     _MedicalSection('psychology', 'Psychology', Icons.spa),
//     _MedicalSection('musculoskeletal', 'Musculoskeletal', Icons.accessibility),
//   ];

//   Map<String, bool> _earnedBadges = {};
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserBadges();
//   }

//   Future<void> _loadUserBadges() async {
//     try {
//       final user = _supabase.getCurrentUser();
//       if (user != null) {
//         final badges = await _supabase.getUserBadges(user.id);
//         setState(() {
//           _earnedBadges = {
//             for (var b in badges) b['badge_type'] as String: true,
//           };
//           _loading = false;
//         });
//       } else {
//         setState(() => _loading = false);
//       }
//     } catch (e) {
//       setState(() => _loading = false);
//       debugPrint('Failed to load badges: $e');
//     }
//   }

//   Future<void> _startSection(String sectionId) async {
//     final result = await Navigator.of(context).push<Map<String, dynamic>>(
//       MaterialPageRoute(
//         builder: (_) => QuizScreen(
//           quizType: 'medical',
//           medicalSection: sectionId,
//         ),
//       ),
//     );

//     if (result != null && result['passed'] == true) {
//       // Notify the BLoC
//       if (mounted) {
//         context.read<InterpreterRegistrationBloc>().add(
//           InterpreterMedicalSectionCompleted(
//             sectionId: sectionId,
//             passed: true,
//           ),
//         );
//       }
//       // Reload badges
//       await _loadUserBadges();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       backgroundColor: ColorManager.backgroundPrimary,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, size: 20),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: const Text('Medical Specializations'),
//         centerTitle: true,
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(AppSize.s16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Earn Badges',
//                     style: theme.textTheme.headlineSmall?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Score 80%+ on each section quiz to earn a badge',
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       color: ColorManager.textSecondary,
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   Expanded(
//                     child: GridView.builder(
//                       gridDelegate:
//                           const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 2,
//                         crossAxisSpacing: 16,
//                         mainAxisSpacing: 16,
//                         childAspectRatio: 1.1,
//                       ),
//                       itemCount: _sections.length,
//                       itemBuilder: (context, index) {
//                         final section = _sections[index];
//                         final earned = _earnedBadges[section.id] == true;
//                         return _SectionCard(
//                           section: section,
//                           earned: earned,
//                           onTap: () => _startSection(section.id),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//     );
//   }
// }

// class _MedicalSection {
//   final String id;
//   final String name;
//   final IconData icon;

//   const _MedicalSection(this.id, this.name, this.icon);
// }

// class _SectionCard extends StatelessWidget {
//   final _MedicalSection section;
//   final bool earned;
//   final VoidCallback onTap;

//   const _SectionCard({
//     required this.section,
//     required this.earned,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color:
//                 earned
//                     ? ColorManager.success
//                     : ColorManager.greyLight,
//             width: earned ? 2 : 1,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Stack(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color:
//                         earned
//                             ? ColorManager.success.withValues(alpha: 0.1)
//                             : ColorManager.primary2.withValues(alpha: 0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     section.icon,
//                     size: 32,
//                     color:
//                         earned ? ColorManager.success : ColorManager.primary2,
//                   ),
//                 ),
//                 if (earned)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         color: ColorManager.success,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.check,
//                         size: 12,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Text(
//               section.name,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//             if (earned) ...[
//               const SizedBox(height: 4),
//               Text(
//                 'Earned',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: ColorManager.success,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _GeneralQuizStep extends StatelessWidget {
//   final bool passed;
//   final VoidCallback onLaunchQuiz;

//   const _GeneralQuizStep({
//     required this.passed,
//     required this.onLaunchQuiz,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Complete the general interpretation assessment. Required for all interpreters. Minimum passing score: 70%.',
//           style: Theme.of(context).textTheme.bodySmall,
//         ),
//         const SizedBox(height: AppSize.s12),
//         if (passed)
//           Card(
//             elevation: 0,
//             color: Colors.green.withValues(alpha: 0.08),
//             child: const  ListTile(
//               leading: const const const const const const = const const const const const const Icon(Icons.check_circle, color: Colors.green),
//               title: const Text('General Quiz Passed'),
//               subtitle: const Text('You can proceed to the next step'),
//             ),
//           ),
//         const SizedBox(height: AppSize.s12),
//         ElevatedButton.icon(
//           onPressed: onLaunchQuiz,
//           icon: const Icon(Icons.quiz, color: Colors.white),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: ColorManager.primary,
//           ),
//           label: Text(
//             passed ? 'Retake assessment' : 'Start general quiz',
//             style: const TextStyle(color: Colors.white),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _MedicalSectionsStep extends StatelessWidget {
//   final int sectionsCount;
//   final VoidCallback onLaunchSelector;

//   const _MedicalSectionsStep({
//     required this.sectionsCount,
//     required this.onLaunchSelector,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Earn badges by completing medical specialization quizzes. Pass at least one section to qualify for paid medical calls. Minimum passing score: 80%.',
//           style: Theme.of(context).textTheme.bodySmall,
//         ),
//         const SizedBox(height: AppSize.s12),
//         if (sectionsCount > 0)
//           Card(
//             elevation: 0,
//             color: Colors.green.withValues(alpha: 0.08),
//             child: ListTile(
//               leading:st const const const const const const Icon(Icons.verified, color: Colors.green),
//               title: Text('$sectionsCount Badge${sectionsCount == 1 ? '' : 's'} Earned'),
//               subtitle: const Text('Great job! You can continue.'),
//             ),
//           ),
//         const SizedBox(height: AppSize.s12),
//         ElevatedButton.icon(
//           onPressed: onLaunchSelector,
//           icon: const Icon(Icons.school, color: Colors.white),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: ColorManager.primary2,
//           ),
//           label: Text(
//             sectionsCount > 0 ? 'Earn more badges' : 'Start medical quizzes',
//             style: const TextStyle(color: Colors.white),
//           ),
//         ),
//       ],
//     );
//   }
// }
