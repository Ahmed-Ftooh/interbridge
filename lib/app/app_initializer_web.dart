import 'dart:async';
import 'dart:developer';
import 'dart:html' as html;

/// Subscription to the browser popstate event. Stored so it can be
/// cancelled on re-initialization to prevent duplicate listeners.
StreamSubscription? _popStateSub;

/// Web-specific deep link handling using browser URL
void setupDeepLinkHandling(Future<void> Function(Uri uri) handleDeepLink) {
  // On web, check the current URL for auth callbacks
  final currentUri = Uri.parse(html.window.location.href);

  bool isAuthCallback(Uri uri) {
    final query = uri.queryParameters;
    return uri.fragment.isNotEmpty ||
        query.containsKey('access_token') ||
        query.containsKey('refresh_token') ||
        query.containsKey('code') ||
        query.containsKey('token') ||
        query.containsKey('token_hash') ||
        query.containsKey('type') ||
        uri.toString().contains('login-callback');
  }

  // Check if this is an auth callback URL
  if (isAuthCallback(currentUri)) {
    log('Web deep link detected: $currentUri');
    handleDeepLink(currentUri);
  }

  // Cancel any previous subscription (e.g. on hot restart)
  _popStateSub?.cancel();

  // Listen for URL changes (for SPA-style navigation)
  _popStateSub = html.window.onPopState.listen((event) {
    final newUri = Uri.parse(html.window.location.href);
    log('Web URL changed: $newUri');
    if (isAuthCallback(newUri)) {
      handleDeepLink(newUri);
    }
  });
}
