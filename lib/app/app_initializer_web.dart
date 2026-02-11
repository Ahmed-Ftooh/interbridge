import 'dart:developer';
import 'dart:html' as html;

/// Web-specific deep link handling using browser URL
void setupDeepLinkHandling(Future<void> Function(Uri uri) handleDeepLink) {
  // On web, check the current URL for auth callbacks
  final currentUri = Uri.parse(html.window.location.href);

  // Check if this is an auth callback URL
  if (currentUri.fragment.isNotEmpty ||
      currentUri.queryParameters.containsKey('access_token') ||
      currentUri.queryParameters.containsKey('code') ||
      currentUri.toString().contains('login-callback')) {
    log('Web deep link detected: $currentUri');
    handleDeepLink(currentUri);
  }

  // Listen for URL changes (for SPA-style navigation)
  html.window.onPopState.listen((event) {
    final newUri = Uri.parse(html.window.location.href);
    log('Web URL changed: $newUri');
    if (newUri.fragment.isNotEmpty ||
        newUri.queryParameters.containsKey('access_token') ||
        newUri.queryParameters.containsKey('code')) {
      handleDeepLink(newUri);
    }
  });
}
