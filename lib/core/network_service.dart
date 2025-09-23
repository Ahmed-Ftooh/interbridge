import 'dart:async';
import 'dart:developer';
import 'dart:io';

/// Service to monitor network connectivity and provide network status
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  // Stream controller for connectivity changes
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  // Current connectivity status
  bool _isConnected = true; // Default to connected

  /// Stream that emits true when connected, false when disconnected
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Whether device is currently connected to internet
  bool get isConnected => _isConnected;

  /// Whether device is connected via WiFi (simplified)
  bool get isWifiConnected => _isConnected;

  /// Whether device is connected via mobile data (simplified)
  bool get isMobileConnected => _isConnected;

  /// Whether device is connected via ethernet (simplified)
  bool get isEthernetConnected => _isConnected;

  /// Whether device is connected via bluetooth (simplified)
  bool get isBluetoothConnected => false;

  /// Initialize network monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      _isConnected = await _checkConnectivity();
      log('Initial connectivity: $_isConnected');

      // Emit initial status
      _connectivityController.add(_isConnected);
    } catch (e) {
      log('Error initializing NetworkService: $e');
      // Default to disconnected state
      _isConnected = false;
      _connectivityController.add(false);
    }
  }

  /// Check network connectivity by attempting to reach a reliable server
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2)); // Reduced from 5 to 2 seconds
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      log('Connectivity check failed: $e');
      return false;
    }
  }

  /// Update connectivity status
  void updateConnectivity(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectivityController.add(connected);
      log('Connectivity updated: $connected');
    }
  }

  /// Check if device can reach the internet by pinging a reliable server
  Future<bool> hasInternetAccess() async {
    try {
      return await _checkConnectivity();
    } catch (e) {
      log('Error checking internet access: $e');
      return false;
    }
  }

  /// Get user-friendly connection type description
  String getConnectionTypeDescription() {
    if (!_isConnected) {
      return 'No internet connection';
    }
    return 'Connected to internet';
  }

  /// Get detailed connection information
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'connectionTypes': _isConnected ? ['internet'] : ['none'],
      'isWifi': _isConnected,
      'isMobile': _isConnected,
      'isEthernet': _isConnected,
      'isBluetooth': false,
      'description': getConnectionTypeDescription(),
    };
  }

  /// Dispose resources
  void dispose() {
    _connectivityController.close();
  }
}
