import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/theme/theme_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectFieldBloc/select_field_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/languageFluencyBloc/language_fluency_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/selectLanguageBloc/select_language_bloc.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Global navigator key for notification navigation
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // named constructor

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
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
        BlocProvider<CallBloc>(create: (_) => instance<CallBloc>()),
        BlocProvider<ChatBloc>(create: (_) => instance<ChatBloc>()),
      ],
      child: MaterialApp(
        navigatorKey: MyApp.navigatorKey,
        debugShowCheckedModeBanner: false,
        onGenerateRoute: RouteGenerator.getRoute,
        
        // On web, preserve browser URL on refresh (step routes, auth callback).
        // For mobile, keep splash as the explicit entry route.
        initialRoute: kIsWeb ? null : Routes.splashRoute,
        theme: getApplicationTheme(),
      ),
    );
  }
}
