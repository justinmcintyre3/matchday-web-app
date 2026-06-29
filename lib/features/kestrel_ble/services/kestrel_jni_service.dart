import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class KestrelJniService {
  static const MethodChannel _channel = MethodChannel('com.matchday/kestrel_jni');

  // Stream of raw TX bytes coming from JNI (to be sent over BLE to the Kestrel)
  final StreamController<List<int>> _txBytesController = StreamController.broadcast();
  Stream<List<int>> get onTxBytes => _txBytesController.stream;

  // Streams for Auth events
  final StreamController<bool> _privacyStatusController = StreamController.broadcast();
  Stream<bool> get onPrivacyStatus => _privacyStatusController.stream;

  final StreamController<bool> _authCompleteController = StreamController.broadcast();
  Stream<bool> get onAuthComplete => _authCompleteController.stream;

  KestrelJniService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTxBytes':
        final bytes = call.arguments as Uint8List;
        _txBytesController.add(bytes.toList());
        break;
      case 'rcvPrivacyStatus':
        final isPrivacyOn = call.arguments as bool;
        debugPrint('[KestrelJni] rcvPrivacyStatus: $isPrivacyOn');
        _privacyStatusController.add(isPrivacyOn);
        break;
      case 'updateAuthComplete':
      case 'rcvPrivacyAuthAck':
      case 'rcvAuthRequestAck':
        final isAuth = call.arguments as bool;
        debugPrint('[KestrelJni] ${call.method}: $isAuth');
        _authCompleteController.add(isAuth);
        break;
    }
  }

  Future<void> connectJni() async {
    debugPrint('[KestrelJni] Connecting to Native JNI layer...');
    await _channel.invokeMethod('connectJni');
  }

  Future<void> disconnectJni() async {
    await _channel.invokeMethod('disconnectJni');
  }

  /// Feed data received from BLE (RX) into the Native JNI layer
  Future<void> setRxBytes(List<int> bytes) async {
    await _channel.invokeMethod('setRxBytes', {'bytes': Uint8List.fromList(bytes)});
  }

  /// Asks Kestrel if it has a PIN enabled
  Future<void> sendCmdGetPrivacyStatus() async {
    await _channel.invokeMethod('sendCmdGetPrivacyStatus');
  }

  /// Sends auth request without a PIN
  Future<void> sendRequestAuth() async {
    await _channel.invokeMethod('sendRequestAuth');
  }

  /// Sends auth request with a PIN
  Future<void> sendCmdPrivacyAuthenticate(String periphPin, String hostPin) async {
    await _channel.invokeMethod('sendCmdPrivacyAuthenticate', {
      'periphPin': periphPin,
      'hostPin': hostPin,
    });
  }

  void dispose() {
    _txBytesController.close();
    _privacyStatusController.close();
    _authCompleteController.close();
  }
}
