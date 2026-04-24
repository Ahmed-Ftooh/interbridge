import 'package:flutter/foundation.dart';

const String kDeepLinkScheme = 'io.supabase.flutter';
const String kAuthCallbackHost = 'login-callback';

// Optional web portal base URLs (set via --dart-define):
// - WEB_INTERPRETER_PORTAL_BASE
// - WEB_ORGANIZATION_PORTAL_BASE
// - WEB_ADMIN_PORTAL_BASE
// - WEB_SHARED_PORTAL_BASE
const String _webInterpreterPortalBase = String.fromEnvironment(
  'WEB_INTERPRETER_PORTAL_BASE',
);
const String _webOrganizationPortalBase = String.fromEnvironment(
  'WEB_ORGANIZATION_PORTAL_BASE',
);
const String _webAdminPortalBase = String.fromEnvironment(
  'WEB_ADMIN_PORTAL_BASE',
);
const String _webSharedPortalBase = String.fromEnvironment(
  'WEB_SHARED_PORTAL_BASE',
);

String _trimTrailingSlash(String value) {
  if (value.endsWith('/')) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

String _callbackUrlFromBase(
  String base, {
  String callbackPath = '/login-callback',
}) {
  final normalized = _trimTrailingSlash(base);
  if (callbackPath.startsWith('/')) {
    return '$normalized$callbackPath';
  }
  return '$normalized/$callbackPath';
}

String _currentWebPortalHint() {
  final host = Uri.base.host.toLowerCase();
  final path = Uri.base.path.toLowerCase();

  if (host.startsWith('admin.') || path.startsWith('/admin')) {
    return 'admin';
  }
  if (host.startsWith('organization.') || path.startsWith('/organization')) {
    return 'organization';
  }
  if (host.startsWith('interpreter.') || path.startsWith('/interpreter')) {
    return 'interpreter';
  }

  return 'shared';
}

String getAuthCallbackUrl({String? portalHint}) {
  if (kIsWeb) {
    final hint = (portalHint ?? _currentWebPortalHint()).toLowerCase();
    final host = Uri.base.host.toLowerCase();
    final origin = Uri.base.origin;

    if (hint == 'admin') {
      if (_webAdminPortalBase.isNotEmpty) {
        return _callbackUrlFromBase(_webAdminPortalBase);
      }
      if (host.startsWith('admin.')) {
        return '$origin/login-callback';
      }
      return '$origin/admin/login-callback';
    }

    if (hint == 'organization') {
      if (_webOrganizationPortalBase.isNotEmpty) {
        return _callbackUrlFromBase(_webOrganizationPortalBase);
      }
      if (host.startsWith('organization.')) {
        return '$origin/login-callback';
      }
      return '$origin/organization/login-callback';
    }

    if (hint == 'interpreter') {
      if (_webInterpreterPortalBase.isNotEmpty) {
        return _callbackUrlFromBase(_webInterpreterPortalBase);
      }
      if (host.startsWith('interpreter.')) {
        return '$origin/login-callback';
      }
      return '$origin/interpreter/login-callback';
    }

    if (_webSharedPortalBase.isNotEmpty) {
      return _callbackUrlFromBase(_webSharedPortalBase);
    }

    return '$origin/login-callback';
  }

  return '$kDeepLinkScheme://$kAuthCallbackHost';
}
