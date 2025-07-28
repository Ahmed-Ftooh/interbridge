import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/theme/theme_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_bloc.dart';
import 'package:interbridge/app/di.dart';

class MyApp extends StatefulWidget {
  // named constructor
  const MyApp._internal();

  final int appState = 0;

  static final MyApp _instance =
      const MyApp._internal(); // singleton or single instance

  factory MyApp() => _instance; // factory

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  // final AppPreferences _appPreferences = instance<AppPreferences>();
  // @override
  // void didChangeDependencies() {
  //   _appPreferences.getLocale().then((locale) => context.setLocale(locale));
  //   super.didChangeDependencies();
  // }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LoginBloc>(create: (_) => instance<LoginBloc>()),
        BlocProvider<RegisterBloc>(create: (_) => instance<RegisterBloc>()),
        BlocProvider<SelectFieldBloc>(
          create: (_) => instance<SelectFieldBloc>(),
        ),
        BlocProvider<LanguageFluencyBloc>(
          create: (_) => instance<LanguageFluencyBloc>(),
        ),
        BlocProvider<SelectLanguageBloc>(
          create: (_) => instance<SelectLanguageBloc>(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateRoute: RouteGenerator.getRoute,
        initialRoute: Routes.splashRoute,
        theme: getApplicationTheme(),
      ),
    );
  }
}
