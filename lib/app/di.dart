import 'package:get_it/get_it.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_bloc.dart';
import 'package:interbridge/data/services/supabase_service.dart';

final instance = GetIt.instance;
Future<void> initAppModule() async {
  final sharedPrefs = await SharedPreferences.getInstance();
  instance.registerLazySingleton<SharedPreferences>(() => sharedPrefs);
  instance.registerLazySingleton<AppPreferences>(
    () => AppPreferences(instance()),
  );
  // Register SupabaseService
  instance.registerLazySingleton<SupabaseService>(() => SupabaseService());
  // Register all Blocs
  instance.registerFactory<LoginBloc>(() => LoginBloc());
  instance.registerFactory<RegisterBloc>(() => RegisterBloc());
  instance.registerFactory<SelectFieldBloc>(() => SelectFieldBloc());
  instance.registerFactory<LanguageFluencyBloc>(() => LanguageFluencyBloc());
  instance.registerFactory<SelectLanguageBloc>(() => SelectLanguageBloc());
}
