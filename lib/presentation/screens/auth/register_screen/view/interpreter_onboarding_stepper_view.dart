// import 'dart:convert';
// import 'dart:io';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:get_it/get_it.dart';
// import 'package:interbridge/app/app_prf.dart';
// import 'package:interbridge/data/models/fluency_level.dart';
// import 'package:interbridge/data/models/language.dart';
// import 'package:interbridge/data/models/skill.dart';
// import 'package:interbridge/data/models/specialization.dart';
// import 'package:interbridge/data/services/supabase_service.dart';
// import 'package:interbridge/presentation/resources/color_manager.dart';
// import 'package:interbridge/presentation/resources/routes_manager.dart';

// class InterpreterOnboardingStepperView extends StatefulWidget {
//   const InterpreterOnboardingStepperView({super.key});

//   @override
//   State<InterpreterOnboardingStepperView> createState() =>
//       _InterpreterOnboardingStepperViewState();
// }

// class _InterpreterOnboardingStepperViewState
//     extends State<InterpreterOnboardingStepperView> {
//   final SupabaseService _supabase = GetIt.I<SupabaseService>();
//   final AppPreferences _prefs = GetIt.I<AppPreferences>();

//   int _currentStep = 0;

//   // Catalog data
//   List<Language> _languages = [];
//   List<FluencyLevel> _fluencyLevels = [];
//   List<Skill> _skills = [];
//   List<Specialization> _specializations = [];

//   // Form state
//   final Set<int> _selectedLanguageIds = {};
//   final Map<int, int> _languageFluency = {}; // languageId -> fluencyId
//   final Set<int> _selectedSkillIds = {};
//   final Set<int> _selectedSpecializationIds = {};
//   File? _certificateFile;
//   final TextEditingController _bioController = TextEditingController();
//   final TextEditingController _yearsController = TextEditingController();

//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _bootstrap();
//   }

//   Future<void> _bootstrap() async {
//     try {
//       final langs = await _supabase.getLanguages();
//       final fluencies = await _supabase.getFluencyLevels();
//       final skills = await _supabase.getSkills();
//       final specs = await _supabase.getSpecializations();

//       // Load any pending draft
//       final pending = _prefs.getPendingRegistration();
//       if (pending != null) {
//         final data = jsonDecode(pending) as Map<String, dynamic>;
//         final role = data['role'];
//         if (role == 'interpreter') {
//           final langsList =
//               (data['languages'] as List?)
//                   ?.map((e) => int.tryParse(e.toString()))
//                   .whereType<int>()
//                   .toList() ??
//               [];
//           _selectedLanguageIds.addAll(langsList);
//           final flu = (data['fluency'] as Map?) ?? {};
//           _languageFluency
//             ..clear()
//             ..addAll(
//               flu.map(
//                 (k, v) => MapEntry(
//                   int.tryParse(k.toString()) ?? -1,
//                   int.tryParse(v?.toString() ?? '') ?? 0,
//                 ),
//               )..removeWhere((key, value) => key <= 0 || value <= 0),
//             );
//           _selectedSkillIds.addAll(
//             ((data['skillIds'] ?? data['skills']) as List?)
//                     ?.map((e) => int.tryParse(e.toString()))
//                     .whereType<int>() ??
//                 {},
//           );
//           // Load specialization IDs but filter to only valid ones that still exist
//           final savedSpecIds =
//               ((data['specializationIds'] ?? data['specializations']) as List?)
//                   ?.map((e) => int.tryParse(e.toString()))
//                   .whereType<int>()
//                   .toSet() ??
//               {};
//           // Filter against valid specialization IDs from database
//           final validSpecIds = specs.map((s) => s.id).toSet();
//           _selectedSpecializationIds.addAll(
//             savedSpecIds.where((id) => validSpecIds.contains(id)),
//           );
//           final certPath = data['certificatePath'] as String?;
//           if (certPath != null && certPath.isNotEmpty) {
//             final f = File(certPath);
//             if (await f.exists()) _certificateFile = f;
//           }
//           _bioController.text = (data['bio'] as String?) ?? '';
//           final years = data['yearsExperience']?.toString();
//           if (years != null) _yearsController.text = years;
//         }
//       }

//       setState(() {
//         _languages = langs;
//         _fluencyLevels = fluencies;
//         _skills = skills;
//         _specializations = specs;
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() => _loading = false);
//     }
//   }

//   void _autosave() {
//     final data = {
//       'role': 'interpreter',
//       'languages': _selectedLanguageIds.map((e) => e.toString()).toList(),
//       'fluency': _languageFluency.map(
//         (k, v) => MapEntry(k.toString(), v.toString()),
//       ),
//       'skills': _selectedSkillIds.toList(),
//       'specializations': _selectedSpecializationIds.toList(),
//       'certificatePath': _certificateFile?.path,
//       'bio': _bioController.text,
//       'yearsExperience': int.tryParse(_yearsController.text),
//     };
//     _prefs.savePendingRegistration(jsonEncode(data));
//   }

