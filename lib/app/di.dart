import 'dart:developer';

import 'package:get_it/get_it.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_bloc.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/services/notification_service.dart';
import 'package:interbridge/data/services/interpreter_job_service.dart';
import 'package:interbridge/data/services/firebase_messaging_service.dart';
import 'package:interbridge/data/services/document_translation_service.dart';
import 'package:interbridge/data/services/translation_cache_service.dart';
import 'package:interbridge/data/services/app_state_restoration_service.dart';
import 'package:interbridge/core/firebase_service.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';

final instance = GetIt.instance;
Future<void> initAppModule() async {
  try {
    final sharedPrefs = await SharedPreferences.getInstance();
    instance.registerLazySingleton<SharedPreferences>(() => sharedPrefs);

    instance.registerLazySingleton<AppPreferences>(
      () => AppPreferences(instance()),
    );

    // Register SupabaseService
    instance.registerLazySingleton<SupabaseService>(() => SupabaseService());

    // Register CallService
    instance.registerLazySingleton<CallService>(() => CallService());

    instance.registerLazySingleton<ChatService>(() => ChatService());
    // Register NotificationService
    instance.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );

    // Register InterpreterJobService
    instance.registerLazySingleton<InterpreterJobService>(
      () => InterpreterJobService(),
    );

    // Register DocumentTranslationService
    instance.registerLazySingleton<DocumentTranslationService>(
      () => DocumentTranslationService(),
    );

    // Register TranslationCacheService
    instance.registerLazySingleton<TranslationCacheService>(
      () => TranslationCacheService(),
    );

    // Register AppStateRestorationService
    instance.registerLazySingleton<AppStateRestorationService>(
      () => AppStateRestorationService(),
    );

    // Register Firebase services
    instance.registerLazySingleton<FirebaseService>(
      () => FirebaseService.instance,
    );
    instance.registerLazySingleton<FirebaseMessagingService>(
      () => FirebaseMessagingService(),
    );

    // Register all Blocs
    instance.registerFactory<LoginBloc>(() => LoginBloc());
    instance.registerFactory<RegisterBloc>(() => RegisterBloc());
    instance.registerLazySingleton<InterpreterJobBloc>(
      () => InterpreterJobBloc(),
    );
    instance.registerFactory<CallBloc>(() => CallBloc(service: CallService()));
    instance.registerFactory<ChatBloc>(() => ChatBloc(service: ChatService()));

    instance.registerFactory<SelectFieldBloc>(() => SelectFieldBloc());
    instance.registerFactory<LanguageFluencyBloc>(() => LanguageFluencyBloc());
    instance.registerFactory<SelectLanguageBloc>(() => SelectLanguageBloc());
  } catch (e) {
    log('Error in dependency injection: $e');
    rethrow;
  }
}
