import 'dart:async';
import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/translation_draft_repository.dart';

class InterpreterDraftState {
  final String text;
  final String? fileUrl;
  final bool saving;
  final DateTime? lastSavedAt;
  final String? error;
  final bool loaded;

  const InterpreterDraftState({
    this.text = '',
    this.fileUrl,
    this.saving = false,
    this.lastSavedAt,
    this.error,
    this.loaded = false,
  });

  InterpreterDraftState copyWith({
    String? text,
    String? fileUrl,
    bool? saving,
    DateTime? lastSavedAt,
    String? error,
    bool? loaded,
  }) {
    return InterpreterDraftState(
      text: text ?? this.text,
      fileUrl: fileUrl ?? this.fileUrl,
      saving: saving ?? this.saving,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      error: error,
      loaded: loaded ?? this.loaded,
    );
  }
}

class InterpreterDraftCubit extends Cubit<InterpreterDraftState> {
  final TranslationDraftRepository _repo;
  final String requestId;
  final String interpreterId;
  Timer? _saveTimer;

  InterpreterDraftCubit({
    required TranslationDraftRepository repo,
    required this.requestId,
    required this.interpreterId,
  }) : _repo = repo,
       super(const InterpreterDraftState());

  Future<void> load() async {
    try {
      final draft = await _repo.getDraft(
        requestId: requestId,
        interpreterId: interpreterId,
      );
      if (draft != null) {
        emit(
          state.copyWith(
            text: draft.draftText ?? '',
            fileUrl: draft.draftFileUrl,
            lastSavedAt: draft.autosavedAt,
            loaded: true,
          ),
        );
      } else {
        emit(state.copyWith(loaded: true));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load draft', loaded: true));
    }
  }

  void queueAutosave({required String text, String? fileUrl}) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      await save(text: text, fileUrl: fileUrl);
    });
  }

  Future<void> save({required String text, String? fileUrl}) async {
    try {
      emit(state.copyWith(saving: true, error: null));
      await _repo.upsertDraft(
        requestId: requestId,
        interpreterId: interpreterId,
        draftText: text,
        draftFileUrl: fileUrl ?? state.fileUrl,
      );
      emit(
        state.copyWith(
          text: text,
          fileUrl: fileUrl ?? state.fileUrl,
          saving: false,
          lastSavedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      log('Draft save failed: $e');
      emit(state.copyWith(saving: false, error: 'Autosave failed'));
    }
  }

  Future<void> clear() async {
    try {
      await _repo.clearDraft(
        requestId: requestId,
        interpreterId: interpreterId,
      );
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _saveTimer?.cancel();
    return super.close();
  }
}
