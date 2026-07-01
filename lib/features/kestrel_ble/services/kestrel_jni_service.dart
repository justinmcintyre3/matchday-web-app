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

  final StreamController<bool> _privacyAuthAckController = StreamController.broadcast();
  Stream<bool> get onPrivacyAuthAck => _privacyAuthAckController.stream;

  final StreamController<bool> _authRequestAckController = StreamController.broadcast();
  Stream<bool> get onAuthRequestAck => _authRequestAckController.stream;

  // Streams for Sync Handshake
  final StreamController<bool> _tgtInfoSettingsController = StreamController.broadcast();
  Stream<bool> get onTgtInfoSettingsReceived => _tgtInfoSettingsController.stream;

  final StreamController<bool> _gunTransferSettingsController = StreamController.broadcast();
  Stream<bool> get onGunTransferSettingsReceived => _gunTransferSettingsController.stream;

  final StreamController<void> _balInfoSettingsController = StreamController.broadcast();
  Stream<void> get onBalInfoSettingsReceived => _balInfoSettingsController.stream;

  Stream<Map<String, dynamic>> get onBalFullSolution => _onBalFullSolutionController.stream;
  final _onBalFullSolutionController = StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<bool> _calcFullSolnAckController = StreamController.broadcast();
  Stream<bool> get onCalcFullSolnAck => _calcFullSolnAckController.stream;

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
        final isAuth = call.arguments as bool;
        debugPrint('[KestrelJni] updateAuthComplete: $isAuth');
        _authCompleteController.add(isAuth);
        break;
      case 'rcvPrivacyAuthAck':
        final isAuth = call.arguments as bool;
        debugPrint('[KestrelJni] rcvPrivacyAuthAck: $isAuth');
        _privacyAuthAckController.add(isAuth);
        break;
      case 'rcvAuthRequestAck':
        final isAuth = call.arguments as bool;
        debugPrint('[KestrelJni] rcvAuthRequestAck: $isAuth');
        _authRequestAckController.add(isAuth);
        break;
      case 'onTgtInfoSettingsReceived':
        _tgtInfoSettingsController.add(call.arguments as bool);
        break;
      case 'onGunTransferSettingsReceived':
        _gunTransferSettingsController.add(call.arguments as bool);
        break;
      case 'onBalInfoSettingsReceived':
        _balInfoSettingsController.add(null);
        break;
      case 'onBalFullSolution':
        final map = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('[KestrelJni] onBalFullSolution target=${map['targetNumber']}');
        _onBalFullSolutionController.add(map);
        break;
      case 'onCalcFullSolnAck':
        _calcFullSolnAckController.add(call.arguments as bool);
        break;
      case 'onSetRemoteSolnAck':
        debugPrint('[KestrelJni] onSetRemoteSolnAck: ${call.arguments}');
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

  /// Sends command to stop encryption (part of init sequence)
  Future<void> sendCmdStopEncrypting() async {
    await _channel.invokeMethod('sendCmdStopEncrypting');
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
  Future<void> sendCmdPrivacyAuthenticate(String pin, String hostId) async {
    await _channel.invokeMethod('sendCmdPrivacyAuthenticate', {
      'periphPin': pin,
      'hostPin': hostId,
    });
  }

  Future<String> getHostId() async {
    final String? hostId = await _channel.invokeMethod<String>('getHostId');
    return hostId ?? "1234";
  }

  /// Sends a BallisticsEnvironment update to override the latitude
  Future<void> sendSetEnvironment(double latitude) async {
    await _channel.invokeMethod('sendSetEnvironment', {'latitude': latitude});
  }

  /// Phase 1: push target slot data to the Kestrel (cmd 137 / setBalFullInputs).
  Future<void> sendCmdSetBalFullInputs({
    required int targetNumber,
    required double targetRangeYards,
    required double directionOfFire,
    required double windSpeed1Mph,
    required double windSpeed2Mph,
    required double windDirection,
    double inclinationAngle = 0,
    double targetSpeedMph = 0,
  }) async {
    await _channel.invokeMethod('sendCmdSetBalFullInputs', {
      'targetNumber': targetNumber,
      'targetRangeYards': targetRangeYards,
      'directionOfFire': directionOfFire,
      'windSpeed1Mph': windSpeed1Mph,
      'windSpeed2Mph': windSpeed2Mph,
      'windDirection': windDirection,
      'inclinationAngle': inclinationAngle,
      'targetSpeedMph': targetSpeedMph,
    });
  }

  /// Phase 2: trigger ballistics calc for a target slot already written to the Kestrel.
  Future<void> sendCalcFullSolution({required int targetNumber}) async {
    await _channel.invokeMethod('sendCalcFullSolution', {
      'targetNumber': targetNumber,
    });
  }

  // Initialization Handshake Commands
  Future<void> sendCmdGetTgtInfoSettings() async {
    await _channel.invokeMethod('sendCmdGetTgtInfoSettings');
  }

  Future<void> sendCmdGetGunTransferSettings() async {
    await _channel.invokeMethod('sendCmdGetGunTransferSettings');
  }

  Future<void> sendCmdGetBalInfoSettings() async {
    await _channel.invokeMethod('sendCmdGetBalInfoSettings');
  }

  void dispose() {
    _txBytesController.close();
    _privacyStatusController.close();
    _authCompleteController.close();
    _privacyAuthAckController.close();
    _authRequestAckController.close();
    _tgtInfoSettingsController.close();
    _gunTransferSettingsController.close();
    _balInfoSettingsController.close();
    _onBalFullSolutionController.close();
    _calcFullSolnAckController.close();
  }
}
