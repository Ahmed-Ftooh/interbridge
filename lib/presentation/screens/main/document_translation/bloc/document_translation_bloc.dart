import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'document_translation_event.dart';
import 'document_translation_state.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/document_translation_request.dart';
import 'package:interbridge/data/models/language.dart';

class DocumentTranslationBloc
    extends Bloc<DocumentTranslationEvent, DocumentTranslationState> {
  final DocumentTranslationService translationService;
  final SupabaseService supabaseService;

  DocumentTranslationBloc({
    required this.translationService,
    required this.supabaseService,
  }) : super(DocumentTranslationInitial()) {
    on<LoadLanguages>(_onLoadLanguages);
    on<LoadUserRequests>(_onLoadUserRequests);
    on<SubmitRequest>(_onSubmitRequest);
    on<DeleteRequest>(_onDeleteRequest);
  }

  Future<void> _onLoadLanguages(
    LoadLanguages event,
    Emitter<DocumentTranslationState> emit,
  ) async {
    // Don't emit loading if we already have a success state to preserve
    if (state is! DocumentTranslationLoadSuccess) {
      emit(DocumentTranslationLoading());
    }
    try {
      final languages = await supabaseService.getLanguages();
      // Preserve existing requests if we have them
      if (state is DocumentTranslationLoadSuccess) {
        final currentState = state as DocumentTranslationLoadSuccess;
        emit(
          DocumentTranslationLoadSuccess(
            languages: languages,
            requests: currentState.requests,
          ),
        );
      } else {
        emit(DocumentTranslationLoadSuccess(languages: languages));
      }
    } catch (e) {
      emit(DocumentTranslationOperationFailure(e.toString()));
    }
  }

  Future<void> _onLoadUserRequests(
    LoadUserRequests event,
    Emitter<DocumentTranslationState> emit,
  ) async {
    // Don't emit loading if we already have a success state to preserve
    if (state is! DocumentTranslationLoadSuccess) {
      emit(DocumentTranslationLoading());
    }
    try {
      final requests = await translationService.getUserRequests();
      // Preserve existing languages if we have them
      if (state is DocumentTranslationLoadSuccess) {
        final currentState = state as DocumentTranslationLoadSuccess;
        emit(
          DocumentTranslationLoadSuccess(
            languages: currentState.languages,
            requests: requests,
          ),
        );
      } else {
        emit(DocumentTranslationLoadSuccess(requests: requests));
      }
    } catch (e) {
      emit(DocumentTranslationOperationFailure(e.toString()));
    }
  }

  Future<void> _onSubmitRequest(
    SubmitRequest event,
    Emitter<DocumentTranslationState> emit,
  ) async {
    emit(DocumentTranslationLoading());
    try {
      await translationService.createRequest(
        fromLanguage: event.fromLanguage,
        toLanguage: event.toLanguage,
        specialization: event.specialization,
        text: event.text,
        title: event.title,
        comment: event.comment,
        translationMethod: event.translationMethod,
        fileUrl: event.fileUrl,
        fileType: event.fileType,
        fileName: event.fileName,
      );
      emit(DocumentTranslationOperationSuccess());
    } catch (e) {
      emit(DocumentTranslationOperationFailure(e.toString()));
    }
  }

  Future<void> _onDeleteRequest(
    DeleteRequest event,
    Emitter<DocumentTranslationState> emit,
  ) async {
    emit(DocumentTranslationLoading());
    try {
      await translationService.deleteRequest(event.requestId);
      emit(DocumentTranslationOperationSuccess());
    } catch (e) {
      emit(DocumentTranslationOperationFailure(e.toString()));
    }
  }
}
