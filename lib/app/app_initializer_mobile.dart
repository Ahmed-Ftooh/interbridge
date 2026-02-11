import 'dart:developer';
import 'package:app_links/app_links.dart';

/// Mobile-specific deep link handling using app_links
void setupDeepLinkHandling(Future<void> Function(Uri uri) handleDeepLink) {
  final appLinks = AppLinks();

  // Handle deep link when app is already running (warm start)
  appLinks.uriLinkStream.listen((Uri uri) {
    log('Deep link received (warm): $uri');
    handleDeepLink(uri);
  });

  // Handle deep link when app is launched from deep link (cold start)
  appLinks.getInitialLink().then((Uri? uri) {
    if (uri != null) {
      log('Deep link received (cold): $uri');
      handleDeepLink(uri);
    }
  });
}
