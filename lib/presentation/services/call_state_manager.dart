import 'dart:async';

/// Global call state manager to track active calls across the app
class CallStateManager {
  static final CallStateManager _instance = CallStateManager._internal();
  factory CallStateManager() => _instance;
  CallStateManager._internal();

  final StreamController<String?> _activeCallController =
      StreamController<String?>.broadcast();

  /// Stream that emits the active channel ID when a call is active, null when no call
  Stream<String?> get activeCallStream => _activeCallController.stream;

  String? _activeChannelId;

  /// Get the currently active channel ID
  String? get activeChannelId => _activeChannelId;

  /// Check if there's an active call
  bool get isCallActive => _activeChannelId != null;

  /// Start tracking a call
  void startCall(String channelId) {
    _activeChannelId = channelId;
    _activeCallController.add(channelId);
  }

  /// Stop tracking a call
  void endCall() {
    _activeChannelId = null;
    _activeCallController.add(null);
  }

  /// Dispose resources
  void dispose() {
    _activeCallController.close();
  }
}
