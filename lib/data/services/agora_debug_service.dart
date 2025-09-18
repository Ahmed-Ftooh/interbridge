import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:interbridge/config.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraDebugService {
  static RtcEngine? _engine;

  /// Test Agora initialization
  static Future<bool> testInitialization() async {
    try {
      log('Testing Agora initialization...');
      log('App ID: $agoraAppId');

      if (agoraAppId.isEmpty) {
        log('ERROR: Agora App ID is empty!');
        return false;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

      log('✅ Agora RTC Engine initialized successfully');

      // Test basic audio functionality
      await _engine!.enableAudio();
      log('✅ Audio enabled successfully');

      return true;
    } catch (e) {
      log('❌ Agora initialization failed: $e');
      return false;
    }
  }

  /// Test audio permissions
  static Future<bool> testAudioPermissions() async {
    try {
      log('Testing audio permissions...');

      // Test microphone permission
      final micPermission = await Permission.microphone.status;
      log('Microphone permission: ${micPermission.name}');

      // Test audio settings permission
      final audioSettingsPermission = await Permission.microphone.status;
      log('Audio settings permission: ${audioSettingsPermission.name}');

      return micPermission.isGranted && audioSettingsPermission.isGranted;
    } catch (e) {
      log('❌ Error testing audio permissions: $e');
      return false;
    }
  }

  /// Test channel joining (without actual join)
  static Future<bool> testChannelSetup() async {
    try {
      log('Testing channel setup...');

      if (_engine == null) {
        log('❌ Engine not initialized');
        return false;
      }

      // Test event handler registration
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            log('✅ Join channel success callback registered');
          },
          onError: (err, msg) {
            log('❌ Agora error: $err - $msg');
          },
        ),
      );

      log('✅ Event handlers registered successfully');
      return true;
    } catch (e) {
      log('❌ Error testing channel setup: $e');
      return false;
    }
  }

  /// Run all tests
  static Future<Map<String, bool>> runAllTests() async {
    log('🚀 Starting Agora diagnostic tests...');

    final results = <String, bool>{};

    // Test 1: Permissions
    results['permissions'] = await testAudioPermissions();

    // Test 2: Initialization
    results['initialization'] = await testInitialization();

    // Test 3: Channel setup
    results['channel_setup'] = await testChannelSetup();

    // Summary
    log('📊 Test Results:');
    results.forEach((test, result) {
      log('${result ? '✅' : '❌'} $test');
    });

    final allPassed = results.values.every((result) => result);
    log(allPassed ? '🎉 All tests passed!' : '⚠️ Some tests failed');

    return results;
  }

  /// Clean up
  static Future<void> cleanup() async {
    try {
      await _engine?.release();
      _engine = null;
      log('🧹 Agora engine cleaned up');
    } catch (e) {
      log('❌ Error during cleanup: $e');
    }
  }
}
