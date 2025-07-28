import 'package:equatable/equatable.dart';

abstract class SelectFieldEvent extends Equatable {
  const SelectFieldEvent();
  @override
  List<Object?> get props => [];
}

class InitializeFields extends SelectFieldEvent {
  final List<String> fields;
  const InitializeFields(this.fields);
  @override
  List<Object?> get props => [fields];
}

class ToggleField extends SelectFieldEvent {
  final String field;
  const ToggleField(this.field);
  @override
  List<Object?> get props => [field];
}

class CustomFieldChanged extends SelectFieldEvent {
  final String value;
  const CustomFieldChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class SubmitFields extends SelectFieldEvent {} 