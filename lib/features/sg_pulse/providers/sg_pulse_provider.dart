// State management for SG Pulse BLE connectivity.
//
// This [ChangeNotifier] sits between [SgPulseBleService] (BLE layer) and
// the UI (scan screen, detail screen, settings screen).
//
// UI calls:   startScan()  connect()  disconnect()  forgetDevice()
// UI watches: scannedDevices, connectedDevice, connectionState,
//             isScanning, latestSnapshot, shotCount

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math' as math;

import '../models/sg_pulse_device.dart';
import '../models/pulse_snapshot.dart';
import '../services/sg_pulse_ble_service.dart';

class SgPulseProvider extends ChangeNotifier {
  static const _savedDeviceKey = 'saved_sg_pulse_device';
  static const _rollThresholdKey = 'sg_pulse_roll_threshold';
  static const _greenZoneKey = 'sg_pulse_stability_green_zone';
  static const _yellowZoneKey = 'sg_pulse_stability_yellow_zone';
  static const _batteryWarningThresholdKey = 'sg_pulse_battery_warning_threshold';

  final SgPulseBleService _service;
  
  final _shotDetectedController = StreamController<void>.broadcast();
  Stream<void> get shotDetectedStream => _shotDetectedController.stream;

  bool _hasWarnedBatteryThisSession = false;
  final _batteryLowController = StreamController<int>.broadcast();
  Stream<int> get onBatteryLow => _batteryLowController.stream;
 
  SgPulseProvider({SgPulseBleService? service})
      : _service = service ?? SgPulseBleService() {
    _service.onScanResult            = _onScanResult;
    _service.onConnectionStateChanged = _onConnectionStateChanged;
    _service.onPulseData             = _onPulseData;
    _service.onShotDetected          = _onShotDetected;
    _service.onBatteryLevelReceived  = _onBatteryLevelReceived;
    _initPrefs();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Persistence
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    rollThreshold = prefs.getDouble(_rollThresholdKey) ?? 0.3;
    stabilityGreenZone = prefs.getDouble(_greenZoneKey) ?? 1.0;
    stabilityYellowZone = prefs.getDouble(_yellowZoneKey) ?? 5.0;
    batteryWarningThreshold = prefs.getInt(_batteryWarningThresholdKey) ?? 25;
    final saved = prefs.getString(_savedDeviceKey);
    if (saved != null) {
      try {
        connectedDevice = SgPulseDevice.fromJsonString(saved);
        notifyListeners();
        connect(connectedDevice!, autoConnect: true);
      } catch (e) {
        debugPrint('[SgPulseProvider] Error loading saved device: $e');
      }
    }
  }

  Future<void> _saveDevice() async {
    if (connectedDevice != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedDeviceKey, connectedDevice!.toJsonString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // State exposed to UI
  // ──────────────────────────────────────────────────────────────────────────

  /// Devices discovered during the current scan session.
  final List<SgPulseDevice> scannedDevices = [];

  /// The device we are connecting to or have connected.
  SgPulseDevice? connectedDevice;

  /// Latest IMU frame received from the device.
  PulseSnapshot? latestSnapshot;

  /// Running shot count for this session.
  int shotCount = 0;

  /// Firearm roll threshold (capping cant limit)
  double rollThreshold = 0.3;

  /// Firearm stability configurations
  double stabilityGreenZone = 1.0;
  double stabilityYellowZone = 5.0;

  /// Battery warning threshold percentage
  int batteryWarningThreshold = 25;

  /// Internal buffers for calculating stability metrics locally
  final List<double> _angleHistory = [];
  final List<double> _stabilityHistory = [];

  /// Temporary flag to trigger visual shot feedback in UI.
  bool isShotFlashing = false;

  SgPulseConnectionState get connectionState =>
      connectedDevice?.state ?? SgPulseConnectionState.disconnected;

  bool get isScanning  => connectionState == SgPulseConnectionState.scanning;
  bool get isConnected => connectionState == SgPulseConnectionState.connected;

  String? get errorMessage => connectedDevice?.errorMessage;

  // ──────────────────────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────────────────────

  /// Start a filtered BLE scan for SG Pulse devices.
  Future<void> startScan() async {
    scannedDevices.clear();
    connectedDevice = null;
    latestSnapshot = null;
    shotCount = 0;
    _updateState(SgPulseConnectionState.scanning);
    await _service.startScan();
  }

  /// Stop scan without connecting.
  Future<void> stopScan() async {
    await _service.stopScan();
    if (connectionState == SgPulseConnectionState.scanning) {
      _updateState(SgPulseConnectionState.disconnected);
    }
  }

  /// Connect to a [device] from the scan list.
  Future<void> connect(SgPulseDevice device, {bool autoConnect = false}) async {
    connectedDevice = device.copyWith(state: SgPulseConnectionState.connecting);
    notifyListeners();
    await _service.connect(device, autoConnect: autoConnect);
  }

  /// Disconnect from the current device but keep it saved.
  Future<void> disconnect() async {
    await _service.disconnect();
    if (connectedDevice != null) {
      connectedDevice = connectedDevice!.copyWith(
        state: SgPulseConnectionState.disconnected,
      );
    }
    notifyListeners();
  }

  /// Disconnect and completely forget the device (wipes SharedPreferences).
  Future<void> forgetDevice() async {
    await _service.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedDeviceKey);
    connectedDevice = null;
    latestSnapshot = null;
    shotCount = 0;
    _angleHistory.clear();
    _stabilityHistory.clear();
    notifyListeners();
  }

  /// Update firearm roll threshold limit
  Future<void> setRollThreshold(double value) async {
    rollThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rollThresholdKey, value);
    notifyListeners();
  }

