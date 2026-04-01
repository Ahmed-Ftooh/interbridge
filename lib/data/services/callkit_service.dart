import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

/// Thin wrapper around [FlutterCallkitIncoming] to keep call-related logic in
/// one place and make it easier to stub in tests.
class CallKitService {
  CallKitService();

  final Uuid _uuid = const Uuid();

  Future<void> initialize() async {
    // FlutterCallkitIncoming doesn't require initialization
  }

  Future<void> showIncomingCall({
    required String callerName,
    required String callerId,
    String? callerAvatar,
    String? requestId,
    String? callType,
    String? interpreterType,
    String? medicalSection,
  }) async {
    final id = callerId.isNotEmpty ? callerId : _uuid.v4();
    await FlutterCallkitIncoming.showCallkitIncoming(
      CallKitParams(
        id: id,
        nameCaller: callerName,
        appName: 'Interbridge',
        avatar: callerAvatar,
        handle: callerId,
        type: callType == 'video' ? 1 : 0, // 0 = audio, 1 = video
        textAccept: 'Answer',
        textDecline: 'Decline',
        duration: 30000, // 30 seconds timeout
        extra: <String, dynamic>{
          'callerId': callerId,
          'request_id': requestId,
          'call_type': callType ?? 'voice',
          'interpreter_type': interpreterType ?? 'general',
          'medical_section': medicalSection,
        },
        android: const AndroidParams(
          isCustomNotification:
              false, // Use system incoming call UI for full screen
          isShowLogo: true,
          ringtonePath: 'system_ringtone_default', // Use system ringtone
          backgroundColor: '#0955fa',
          backgroundUrl: '',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          isShowFullLockedScreen: true,
          incomingCallNotificationChannelName: 'Incoming Calls',
          isShowCallID: false,
        ),
        ios: const IOSParams(
          iconName: 'CallKitIcon',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'call_ring',
        ),
      ),
    );
  }

  Future<void> endCall(String id) => FlutterCallkitIncoming.endCall(id);

  Future<void> endAllCalls() => FlutterCallkitIncoming.endAllCalls();
}
