import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/app/app_initializer.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // On web: always call runApp() so Flutter renders its first frame and
    // the HTML loading screen is dismissed.  If initialization hangs or
    // fails (e.g. .env not reachable on the hosting), the user still sees
    // the login page instead of an infinite spinner.
    try {
      await AppInitializer.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Web: initialization timed out after 10 s');
        },
      );
    } catch (e) {
      debugPrint('Web: initialization error: $e');
      // Ensure DI is at least set up so BlocProviders can create instances.
      if (!GetIt.instance.isRegistered<AppPreferences>()) {
        try {
          await initAppModule();
        } catch (_) {}
      }
    }
  } else {
    await AppInitializer.initialize();
  }

  runApp(const MyApp());
}
