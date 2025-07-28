import 'package:flutter_bloc/flutter_bloc.dart';
import 'language_fluency_event.dart';
import 'language_fluency_state.dart';

class LanguageFluencyBloc
    extends Bloc<LanguageFluencyEvent, LanguageFluencyState> {
  LanguageFluencyBloc() : super(const LanguageFluencyState()) {
    on<InitializeLanguages>((event, emit) {
      final fluencyMap = <String, String?>{};
      final skillsMap = <String, Set<String>>{};
      for (var lang in event.selectedLanguages) {
        fluencyMap[lang] = null;
        skillsMap[lang] = <String>{};
      }
      emit(
        state.copyWith(
          selectedLanguages: event.selectedLanguages,
          fluencyMap: fluencyMap,
          skillsMap: skillsMap,
          currentLanguageIndex: 0,
          isSelectingFluency: true,
          isComplete: false,
          errorMessage: null,
        ),
      );
    });
    on<SelectFluency>((event, emit) {
      final lang = state.selectedLanguages[state.currentLanguageIndex];
      final newFluencyMap = Map<String, String?>.from(state.fluencyMap);
      newFluencyMap[lang] = event.fluency;
      emit(
        state.copyWith(
          fluencyMap: newFluencyMap,
          isSelectingFluency: false,
          errorMessage: null,
        ),
      );
    });
    on<ToggleSkill>((event, emit) {
      final lang = state.selectedLanguages[state.currentLanguageIndex];
      final newSkillsMap = Map<String, Set<String>>.from(state.skillsMap);
      final skills = Set<String>.from(newSkillsMap[lang] ?? {});
      if (skills.contains(event.skill)) {
        skills.remove(event.skill);
      } else {
        skills.add(event.skill);
      }
      newSkillsMap[lang] = skills;
      emit(state.copyWith(skillsMap: newSkillsMap));
    });
    on<NextLanguage>((event, emit) {
      if (state.currentLanguageIndex < state.selectedLanguages.length - 1) {
        emit(
          state.copyWith(
            currentLanguageIndex: state.currentLanguageIndex + 1,
            isSelectingFluency: true,
            errorMessage: null,
          ),
        );
      } else {
        add(SubmitLanguages());
      }
    });
    on<PreviousLanguage>((event, emit) {
      if (state.currentLanguageIndex > 0) {
        emit(
          state.copyWith(
            currentLanguageIndex: state.currentLanguageIndex - 1,
            isSelectingFluency: true,
            errorMessage: null,
          ),
        );
      }
    });
    on<SubmitLanguages>((event, emit) {
      for (var lang in state.selectedLanguages) {
        if (state.fluencyMap[lang] == null) {
          emit(
            state.copyWith(
              errorMessage: 'Please select fluency level for $lang',
            ),
          );
          return;
        }
      }
      emit(state.copyWith(isComplete: true, errorMessage: null));
    });
  }
}
