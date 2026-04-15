import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  // Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  // Check current status
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _hasConnection(result);
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false; // Assume offline on error for safety
    }
  }

  bool _hasConnection(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      return false;
    }
    // You could add more specific checks here (e.g., if mobile data is enough)
    return true;
  }
}


