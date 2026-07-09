// State management for Kestrel BLE connectivity.
//
// This [ChangeNotifier] sits between [KestrelBleService] (BLE layer) and
// the UI (scan screen, detail screen, settings screen).
//
// UI calls:   startScan()  connect()  disconnect()
// UI watches: scannedDevices, connectedDevice, connectionState, isScanning

import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/kestrel_device.dart';
import '../services/kestrel_ble_service.dart';
import '../../ble_coordinator/ble_coordinator.dart';

class KestrelProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _savedDeviceKey = 'saved_kestrel_device';
  static const _batteryWarningThresholdKey = 'kestrel_battery_warning_threshold';
  static const _keepConnectedDuringSleepKey = 'kestrel_keep_connected_during_sleep';
  final KestrelBleService _service;

  bool _hasCheckedLatitudeThisSession = false;
  bool _hasWarnedBatteryThisSession = false;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  bool _keepConnectedDuringSleep = false;

  final StreamController<double> _latitudeMismatchController = StreamController.broadcast();
  Stream<double> get onLatitudeMismatch => _latitudeMismatchController.stream;

  final StreamController<int> _batteryLowController = StreamController.broadcast();
  Stream<int> get onBatteryLow => _batteryLowController.stream;

  int batteryWarningThreshold = 25;

  KestrelProvider({KestrelBleService? service})
      : _service = service ?? KestrelBleService() {
    _service.onScanResult = _onScanResult;
    _service.onConnectionStateChanged = _onConnectionStateChanged;
    _service.onRxData = _onRxData;
    _service.onBatteryLevelReceived = _onBatteryLevelReceived;
    WidgetsBinding.instance.addObserver(this);
    
    _service.onEnvironmentReceived.listen((env) {
      final kestrelLat = env['latitude'] as double?;
      debugPrint('[KestrelProvider] onEnvironmentReceived stream got latitude: $kestrelLat, checkedThisSession: $_hasCheckedLatitudeThisSession');
      if (kestrelLat != null && !_hasCheckedLatitudeThisSession) {
        _hasCheckedLatitudeThisSession = true;
        _checkLatitudeMismatch(kestrelLat);
      }
    });
    
    _service.onDeviceNameReceived.listen((name) {
      debugPrint('[KestrelProvider] onDeviceNameReceived: $name');
      if (name != null && name.trim().isNotEmpty && connectedDevice != null) {
        connectedDevice = connectedDevice!.copyWith(modelName: name.trim());
        _saveDevice();
        notifyListeners();
      }
    });

    _service.onDeviceSNReceived.listen((sn) {
      debugPrint('[KestrelProvider] onDeviceSNReceived: $sn');
      if (sn != null && sn.trim().isNotEmpty && connectedDevice != null) {
        connectedDevice = connectedDevice!.copyWith(serialNumber: sn.trim());
        _saveDevice();
        notifyListeners();
      }
    });

    _initPrefs();
  }

  Future<void> _checkLatitudeMismatch(double kestrelLat) async {
    final prefs = await SharedPreferences.getInstance();
    final silenced = prefs.getBool('silence_kestrel_latitude_mismatch') ?? false;
    debugPrint('[KestrelProvider] Mismatch check started. silenced: $silenced');
    if (silenced) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[KestrelProvider] Location services enabled: $serviceEnabled');
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[KestrelProvider] Location permission: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[KestrelProvider] Location permission after request: $permission');
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
    final phoneLat = position.latitude;
    final diff = (kestrelLat - phoneLat).abs();
    debugPrint('[KestrelProvider] Kestrel Lat: $kestrelLat, Phone Lat: $phoneLat, Diff: $diff');

    if (diff > 0.1) {
      debugPrint('[KestrelProvider] Significant mismatch detected! Emitting onLatitudeMismatch.');
      // Mismatch is significant
      _latitudeMismatchController.add(kestrelLat);
    }
  }

  Future<void> silenceLatitudeMismatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('silence_kestrel_latitude_mismatch', true);
  }

  bool get keepConnectedDuringSleep => _keepConnectedDuringSleep;

  Future<void> setKeepConnectedDuringSleep(bool value) async {
    _keepConnectedDuringSleep = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepConnectedDuringSleepKey, value);
    notifyListeners();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    batteryWarningThreshold = prefs.getInt(_batteryWarningThresholdKey) ?? 25;
    _keepConnectedDuringSleep = prefs.getBool(_keepConnectedDuringSleepKey) ?? false;
    final savedJson = prefs.getString(_savedDeviceKey);
    if (savedJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        connectedDevice = KestrelDevice.fromJson(data);
        notifyListeners();

        // Auto-connect to the saved device leveraging the OS Bluetooth stack
        connect(connectedDevice!, autoConnect: true);
      } catch (e) {
        debugPrint('[KestrelProvider] Error loading saved device: $e');
      }
    }
  }

  Future<void> _saveDevice() async {
    if (connectedDevice != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedDeviceKey, jsonEncode(connectedDevice!.toJson()));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Auto-reconnect
  // ──────────────────────────────────────────────────────────────────────────
  /// Devices discovered during the current scan session.
  final List<KestrelDevice> scannedDevices = [];

  /// The device we are connecting to or have connected.
  KestrelDevice? connectedDevice;

  KestrelConnectionState get connectionState =>
      connectedDevice?.state ?? KestrelConnectionState.disconnected;

  bool get isScanning => connectionState == KestrelConnectionState.scanning;

  bool get isConnected => connectionState == KestrelConnectionState.connected;

  String? get errorMessage => connectedDevice?.errorMessage;

  // ──────────────────────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────────────────────

  /// Start a filtered BLE scan. Results arrive via [onScanResult].
  Future<void> startScan() async {
    scannedDevices.clear();
    connectedDevice = null;
    _updateState(KestrelConnectionState.scanning);
    await _service.startScan();
  }

  /// Stop scan without connecting.
  Future<void> stopScan() async {
    await _service.stopScan();
    if (connectionState == KestrelConnectionState.scanning) {
      _updateState(KestrelConnectionState.disconnected);
    }
  }

  /// Connect to a [device] from the scan list.
  Future<void> connect(KestrelDevice device, {bool autoConnect = false}) async {
    BleCoordinator.instance.reset();
    if (!autoConnect) {
      connectedDevice = device.copyWith(state: KestrelConnectionState.connecting);
      notifyListeners();
    }
    await _service.connect(device, autoConnect: autoConnect);
  }

  /// Disconnect from the current device but keep it saved.
  Future<void> disconnect() async {
    await _service.disconnect();
    if (connectedDevice != null) {
      connectedDevice = connectedDevice!.copyWith(
        state: KestrelConnectionState.disconnected,
      );
    }
    notifyListeners();
  }

  /// Disconnect and completely forget the device.
  Future<void> forgetDevice() async {
    await _service.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedDeviceKey);
    connectedDevice = null;
    notifyListeners();
  }

  /// Attempt authentication with the provided PIN.
  Future<void> authenticateWithPin(String pin, {bool savePin = false}) async {
    // Always keep the PIN in memory for session-level auto-reconnects.
    connectedDevice = connectedDevice?.copyWith(pin: pin);
    
    if (savePin) {
      _saveDevice();
    }
    
    await _service.authenticateWithPin(pin);
  }

  /// Override the Kestrel's latitude with the given value.
  Future<void> updateKestrelLatitude(double latitude) async {
    if (connectionState != KestrelConnectionState.connected) return;
    await _service.updateLatitude(latitude);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('silence_kestrel_latitude_mismatch', false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Service callbacks (private)
  // ──────────────────────────────────────────────────────────────────────────

  void _onScanResult(KestrelDevice device) {
    // Avoid duplicates (address uniqueness)
    if (!scannedDevices.any((d) => d.address == device.address)) {
      scannedDevices.add(device);
      notifyListeners();
    }
  }

  void _onConnectionStateChanged(KestrelConnectionState state) {
    connectedDevice = connectedDevice?.copyWith(state: state) ??
        KestrelDevice(
          name: 'Kestrel',
          address: '',
          deviceType: 'Unknown',
          state: state,
        );

    // Save device on successful connection/auth
    if (state == KestrelConnectionState.connected) {
      _reconnectAttempts = 0;
      _saveDevice();
      debugPrint('[KestrelProvider] Connected! Requesting device name & serial number...');
      _service.getDeviceName();
      _service.getDeviceSerialNum();
      if (!_hasCheckedLatitudeThisSession) {
        debugPrint('[KestrelProvider] Requesting environment...');
        _service.getEnvironment();
      }
      // Signal coordinator — Kestrel handshake done, release queued devices
      BleCoordinator.instance.signal();
    } 
    // Auto-authenticate if we already have the PIN saved
    else if (state == KestrelConnectionState.pinRequired) {
      if (connectedDevice?.pin != null) {
        debugPrint('[KestrelProvider] Auto-authenticating with saved PIN...');
        connectedDevice = connectedDevice!.copyWith(state: KestrelConnectionState.connecting);
        notifyListeners();
        authenticateWithPin(connectedDevice!.pin!, savePin: true);
        return;
      }
    }
    // Device dropped — issue an autoConnect request to let the OS handle reconnection
    else if (state == KestrelConnectionState.disconnected && connectedDevice != null) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == AppLifecycleState.resumed) {
        debugPrint('[KestrelProvider] Natural disconnect. Issuing autoConnect request.');
        connect(connectedDevice!, autoConnect: true);
      }
    }
    // Connection error — signal coordinator so Rx5000 isn't blocked forever,
    // then schedule an auto-reconnect retry with exponential backoff if previously paired
    else if (state == KestrelConnectionState.error && connectedDevice != null) {
      BleCoordinator.instance.signal(); // Don't block Rx5000 on a Kestrel error
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == AppLifecycleState.resumed && connectedDevice?.serialNumber != null) {
        final backoffSeconds = (1 << _reconnectAttempts).clamp(1, 16);
        _reconnectAttempts++;
        debugPrint('[KestrelProvider] Connection error on previously paired device. '
            'Scheduling auto-reconnect retry in $backoffSeconds seconds (attempt $_reconnectAttempts)...');
        Future.delayed(Duration(seconds: backoffSeconds), () {
          if (connectionState == KestrelConnectionState.error && connectedDevice != null && !_disposed) {
            connect(connectedDevice!, autoConnect: true);
          }
        });
      }
    }

    notifyListeners();
  }

  void _onRxData(List<int> bytes) {
    // Phase 1: log only. Phase 2 will parse these bytes.
    debugPrint('[KestrelProvider] RX data (${bytes.length} bytes): '
        '${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _updateState(KestrelConnectionState state) {
    connectedDevice = connectedDevice?.copyWith(state: state);
    notifyListeners();
  }

  /// Stream of ballistics full solution results from the Kestrel.
  Stream<Map<String, dynamic>> get onBalFullSolution => _service.onBalFullSolution;

  Stream<bool> get onCalcFullSolnAck => _service.onCalcFullSolnAck;

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
    await _service.sendCmdSetBalFullInputs(
      targetNumber: targetNumber,
      targetRangeYards: targetRangeYards,
      directionOfFire: directionOfFire,
      windSpeed1Mph: windSpeed1Mph,
      windSpeed2Mph: windSpeed2Mph,
      windDirection: windDirection,
      inclinationAngle: inclinationAngle,
      targetSpeedMph: targetSpeedMph,
    );
  }

  Future<void> sendCalcFullSolution({required int targetNumber}) async {
    await _service.sendCalcFullSolution(targetNumber: targetNumber);
  }

  Future<void> _onBatteryLevelReceived(int batteryLevel) async {
    if (connectedDevice == null) return;
    connectedDevice = connectedDevice!.copyWith(batteryLevel: batteryLevel);
    _saveDevice();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    
    if (batteryLevel < batteryWarningThreshold) {
      if (!_hasWarnedBatteryThisSession) {
        _hasWarnedBatteryThisSession = true;
        final silenced = prefs.getBool('silence_kestrel_battery_low') ?? false;
        debugPrint('[KestrelProvider] Battery is low: $batteryLevel%. silenced: $silenced');
        if (!silenced) {
          _batteryLowController.add(batteryLevel);
        }
      }
    } else {
      // Clear ignore if battery is >= threshold
      debugPrint('[KestrelProvider] Battery is healthy: $batteryLevel%. Clearing silence flag.');
      await prefs.setBool('silence_kestrel_battery_low', false);
    }
  }

  Future<void> silenceBatteryLowWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('silence_kestrel_battery_low', true);
  }

  Future<void> setBatteryWarningThreshold(int value) async {
    batteryWarningThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_batteryWarningThresholdKey, value);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[KestrelProvider] App lifecycle state changed: $state');
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Cancel any queued coordinator callbacks — no point connecting while sleeping
      BleCoordinator.instance.cancelQueue();
      if (!_keepConnectedDuringSleep &&
          connectionState != KestrelConnectionState.disconnected) {
        debugPrint('[KestrelProvider] App going to sleep. Disconnecting Kestrel '
            '(current state: $connectionState)...');
        disconnect();
      } else if (_keepConnectedDuringSleep) {
        debugPrint('[KestrelProvider] App going to sleep. Keeping Kestrel connected '
            '(keep-alive enabled).');
      }
    } else if (state == AppLifecycleState.resumed) {
      if (connectedDevice != null &&
          connectionState == KestrelConnectionState.disconnected) {
        debugPrint('[KestrelProvider] App resumed. Reconnecting to Kestrel...');
        connect(connectedDevice!, autoConnect: true);
      } else if (_keepConnectedDuringSleep && isConnected) {
        // Already connected — signal coordinator immediately so Rx5000 can proceed
        debugPrint('[KestrelProvider] App resumed. Kestrel still connected (keep-alive). Signalling coordinator.');
        BleCoordinator.instance.signal();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    _latitudeMismatchController.close();
    _batteryLowController.close();
    super.dispose();
  }
}