  /// Update firearm stability green zone limit
  Future<void> setStabilityGreenZone(double value) async {
    stabilityGreenZone = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_greenZoneKey, value);
    notifyListeners();
  }

  /// Update firearm stability yellow zone limit
  Future<void> setStabilityYellowZone(double value) async {
    stabilityYellowZone = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_yellowZoneKey, value);
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Service callbacks (private)
  // ──────────────────────────────────────────────────────────────────────────

  void _onScanResult(SgPulseDevice device) {
    if (!scannedDevices.any((d) => d.address == device.address)) {
      scannedDevices.add(device);
      notifyListeners();
    }
  }

  void _onConnectionStateChanged(SgPulseConnectionState state) {
    connectedDevice = connectedDevice?.copyWith(state: state) ??
        SgPulseDevice(name: 'SG Pulse', address: '', state: state);

    if (state == SgPulseConnectionState.connected) {
      _saveDevice();
    } else if (state == SgPulseConnectionState.disconnected &&
        connectedDevice != null) {
      debugPrint('[SgPulseProvider] Natural disconnect. Issuing autoConnect request.');
      connect(connectedDevice!, autoConnect: true);
    }

    notifyListeners();
  }

  void _onPulseData(PulseSnapshot snapshot) {
    // 1. Decouple minor tremor/noise by quantizing the incoming pitch and roll to 0.1 degree steps (tenths).
    // This replicates the `(((int)(val / 100.0d)) * 100) / 1000.0d` quantization in the Drills app.
    // Also, snap values to absolute zero if below 0.1.
    double rawPitch = snapshot.pitch.abs() < 0.1 ? 0.0 : snapshot.pitch;
    double rawRoll = snapshot.roll.abs() < 0.1 ? 0.0 : snapshot.roll;

    final double pitchQuantized = (rawPitch * 10.0).round() / 10.0;
    final double rollQuantized = (rawRoll * 10.0).round() / 10.0;

    final double pitchRad = pitchQuantized * math.pi / 180.0;
    final double rollRad = rollQuantized * math.pi / 180.0;
    final double cosVal = math.cos(pitchRad) * math.cos(rollRad);
    final double angleDeg = math.acos(cosVal.clamp(-1.0, 1.0)) * 180.0 / math.pi;

    _angleHistory.add(angleDeg);
    // Keep a shorter window of 12 frames so the average angle adapts faster when movement stops.
    if (_angleHistory.length > 12) {
      _angleHistory.removeAt(0);
    }

    final double avgAngle = _angleHistory.reduce((a, b) => a + b) / _angleHistory.length;
    double instability = (angleDeg - avgAngle).abs() * 60.0;

    // Apply a noise gate: if instability is under 0.15 MOA (sub-micro tremors), snap it to 0.0.
    if (instability < 0.15) {
      instability = 0.0;
    }

    _stabilityHistory.add(instability);
    if (_stabilityHistory.length > 5) {
      _stabilityHistory.removeAt(0);
    }

    // 2. Replicate the exact recursive decay formula from the Shooters Global app:
    // stability = (sum(instabilityHistory) + previousStability) / (historyLength + 1)
    // This creates an extremely aggressive exponential decay (decaying by 1/6th per frame when still),
    // causing the stability value to snap to 0 virtually instantly.
    final double historySum = _stabilityHistory.reduce((a, b) => a + b);
    final double prevStability = latestSnapshot?.stability ?? 0.0;
    double stability = (historySum + prevStability) / (_stabilityHistory.length + 1);

    if (stability < 0.15) {
      stability = 0.0;
    }

    latestSnapshot = PulseSnapshot(
      roll: snapshot.roll,
      pitch: snapshot.pitch,
      yaw: snapshot.yaw,
      stability: stability,
      isShoot: snapshot.isShoot,
      stabilityX: snapshot.stabilityX,
      stabilityY: snapshot.stabilityY,
    );
    notifyListeners();
  }

  void _onShotDetected() {
    shotCount++;
    isShotFlashing = true;
    _shotDetectedController.add(null);
    notifyListeners();
    debugPrint('[SgPulseProvider] Shot detected! Total: $shotCount');
    
    // Clear flash after 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      isShotFlashing = false;
      notifyListeners();
    });
  }

  /// Clear the running shot count and stability filters.
  void clearSession() {
    shotCount = 0;
    isShotFlashing = false;
    _angleHistory.clear();
    _stabilityHistory.clear();
    notifyListeners();
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
        final silenced = prefs.getBool('silence_sg_pulse_battery_low') ?? false;
        debugPrint('[SgPulseProvider] Battery is low: $batteryLevel%. silenced: $silenced');
        if (!silenced) {
          _batteryLowController.add(batteryLevel);
        }
      }
    } else {
      // Clear ignore if battery is >= threshold
      debugPrint('[SgPulseProvider] Battery is healthy: $batteryLevel%. Clearing silence flag.');
      await prefs.setBool('silence_sg_pulse_battery_low', false);
    }
  }

  Future<void> silenceBatteryLowWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('silence_sg_pulse_battery_low', true);
  }

  Future<void> setBatteryWarningThreshold(int value) async {
    batteryWarningThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_batteryWarningThresholdKey, value);
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _updateState(SgPulseConnectionState state) {
    connectedDevice = connectedDevice?.copyWith(state: state);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    _shotDetectedController.close();
    _batteryLowController.close();
    super.dispose();
  }
}
