import 'package:equatable/equatable.dart';

class LanguageFluencyState extends Equatable {
  final List<String> selectedLanguages;
  final int currentLanguageIndex;
  final Map<String, String?> fluencyMap;
  final Map<String, Set<String>> skillsMap;
  final bool isSelectingFluency;
  final bool isComplete;
  final String? errorMessage;

  const LanguageFluencyState({
    this.selectedLanguages = const [],
    this.currentLanguageIndex = 0,
    this.fluencyMap = const {},
    this.skillsMap = const {},
    this.isSelectingFluency = true,
    this.isComplete = false,
    this.errorMessage,
  });

  LanguageFluencyState copyWith({
    List<String>? selectedLanguages,
    int? currentLanguageIndex,
    Map<String, String?>? fluencyMap,
    Map<String, Set<String>>? skillsMap,
    bool? isSelectingFluency,
    bool? isComplete,
    String? errorMessage,
  }) {
    return LanguageFluencyState(
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      currentLanguageIndex: currentLanguageIndex ?? this.currentLanguageIndex,
      fluencyMap: fluencyMap ?? this.fluencyMap,
      skillsMap: skillsMap ?? this.skillsMap,
      isSelectingFluency: isSelectingFluency ?? this.isSelectingFluency,
      isComplete: isComplete ?? this.isComplete,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    selectedLanguages,
    currentLanguageIndex,
    fluencyMap,
    skillsMap,
    isSelectingFluency,
    isComplete,
    errorMessage,
  ];
}
