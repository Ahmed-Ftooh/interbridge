import 'package:equatable/equatable.dart';

abstract class SelectLanguageEvent extends Equatable {
  const SelectLanguageEvent();
  @override
  List<Object?> get props => [];
}

class InitializeLanguages extends SelectLanguageEvent {
  final List<String> languages;
  const InitializeLanguages(this.languages);
  @override
  List<Object?> get props => [languages];
}

class ToggleLanguage extends SelectLanguageEvent {
  final String language;
  const ToggleLanguage(this.language);
  @override
  List<Object?> get props => [language];
}

class SearchLanguageChanged extends SelectLanguageEvent {
  final String query;
  const SearchLanguageChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class SubmitLanguages extends SelectLanguageEvent {}
