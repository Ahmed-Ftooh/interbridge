import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'select_field_event.dart';
import 'select_field_state.dart';

class SelectFieldBloc extends Bloc<SelectFieldEvent, SelectFieldState> {
  SelectFieldBloc() : super(const SelectFieldState()) {
    on<InitializeFields>((event, emit) {
      emit(state.copyWith(allFields: event.fields));
    });
    on<ToggleField>((event, emit) {
      final selected = List<String>.from(state.selectedFields);

      // Check if the clicked field is "None of the above"
      if (event.field == AppStrings.noneOfTheAbove) {
        if (selected.contains(AppStrings.noneOfTheAbove)) {
          // If "None of the above" is already selected, unselect it
          selected.remove(AppStrings.noneOfTheAbove);
        } else {
          // If "None of the above" is being selected, clear all other selections
          selected.clear();
          selected.add(AppStrings.noneOfTheAbove);
        }
      } else {
        // If any other field is being selected
        if (selected.contains(event.field)) {
          // If the field is already selected, unselect it
          selected.remove(event.field);
        } else {
          // If the field is being selected, first remove "None of the above" if it's selected
          selected.remove(AppStrings.noneOfTheAbove);
          // Then add the new field
          selected.add(event.field);
        }
      }

      emit(state.copyWith(selectedFields: selected));
    });
    on<CustomFieldChanged>((event, emit) {
      emit(state.copyWith(customField: event.value));
    });
    on<SubmitFields>((event, emit) async {
      emit(
        state.copyWith(isSubmitting: true, isFailure: false, isSuccess: false),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (state.selectedFields.isEmpty && state.customField.trim().isEmpty) {
        emit(
          state.copyWith(
            isSubmitting: false,
            isFailure: true,
            errorMessage: 'Please select or enter a field',
          ),
        );
        return;
      }
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    });
  }
}
