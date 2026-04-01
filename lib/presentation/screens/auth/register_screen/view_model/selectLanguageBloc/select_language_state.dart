import 'package:equatable/equatable.dart';

class SelectLanguageState extends Equatable {
  final List<String> allLanguages;
  final Map<String, bool> selectedLanguages;
  final String searchQuery;
  final bool isSubmitting;
  final bool isSuccess;
  final bool isFailure;
  final String? errorMessage;

  const SelectLanguageState({
    this.allLanguages = const [],
    this.selectedLanguages = const {},
    this.searchQuery = '',
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isFailure = false,
    this.errorMessage,
  });

  SelectLanguageState copyWith({
    List<String>? allLanguages,
    Map<String, bool>? selectedLanguages,
    String? searchQuery,
    bool? isSubmitting,
    bool? isSuccess,
    bool? isFailure,
    String? errorMessage,
  }) {
    return SelectLanguageState(
      allLanguages: allLanguages ?? this.allLanguages,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      searchQuery: searchQuery ?? this.searchQuery,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isFailure: isFailure ?? this.isFailure,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    allLanguages,
    selectedLanguages,
    searchQuery,
    isSubmitting,
    isSuccess,
    isFailure,
    errorMessage,
  ];
}
