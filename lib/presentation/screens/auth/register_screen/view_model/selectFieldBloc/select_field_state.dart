import 'package:equatable/equatable.dart';

class SelectFieldState extends Equatable {
  final List<String> allFields;
  final List<String> selectedFields;
  final String customField;
  final bool isSubmitting;
  final bool isSuccess;
  final bool isFailure;
  final String? errorMessage;

  const SelectFieldState({
    this.allFields = const [],
    this.selectedFields = const [],
    this.customField = '',
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isFailure = false,
    this.errorMessage,
  });

  SelectFieldState copyWith({
    List<String>? allFields,
    List<String>? selectedFields,
    String? customField,
    bool? isSubmitting,
    bool? isSuccess,
    bool? isFailure,
    String? errorMessage,
  }) {
    return SelectFieldState(
      allFields: allFields ?? this.allFields,
      selectedFields: selectedFields ?? this.selectedFields,
      customField: customField ?? this.customField,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isFailure: isFailure ?? this.isFailure,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    allFields,
    selectedFields,
    customField,
    isSubmitting,
    isSuccess,
    isFailure,
    errorMessage,
  ];
}
