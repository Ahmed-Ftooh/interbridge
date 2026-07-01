import 'dart:async';
import 'dart:developer';
import 'package:app_links/app_links.dart';

/// Subscription to the deep link stream. Stored so it can be cancelled
/// on re-initialization to prevent duplicate listeners.
StreamSubscription? _deepLinkSub;

/// Mobile-specific deep link handling using app_links
void setupDeepLinkHandling(Future<void> Function(Uri uri) handleDeepLink) {
  final appLinks = AppLinks();

  // Cancel any previous subscription (e.g. on hot restart)
  _deepLinkSub?.cancel();

  // Handle deep link when app is already running (warm start)
  _deepLinkSub = appLinks.uriLinkStream.listen((Uri uri) {
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
