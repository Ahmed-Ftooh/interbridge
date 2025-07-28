import 'package:equatable/equatable.dart';

abstract class LanguageFluencyEvent extends Equatable {
  const LanguageFluencyEvent();
  @override
  List<Object?> get props => [];
}

class InitializeLanguages extends LanguageFluencyEvent {
  final List<String> selectedLanguages;
  const InitializeLanguages(this.selectedLanguages);
  @override
  List<Object?> get props => [selectedLanguages];
}

class SelectFluency extends LanguageFluencyEvent {
  final String fluency;
  const SelectFluency(this.fluency);
  @override
  List<Object?> get props => [fluency];
}

class ToggleSkill extends LanguageFluencyEvent {
  final String skill;
  const ToggleSkill(this.skill);
  @override
  List<Object?> get props => [skill];
}

class NextLanguage extends LanguageFluencyEvent {}

class PreviousLanguage extends LanguageFluencyEvent {}

class SubmitLanguages extends LanguageFluencyEvent {}
