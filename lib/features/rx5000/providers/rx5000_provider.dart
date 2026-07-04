import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rx5000_device.dart';
import '../services/rx5000_ble_service.dart';

class Rx5000Provider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _savedDeviceKey = 'saved_rx5000_device';
  static const String _savedTokenKey = 'saved_rx5000_token';

  final Rx5000BleService _service;

  // State exposed to UI
  final List<Rx5000Device> scannedDevices = [];
  Rx5000Device? connectedDevice;

  int? _lastChallenge;
  String? pairingDeviceCode;
  int? _pairingPin;
  bool _headingModePersistent = false;
  int _activePageCount = 0;

  final StreamController<Map<String, dynamic>> _rangeStreamController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get onRangeData => _rangeStreamController.stream;

  Rx5000Provider({Rx5000BleService? service})
      : _service = service ?? Rx5000BleService() {
    _service.onScanResult = _onScanResult;
    _service.onConnectionStateChanged = _onConnectionStateChanged;
    _service.onRegisterReceived = _onRegisterReceived;
    _service.onRangeReceived = _onRangeReceived;
    _service.onTokenReceived = _onTokenReceived;
    WidgetsBinding.instance.addObserver(this);
    _initPrefs();
  }

  Rx5000ConnectionState get connectionState =>
      connectedDevice?.state ?? Rx5000ConnectionState.disconnected;

  bool get isScanning => connectionState == Rx5000ConnectionState.scanning;
  bool get isConnected => connectionState == Rx5000ConnectionState.connected;
  String? get errorMessage => connectedDevice?.errorMessage;

  // ── Init & Persistence ──────────────────────────────────────────────────────

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _headingModePersistent = prefs.getBool('rx5000_pin_mode_persistent') ?? false;
    final saved = prefs.getString(_savedDeviceKey);
    if (saved != null) {
      try {
        connectedDevice = Rx5000Device.fromJsonString(saved).copyWith(
          state: Rx5000ConnectionState.disconnected,
        );
        notifyListeners();
        if (_activePageCount > 0) {
          connect(connectedDevice!, autoConnect: true);
        }
      } catch (e) {
        debugPrint('[Rx5000Provider] Error loading saved device: $e');
      }
    }
  }

  Future<void> _saveDevice() async {
    if (connectedDevice != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedDeviceKey, connectedDevice!.toJsonString());
    }
  }

  // ── BLE Actions ─────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    scannedDevices.clear();
    connectedDevice = null;
    pairingDeviceCode = null;
    _lastChallenge = null;
    _pairingPin = null;
    
    _updateState(Rx5000ConnectionState.scanning);
    await _service.startScan();
  }

  Future<void> stopScan() async {
    await _service.stopScan();
    if (connectionState == Rx5000ConnectionState.scanning) {
      _updateState(Rx5000ConnectionState.disconnected);
    }
  }

  Future<void> connect(Rx5000Device device, {bool autoConnect = false}) async {
    try {
      if (!autoConnect) {
        connectedDevice = device.copyWith(state: Rx5000ConnectionState.connecting);
        notifyListeners();
      } else {
        connectedDevice = device.copyWith(state: Rx5000ConnectionState.disconnected);
        notifyListeners();
      }
      await _service.connect(device, autoConnect: autoConnect);
    } catch (e) {
      debugPrint('[Rx5000Provider] Connection failed: $e');
      connectedDevice = device.copyWith(
        state: Rx5000ConnectionState.error,
        errorMessage: "Connection failed. Please verify rangefinder is powered on and in range.",
      );
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _service.disconnect();
    } catch (e) {
      debugPrint('[Rx5000Provider] Error during disconnect: $e');
    }
  }

  Future<void> forgetDevice() async {
    try {
      await _service.disconnect();
    } catch (e) {
      debugPrint('[Rx5000Provider] Error during forget disconnect: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedDeviceKey);
    await prefs.remove(_savedTokenKey);
    connectedDevice = null;
    notifyListeners();
  }

  // ── Pairing & Security ──────────────────────────────────────────────────────

  Future<void> submitPin(int pin) async {
    if (_lastChallenge == null) {
      debugPrint('[Rx5000Provider] Cannot submit PIN: No active challenge.');
      return;
    }
    _pairingPin = pin;

    connectedDevice = connectedDevice?.copyWith(
      state: Rx5000ConnectionState.authenticating,
      errorMessage: null,
    );
    notifyListeners();
    
    try {
      final encryptedVal = SecurityUtil.encryptPin(pin, _lastChallenge!);
      debugPrint('[Rx5000Provider] Submitting PIN: $pin, Encrypted: $encryptedVal');
      
      // Write encrypted PIN to register 1000 (REQUEST_ACCESS_CODE)
      final response = await _service.writeAndAwaitNotification(1000, value: encryptedVal);
      if (response != "0") {
        debugPrint('[Rx5000Provider] PIN rejected by rangefinder (response: $response)');
        connectedDevice = connectedDevice?.copyWith(
          state: Rx5000ConnectionState.pinRequired,
          errorMessage: "Incorrect PIN. Please try again.",
        );
        notifyListeners();
      } else {
        debugPrint('[Rx5000Provider] PIN accepted. Awaiting encrypted token...');
      }
    } catch (e) {
      debugPrint('[Rx5000Provider] Error submitting PIN: $e');
      connectedDevice = connectedDevice?.copyWith(
        state: Rx5000ConnectionState.pinRequired,
        errorMessage: "Connection timeout during authentication.",
      );
      notifyListeners();
    }
  }

  void _onTokenReceived(String encryptedTokenGuid) async {
    if (_pairingPin == null) {
      debugPrint('[Rx5000Provider] Received token, but no pairing PIN is set.');
      return;
    }

    try {
      final decryptedToken = SecurityUtil.decryptToken(encryptedTokenGuid, _pairingPin!);
      debugPrint('[Rx5000Provider] Successfully decrypted token: $decryptedToken');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedTokenKey, decryptedToken);

      // Successfully authenticated! Complete connection
      connectedDevice = connectedDevice?.copyWith(
        state: Rx5000ConnectionState.connected,
        errorMessage: null,
      );
      await _saveDevice();
      notifyListeners();

      // Read initial device parameters
      _refreshProperties();
    } catch (e) {
      debugPrint('[Rx5000Provider] Error processing token: $e');
      connectedDevice = connectedDevice?.copyWith(
        errorMessage: "Failed to authenticate device.",
      );
      notifyListeners();
    }
  }

  // ── Settings updates ────────────────────────────────────────────────────────

  Future<void> setOutputMode(Rx5000OutputMode mode) async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1010, value: mode.index);
      connectedDevice = connectedDevice?.copyWith(outputMode: mode);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update Output Mode: $e');
    }
  }

  Future<void> setDisplayBrightness(Rx5000DisplayBrightness brightness) async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1004, value: brightness.index);
      connectedDevice = connectedDevice?.copyWith(displayBrightness: brightness);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update Brightness: $e');
    }
  }

  Future<void> setReticleType(Rx5000ReticleType reticle) async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1016, value: reticle.index);
      connectedDevice = connectedDevice?.copyWith(reticleType: reticle);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update Reticle Type: $e');
    }
  }

  Future<void> setMeasurementUnit(Rx5000MeasurementUnit unit) async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1011, value: unit.index);
      connectedDevice = connectedDevice?.copyWith(measurementUnit: unit);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update Measurement Unit: $e');
    }
  }

  Future<void> setLastTarget(bool enabled) async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1012, value: enabled ? 1 : 0);
      connectedDevice = connectedDevice?.copyWith(lastTarget: enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update Last Target: $e');
    }
  }

  Future<void> setInPinMode(bool enabled) async {
    if (!isConnected) return;
    _headingModePersistent = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rx5000_pin_mode_persistent', enabled);
    try {
      await _service.writeAndAwaitNotification(1001, value: enabled ? 1 : 0);
      connectedDevice = connectedDevice?.copyWith(inPinMode: enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update Pin Mode: $e');
    }
  }

  Future<void> setBleIdlePowerOffSeconds(int seconds) async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1017, value: seconds);
      connectedDevice = connectedDevice?.copyWith(bleIdlePowerOffSeconds: seconds);
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to update BLE Idle Poweroff Seconds: $e');
    }
  }

  void incrementActivePages() {
    _activePageCount++;
    debugPrint('[Rx5000Provider] Active page count incremented: $_activePageCount');
    if (_activePageCount == 1 && connectedDevice != null && !isConnected && connectionState != Rx5000ConnectionState.connecting) {
      connect(connectedDevice!);
    }
  }

  void decrementActivePages() {
    _activePageCount--;
    debugPrint('[Rx5000Provider] Active page count decremented: $_activePageCount');
    if (_activePageCount <= 0) {
      _activePageCount = 0;
      disconnect();
    }
  }

  Future<void> triggerTestFire() async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1027, value: 1);
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to trigger range test: $e');
    }
  }

  Future<void> startCompassCalibration() async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1029, value: 1);
      connectedDevice = connectedDevice?.copyWith(
        compassCalStatus: "Calibrating...",
        compassCalPercentage: 0,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to start compass calibration: $e');
    }
  }

  Future<void> abortCompassCalibration() async {
    if (!isConnected) return;
    try {
      await _service.writeAndAwaitNotification(1030, value: 1);
      connectedDevice = connectedDevice?.copyWith(
        compassCalStatus: "Aborted",
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Failed to abort compass calibration: $e');
    }
  }

  // ── Service Callbacks ───────────────────────────────────────────────────────

  void _onScanResult(Rx5000Device device, bool inPairingMode) {
    if (!scannedDevices.any((d) => d.address == device.address)) {
      scannedDevices.add(device);
      notifyListeners();
    }
  }

  void _onConnectionStateChanged(Rx5000ConnectionState state) async {
    if (state == Rx5000ConnectionState.connected) {
      connectedDevice = connectedDevice?.copyWith(state: Rx5000ConnectionState.authenticating);
      notifyListeners();
      _authenticateOrPair();
    } else {
      connectedDevice = connectedDevice?.copyWith(
        state: state,
        errorMessage: state == Rx5000ConnectionState.disconnected ? null : connectedDevice?.errorMessage,
      );
      if (state == Rx5000ConnectionState.disconnected) {
        pairingDeviceCode = null;
      }
      notifyListeners();

      if (state == Rx5000ConnectionState.disconnected && connectedDevice != null && _activePageCount > 0) {
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle == AppLifecycleState.resumed) {
          debugPrint('[Rx5000Provider] Natural disconnect. Issuing autoConnect request.');
          connect(connectedDevice!, autoConnect: true);
        }
      }
    }
  }

  Future<void> _authenticateOrPair() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_savedTokenKey);

    if (savedToken != null) {
      // 1. Stored Token exists - Reconnect/Authenticate automatically
      try {
        debugPrint('[Rx5000Provider] Token found. Requesting challenge code (Reg 1003)...');
        final challengeStr = await _service.readRegister(1003); // REQUEST_CHALLENGE
        final challenge = int.tryParse(challengeStr) ?? 0;
        
        final keyBytes = SecurityUtil.uuidToGuidBytes(savedToken);
        final encryptedChallenge = SecurityUtil.encryptTokenChallenge(challenge, keyBytes);
        
        debugPrint('[Rx5000Provider] Sending encrypted challenge code...');
        final authResponse = await _service.writeAndAwaitNotification(1003, value: encryptedChallenge);
        
        if (authResponse == "0") {
          debugPrint('[Rx5000Provider] Re-authentication successful!');
          connectedDevice = connectedDevice?.copyWith(
            state: Rx5000ConnectionState.connected,
            errorMessage: null,
          );
          _saveDevice();
          notifyListeners();
          
          _refreshProperties();
        } else {
          debugPrint('[Rx5000Provider] Re-authentication failed. Token might be stale. Requesting PIN pairing...');
          await prefs.remove(_savedTokenKey);
          _startNewPairing();
        }
      } catch (e) {
        debugPrint('[Rx5000Provider] Error during auto-reconnection: $e');
        connectedDevice = connectedDevice?.copyWith(
          state: Rx5000ConnectionState.error,
          errorMessage: "Failed auto-authentication.",
        );
        notifyListeners();
      }
    } else {
      // 2. No Token - Initiate New PIN Pairing
      _startNewPairing();
    }
  }

  Future<void> _startNewPairing() async {
    try {
      debugPrint('[Rx5000Provider] Requesting pairing challenge code (Reg 1000)...');
      final challengeStr = await _service.readRegister(1000); // REQUEST_ACCESS_CODE
      final challenge = int.tryParse(challengeStr) ?? 0;
      _lastChallenge = challenge;

      pairingDeviceCode = SecurityUtil.getAlphaCode(challenge);
      debugPrint('[Rx5000Provider] Pairing challenge received: $challenge. Generated Alpha Code: $pairingDeviceCode');

      connectedDevice = connectedDevice?.copyWith(
        state: Rx5000ConnectionState.pinRequired, // Transition to pinRequired UI state
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Error requesting pairing code: $e');
      connectedDevice = connectedDevice?.copyWith(
        state: Rx5000ConnectionState.error,
        errorMessage: "Pairing handshake failed.",
      );
      notifyListeners();
    }
  }

  // ── Sync Properties ─────────────────────────────────────────────────────────

  Future<void> _refreshProperties() async {
    try {
      final modeStr = await _service.readRegister(1010);
      final brightStr = await _service.readRegister(1004);
      final reticleStr = await _service.readRegister(1016);
      final unitStr = await _service.readRegister(1011);
      final batteryStr = await _service.readRegister(1005);
      final tempStr = await _service.readRegister(1006);
      final lastTargetStr = await _service.readRegister(1012);
      final pinModeStr = await _service.readRegister(1001);
      final calInProgressStr = await _service.readRegister(1033);
      final calPercentageStr = await _service.readRegister(1031);
      final calQualityStr = await _service.readRegister(1032);
      final bleIdleStr = await _service.readRegister(1017);

      final isPinMode = (int.tryParse(pinModeStr) ?? 0) == 1;
      
      if (_headingModePersistent && !isPinMode) {
        // Enforce persistent mode on hardware upon connection
        debugPrint('[Rx5000Provider] Enforcing persistent Pin Mode (Reg 1001 = 1)...');
        setInPinMode(true);
      } else {
        _headingModePersistent = isPinMode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rx5000_pin_mode_persistent', isPinMode);
      }

      connectedDevice = connectedDevice?.copyWith(
        outputMode: Rx5000OutputMode.values[int.tryParse(modeStr) ?? 0],
        displayBrightness: Rx5000DisplayBrightness.values[int.tryParse(brightStr) ?? 3],
        reticleType: Rx5000ReticleType.values[int.tryParse(reticleStr) ?? 0],
        measurementUnit: Rx5000MeasurementUnit.values[int.tryParse(unitStr) ?? 0],
        batteryLevel: int.tryParse(batteryStr) ?? 100,
        tempCelsius: _parseTemperature(int.tryParse(tempStr) ?? 0),
        lastTarget: (int.tryParse(lastTargetStr) ?? 0) == 1,
        inPinMode: _headingModePersistent,
        compassCalPercentage: int.tryParse(calPercentageStr) ?? 0,
        compassCalQuality: int.tryParse(calQualityStr) ?? 0,
        isCompassCalibrating: (int.tryParse(calInProgressStr) ?? 0) == 1,
        compassCalStatus: (int.tryParse(calInProgressStr) ?? 0) == 1
            ? "Calibrating..."
            : _getQualityLabel(int.tryParse(calQualityStr) ?? 0),
        bleIdlePowerOffSeconds: int.tryParse(bleIdleStr) ?? 30,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[Rx5000Provider] Error refreshing device settings: $e');
    }
  }

  double _parseTemperature(int rawVal) {
    final bd = ByteData(4)..setUint32(0, rawVal, Endian.little);
    return bd.getFloat32(0, Endian.little);
  }

  String _getQualityLabel(int level) {
    if (level <= 0) return 'Not Calibrated';
    const labels = ['None', 'Least', 'Poor', 'Low', 'OK', 'Good', 'Best'];
    if (level < labels.length) {
      return labels[level];
    }
    return 'Best';
  }

  Future<void> _readFinalQuality() async {
    try {
      final qStr = await _service.readRegister(1032);
      final qVal = int.tryParse(qStr) ?? 0;
      connectedDevice = connectedDevice?.copyWith(
        compassCalQuality: qVal,
        compassCalStatus: _getQualityLabel(qVal),
      );
      notifyListeners();
    } catch (_) {}
  }

  // ── Callback Handlers ───────────────────────────────────────────────────────

  void _onRegisterReceived(int register, int val) {
    if (connectedDevice == null) return;
    
    debugPrint('[Rx5000Provider] Register Notification: $register = $val');

    switch (register) {
      case 1006: // TEMPERATURE_DEG_C
        connectedDevice = connectedDevice!.copyWith(tempCelsius: _parseTemperature(val));
        break;
      case 1004: // DISPLAY_BRIGHTNESS
        if (val < Rx5000DisplayBrightness.values.length) {
          connectedDevice = connectedDevice!.copyWith(displayBrightness: Rx5000DisplayBrightness.values[val]);
        }
        break;
      case 1010: // OUTPUT_MODE
        if (val < Rx5000OutputMode.values.length) {
          connectedDevice = connectedDevice!.copyWith(outputMode: Rx5000OutputMode.values[val]);
        }
        break;
      case 1016: // RETICLE
        if (val < Rx5000ReticleType.values.length) {
          connectedDevice = connectedDevice!.copyWith(reticleType: Rx5000ReticleType.values[val]);
        }
        break;
      case 1011: // UNITS_YARD_METER
        if (val < Rx5000MeasurementUnit.values.length) {
          connectedDevice = connectedDevice!.copyWith(measurementUnit: Rx5000MeasurementUnit.values[val]);
        }
        break;
      case 1005: // BATTERY_LEVEL
        connectedDevice = connectedDevice!.copyWith(batteryLevel: val);
        break;
      case 1012: // LAST_TARGET
        connectedDevice = connectedDevice!.copyWith(lastTarget: val == 1);
        break;
      case 1001: // PIN_MODE
        if (val == 0 && _headingModePersistent) {
          // Re-enable Pin Mode automatically to keep it persistent
          _service.writeAndAwaitNotification(1001, value: 1).catchError((e) {
            debugPrint('[Rx5000Provider] Failed to auto-re-enable Pin Mode: $e');
            return '';
          });
        } else {
          connectedDevice = connectedDevice!.copyWith(inPinMode: val == 1);
        }
        break;
      case 1031: // COMPASS_CAL_COMPLETION_PERCENTAGE
        connectedDevice = connectedDevice!.copyWith(compassCalPercentage: val);
        break;
      case 1032: // COMPASS_CAL_QUALITY_INDICATOR
        connectedDevice = connectedDevice!.copyWith(
          compassCalQuality: val,
          compassCalStatus: connectedDevice!.isCompassCalibrating ? "Calibrating..." : _getQualityLabel(val),
        );
        break;
      case 1033: // COMPASS_CAL_IN_PROGRESS
        final isCalibrating = val == 1;
        connectedDevice = connectedDevice!.copyWith(
          isCompassCalibrating: isCalibrating,
          compassCalStatus: isCalibrating ? "Calibrating..." : _getQualityLabel(connectedDevice!.compassCalQuality),
        );
        if (!isCalibrating) {
          _readFinalQuality();
        }
        break;
      case 1019: // LASER_ACTIVE
        connectedDevice = connectedDevice!.copyWith(isLaserActive: val == 1);
        break;
      case 1017: // BLE_IDLE_POWEROFF_SECONDS
        connectedDevice = connectedDevice!.copyWith(bleIdlePowerOffSeconds: val);
        break;
    }
    notifyListeners();
  }

  void _onRangeReceived(Map<String, dynamic> data) {
    if (connectedDevice == null) return;

    debugPrint('[Rx5000Provider] Range Notification: $data');

    _rangeStreamController.add(data);

    final headingVal = data['heading'] as double?;

    connectedDevice = connectedDevice!.copyWith(
      inPinMode: _headingModePersistent,
      lastRange: data['range'] as double?,
      lastTbrDistance: data['distance'] as double?,
      lastVerticalDistance: data['verticalDistance'] as double?,
      lastInclination: data['inclination'] as int?,
      lastHeading: headingVal,
      clearHeading: headingVal == null,
      lastDistanceType: data['lastDistanceType'] as String?,
      lastWindage: data['windage'] as double?,
    );
    notifyListeners();

    if (_headingModePersistent) {
      // Re-enable Pin Mode automatically to keep it persistent for subsequent fires
      _service.writeAndAwaitNotification(1001, value: 1).catchError((e) {
        debugPrint('[Rx5000Provider] Failed to auto-re-enable Pin Mode after shot: $e');
        return '';
      });
    }
  }

  void _updateState(Rx5000ConnectionState state) {
    connectedDevice = connectedDevice?.copyWith(state: state);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[Rx5000Provider] App lifecycle state changed: $state');
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (isConnected) {
        disconnect();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_activePageCount > 0 && connectedDevice != null && !isConnected && connectionState != Rx5000ConnectionState.connecting) {
        connect(connectedDevice!, autoConnect: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rangeStreamController.close();
    _service.dispose();
    super.dispose();
  }
}
