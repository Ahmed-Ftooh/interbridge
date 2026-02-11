// States for Document Translation BLoC
import 'package:equatable/equatable.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/models/language.dart';

abstract class DocumentTranslationState extends Equatable {
  const DocumentTranslationState();
  @override
  List<Object?> get props => [];
}

class DocumentTranslationInitial extends DocumentTranslationState {}

class DocumentTranslationLoading extends DocumentTranslationState {}

class DocumentTranslationLoadSuccess extends DocumentTranslationState {
  /// All languages for "from" selection (client language)
  final List<Language> allLanguages;

  /// Interpreter languages for "to" selection (patient language)
  final List<Language> interpreterLanguages;
  final List<DocumentTranslationRequest> requests;
  const DocumentTranslationLoadSuccess({
    this.allLanguages = const [],
    this.interpreterLanguages = const [],
    this.requests = const [],
  });
  @override
  List<Object?> get props => [allLanguages, interpreterLanguages, requests];
}

class DocumentTranslationOperationSuccess extends DocumentTranslationState {}

class DocumentTranslationOperationFailure extends DocumentTranslationState {
  final String error;
  const DocumentTranslationOperationFailure(this.error);
  @override
  List<Object?> get props => [error];
}
