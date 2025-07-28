import 'package:flutter_bloc/flutter_bloc.dart';
import 'select_language_event.dart';
import 'select_language_state.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';

class SelectLanguageBloc
    extends Bloc<SelectLanguageEvent, SelectLanguageState> {
  SelectLanguageBloc() : super(const SelectLanguageState()) {
    on<InitializeLanguages>((event, emit) {
      final selected = {for (var lang in event.languages) lang: false};
      // Select 'English' by default if present
      if (selected.containsKey('English')) {
        selected['English'] = true;
      }
      emit(
        state.copyWith(
          allLanguages: event.languages,
          selectedLanguages: selected,
        ),
      );
    });
    on<ToggleLanguage>((event, emit) {
      final selected = Map<String, bool>.from(state.selectedLanguages);
      selected[event.language] = !(selected[event.language] ?? false);
      emit(state.copyWith(selectedLanguages: selected));
    });
    on<SearchLanguageChanged>((event, emit) {
      emit(state.copyWith(searchQuery: event.query));
    });
    on<SubmitLanguages>((event, emit) async {
      emit(
        state.copyWith(isSubmitting: true, isFailure: false, isSuccess: false),
      );
      await Future.delayed(const Duration(seconds: 1));
      final selectedCount =
          state.selectedLanguages.values.where((v) => v).length;
      if (selectedCount < 2) {
        emit(
          state.copyWith(
            isSubmitting: false,
            isFailure: true,
            errorMessage: AppStrings.pleaseSelectAtLeastTwoLanguages,
          ),
        );
        return;
      }
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    });
  }
}
