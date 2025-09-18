import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer';

class PermissionService {
  /// Request all essential app permissions (notifications + microphone)
  static Future<Map<String, bool>> requestAllAppPermissions() async {
    try {
      final results = <String, bool>{};

      // Request notification permission
      final notificationSettings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      results['notifications'] =
          notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized;

      // Request microphone permission
      final microphoneStatus = await Permission.microphone.request();
      results['microphone'] = microphoneStatus.isGranted;

      // Request additional voice call permissions
      final bluetoothStatus = await Permission.bluetooth.request();
      final bluetoothConnectStatus =
          await Permission.bluetoothConnect.request();
      results['bluetooth'] = bluetoothStatus.isGranted;
      results['bluetoothConnect'] = bluetoothConnectStatus.isGranted;

      return results;
    } catch (e) {
      log('Error requesting all app permissions: $e');
      return {
        'notifications': false,
        'microphone': false,
        'bluetooth': false,
        'bluetoothConnect': false,
      };
    }
  }

  /// Check if all essential permissions are granted
  static Future<Map<String, bool>> checkAllAppPermissions() async {
    try {
      final results = <String, bool>{};

      // Check notification permission
      final notificationSettings =
          await FirebaseMessaging.instance.getNotificationSettings();
      results['notifications'] =
          notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized;

      // Check microphone permission
      final microphoneStatus = await Permission.microphone.status;
      results['microphone'] = microphoneStatus.isGranted;

      // Check additional voice call permissions
      final bluetoothStatus = await Permission.bluetooth.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      results['bluetooth'] = bluetoothStatus.isGranted;
      results['bluetoothConnect'] = bluetoothConnectStatus.isGranted;

      return results;
    } catch (e) {
      log('Error checking all app permissions: $e');
      return {
        'notifications': false,
        'microphone': false,
        'bluetooth': false,
        'bluetoothConnect': false,
      };
    }
  }

  /// Request microphone permission for voice calls
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      log('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  static Future<bool> isMicrophonePermissionGranted() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      log('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request all necessary permissions for voice calls
  static Future<Map<Permission, PermissionStatus>>
  requestVoiceCallPermissions() async {
    try {
      final permissions =
          await [
            Permission.microphone,
            Permission.bluetooth,
            Permission.bluetoothConnect,
          ].request();

      return permissions;
    } catch (e) {
      log('Error requesting voice call permissions: $e');
      return {};
    }
  }

  /// Check if all voice call permissions are granted
  static Future<bool> areVoiceCallPermissionsGranted() async {
    try {
      final microphone = await Permission.microphone.status;
      final bluetooth = await Permission.bluetooth.status;
      final bluetoothConnect = await Permission.bluetoothConnect.status;

      return microphone.isGranted &&
          bluetooth.isGranted &&
          bluetoothConnect.isGranted;
    } catch (e) {
      log('Error checking voice call permissions: $e');
      return false;
    }
  }

  /// Open app settings if permissions are permanently denied
  static Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      log('Error opening app settings: $e');
      return false;
    }
  }
}