//   Future<void> _pickCertificate() async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
//     );
//     if (result != null && result.files.single.path != null) {
//       setState(() {
//         _certificateFile = File(result.files.single.path!);
//       });
//       _autosave();
//     }
//   }

//   bool _canContinueStep(int step) {
//     switch (step) {
//       case 0:
//         return _selectedLanguageIds.isNotEmpty;
//       case 1:
//         // fluency for every selected language
//         return _selectedLanguageIds.every(
//           (id) => (_languageFluency[id] ?? 0) > 0,
//         );
//       case 2:
//         return _selectedSkillIds.isNotEmpty;
//       case 3:
//         return _selectedSpecializationIds.isNotEmpty;
//       case 4:
//         return _certificateFile != null;
//       case 5:
//         // Profile optional; allow continue
//         return true;
//       case 6:
//         // Review step; always allow continue
//         return true;
//       default:
//         return true;
//     }
//   }

//   void _continue() {
//     if (_currentStep < 6) {
//       if (_canContinueStep(_currentStep)) {
//         setState(() => _currentStep += 1);
//       }
//       return;
//     }
//     // Final review -> navigate to RegisterView with arguments
//     final args = {
//       'role': 'interpreter',
//       'languages': _selectedLanguageIds.map((e) => e.toString()).toList(),
//       'fluency': _languageFluency.map(
//         (k, v) => MapEntry(k.toString(), v.toString()),
//       ),
//       'skills': _selectedSkillIds.toList(),
//       'specializations': _selectedSpecializationIds.toList(),
//       'certificatePath': _certificateFile?.path,
//       // Extras retained in draft only for now
//       'bio': _bioController.text,
//       'yearsExperience': int.tryParse(_yearsController.text),
//     };
//     Navigator.of(context).pushNamed(Routes.registerRoute, arguments: args);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Interpreter Onboarding')),
//       body:
//           _loading
//               ? const Center(child: CircularProgressIndicator())
//               : Column(
//                 children: [
//                   Expanded(
//                     child: Stepper(
//                       currentStep: _currentStep,
//                       onStepContinue: () {
//                         if (_canContinueStep(_currentStep)) {
//                           _continue();
//                         }
//                       },
//                       onStepCancel: () {
//                         if (_currentStep > 0) setState(() => _currentStep -= 1);
//                       },
//                       controlsBuilder: (context, details) {
//                         final can = _canContinueStep(_currentStep);
//                         return Row(
//                           children: [
//                             ElevatedButton(
//                               onPressed: can ? details.onStepContinue : null,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: ColorManager.primary,
//                               ),
//                               child: Text(
//                                 _currentStep < 6
//                                     ? 'Next'
//                                     : 'Continue to Sign Up',
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             if (_currentStep > 0)
//                               TextButton(
//                                 onPressed: details.onStepCancel,
//                                 child: const Text('Back'),
//                               ),
//                           ],
//                         );
//                       },
//                       steps: [
//                         Step(
//                           title: const Text('Languages'),
//                           content: _buildLanguagesStep(),
//                           isActive: _currentStep >= 0,
//                           state:
//                               _currentStep > 0
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                         Step(
//                           title: const Text('Fluency'),
//                           content: _buildFluencyStep(),
//                           isActive: _currentStep >= 1,
//                           state:
//                               _currentStep > 1
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                         Step(
//                           title: const Text('Skills'),
//                           content: _buildSkillsStep(),
//                           isActive: _currentStep >= 2,
//                           state:
//                               _currentStep > 2
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                         Step(
//                           title: const Text('Specializations'),
//                           content: _buildSpecializationsStep(),
//                           isActive: _currentStep >= 3,
//                           state:
//                               _currentStep > 3
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                         Step(
//                           title: const Text('Certificate'),
//                           content: _buildCertificateStep(),
//                           isActive: _currentStep >= 4,
//                           state:
//                               _currentStep > 4
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                         Step(
//                           title: const Text('Profile'),
//                           content: _buildProfileStep(),
//                           isActive: _currentStep >= 5,
//                           state:
//                               _currentStep > 5
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                         Step(
//                           title: const Text('Review'),
//                           content: _buildReviewStep(),
//                           isActive: _currentStep >= 6,
//                           state:
//                               _currentStep > 6
//                                   ? StepState.complete
//                                   : StepState.indexed,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//     );
//   }

//   Widget _buildLanguagesStep() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text('Select your languages'),
//         const SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children:
//               _languages.map((lang) {
//                 final selected = _selectedLanguageIds.contains(lang.id);
//                 return FilterChip(
//                   label: Text(lang.name),
//                   selected: selected,
//                   onSelected: (v) {
//                     setState(() {
//                       if (v) {
//                         _selectedLanguageIds.add(lang.id);
//                       } else {
//                         _selectedLanguageIds.remove(lang.id);
//                         _languageFluency.remove(lang.id);
//                       }
//                     });
//                     _autosave();
//                   },
//                 );
//               }).toList(),
//         ),
//       ],
//     );
//   }

//   Widget _buildFluencyStep() {
//     final selectedLangs =
//         _languages.where((l) => _selectedLanguageIds.contains(l.id)).toList();
//     return Column(
//       children:
//           selectedLangs.map((lang) {
//             final selectedFluencyId = _languageFluency[lang.id];
//             return Padding(
//               padding: const EdgeInsets.symmetric(vertical: 8.0),
//               child: Row(
//                 children: [
//                   Expanded(child: Text(lang.name)),
//                   const SizedBox(width: 12),
//                   DropdownButton<int>(
//                     value:
//                         (selectedFluencyId != null && selectedFluencyId > 0)
//                             ? selectedFluencyId
//                             : null,
//                     hint: const Text('Select fluency'),
//                     items:
//                         _fluencyLevels
//                             .map(
//                               (f) => DropdownMenuItem<int>(
//                                 value: f.id,
//                                 child: Text(f.level),
//                               ),
//                             )
//                             .toList(),
//                     onChanged: (v) {
//                       setState(() {
//                         if (v != null) _languageFluency[lang.id] = v;
//                       });
//                       _autosave();
//                     },
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//     );
//   }

//   Widget _buildSkillsStep() {
//     return Column(
//       children:
//           _skills.map((s) {
//             final selected = _selectedSkillIds.contains(s.id);
//             return CheckboxListTile(
//               value: selected,
//               onChanged: (v) {
//                 setState(() {
//                   if (v == true) {
//                     _selectedSkillIds.add(s.id);
//                   } else {
//                     _selectedSkillIds.remove(s.id);
//                   }
//                 });
//                 _autosave();
//               },
//               title: Text(s.name),
//             );
//           }).toList(),
//     );
//   }

//   Widget _buildSpecializationsStep() {
//     return Column(
//       children:
//           _specializations.map((sp) {
//             final selected = _selectedSpecializationIds.contains(sp.id);
//             return CheckboxListTile(
//               value: selected,
//               onChanged: (v) {
//                 setState(() {
//                   if (v == true) {
//                     _selectedSpecializationIds.add(sp.id);
//                   } else {
//                     _selectedSpecializationIds.remove(sp.id);
//                   }
//                 });
//                 _autosave();
//               },
//               title: Text(sp.name),
//             );
//           }).toList(),
//     );
//   }

//   Widget _buildCertificateStep() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text('Upload your certificate (PDF/JPG/PNG)'),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: Text(
//                 _certificateFile != null
//                     ? _certificateFile!.path.split('/').last
//                     : 'No file selected',
//                 overflow: TextOverflow.ellipsis,
//                 maxLines: 1,
//               ),
//             ),
//             TextButton.icon(
//               onPressed: _pickCertificate,
//               icon: const Icon(Icons.upload_file),
//               label: const Text('Choose'),
//             ),
//           ],
//         ),
//         if (_certificateFile == null)
//           const Padding(
//             padding: EdgeInsets.only(top: 8.0),
//             child: Text(
//               'Certificate is required to continue',
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildProfileStep() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         TextField(
//           controller: _bioController,
//           maxLines: 4,
//           decoration: const InputDecoration(labelText: 'Short bio'),
//           onChanged: (_) => _autosave(),
//         ),
//         const SizedBox(height: 12),
//         TextField(
//           controller: _yearsController,
//           keyboardType: TextInputType.number,
//           decoration: const InputDecoration(labelText: 'Years of experience'),
//           onChanged: (_) => _autosave(),
//         ),
//         const SizedBox(height: 8),
//         const Text('You can review everything on next step.'),
//       ],
//     );
//   }

//   Widget _buildReviewStep() {
//     String langNames = _languages
//         .where((l) => _selectedLanguageIds.contains(l.id))
//         .map((l) => l.name)
//         .join(', ');
//     final skillNames = _skills
//         .where((s) => _selectedSkillIds.contains(s.id))
//         .map((s) => s.name)
//         .join(', ');
//     final specNames = _specializations
//         .where((s) => _selectedSpecializationIds.contains(s.id))
//         .map((s) => s.name)
//         .join(', ');

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _reviewRow('Languages', langNames.isEmpty ? '-' : langNames),
//         _reviewRow(
//           'Fluency set for',
//           '${_languageFluency.length}/${_selectedLanguageIds.length} languages',
//         ),
//         _reviewRow('Skills', skillNames.isEmpty ? '-' : skillNames),
//         _reviewRow('Specializations', specNames.isEmpty ? '-' : specNames),
//         _reviewRow(
//           'Certificate',
//           _certificateFile != null
//               ? _certificateFile!.path.split('/').last
//               : 'Not provided',
//         ),
//         _reviewRow(
//           'Bio',
//           _bioController.text.isEmpty ? '-' : _bioController.text,
//         ),
//         _reviewRow(
//           'Years experience',
//           _yearsController.text.isEmpty ? '-' : _yearsController.text,
//         ),
//         const SizedBox(height: 8),
//         const Text('Press Continue to complete account sign up.'),
//       ],
//     );
//   }

//   Widget _reviewRow(String title, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 140,
//             child: Text(
//               title,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _bioController.dispose();
//     _yearsController.dispose();
//     super.dispose();
//   }
// }
