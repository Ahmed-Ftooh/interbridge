// Events for Document Translation BLoC
import 'package:equatable/equatable.dart';

abstract class DocumentTranslationEvent extends Equatable {
  const DocumentTranslationEvent();
  @override
  List<Object?> get props => [];
}

class LoadLanguages extends DocumentTranslationEvent {}

class LoadUserRequests extends DocumentTranslationEvent {}

class LoadInterpreterRequests extends DocumentTranslationEvent {}

class SubmitRequest extends DocumentTranslationEvent {
  final String fromLanguage;
  final String toLanguage;
  final String? specialization;
  final String? text;
  final String? title;
  final String? comment;
  final String translationMethod;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  const SubmitRequest({
    required this.fromLanguage,
    required this.toLanguage,
    required this.translationMethod,
    this.specialization,
    this.text,
    this.title,
    this.comment,
    this.fileUrl,
    this.fileType,
    this.fileName,
  });
  @override
  List<Object?> get props => [
    fromLanguage,
    toLanguage,
    specialization,
    text,
    title,
    comment,
    translationMethod,
    fileUrl,
    fileType,
    fileName,
  ];
}

class DeleteRequest extends DocumentTranslationEvent {
  final String requestId;
  const DeleteRequest(this.requestId);
  @override
  List<Object?> get props => [requestId];
}

// More can be added as needed, e.g., AcceptRequest, CompleteRequest, HideRequest, etc.
