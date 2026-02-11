import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import for platform detection
import 'platform_stub.dart' if (dart.library.io) 'dart:io' show Platform;

/// Platform detection utility
class PlatformService {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Check if current platform supports native push notifications
  static bool get supportsPushNotifications => isMobile;

  /// Check if current platform supports CallKit
  static bool get supportsCallKit => isMobile;

  /// Check if current platform supports native audio recording
  static bool get supportsNativeRecording => isMobile;

  /// Get the platform name for logging
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
