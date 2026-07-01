// State management for SG Pulse BLE connectivity.
//
// This [ChangeNotifier] sits between [SgPulseBleService] (BLE layer) and
// the UI (scan screen, detail screen, settings screen).
//
// UI calls:   startScan()  connect()  disconnect()  forgetDevice()
// UI watches: scannedDevices, connectedDevice, connectionState,
//             isScanning, latestSnapshot, shotCount

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sg_pulse_device.dart';
import '../models/pulse_snapshot.dart';
import '../services/sg_pulse_ble_service.dart';

class SgPulseProvider extends ChangeNotifier {
  static const _savedDeviceKey = 'saved_sg_pulse_device';

  final SgPulseBleService _service;

  SgPulseProvider({SgPulseBleService? service})
      : _service = service ?? SgPulseBleService() {
    _service.onScanResult            = _onScanResult;
    _service.onConnectionStateChanged = _onConnectionStateChanged;
    _service.onPulseData             = _onPulseData;
    _service.onShotDetected          = _onShotDetected;
    _initPrefs();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Persistence
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
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
    latestSnapshot = snapshot;
    notifyListeners();
  }

  void _onShotDetected() {
    shotCount++;
    isShotFlashing = true;
    notifyListeners();
    debugPrint('[SgPulseProvider] Shot detected! Total: $shotCount');
    
    // Clear flash after 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      isShotFlashing = false;
      notifyListeners();
    });
  }

  /// Clear the running shot count.
  void clearSession() {
    shotCount = 0;
    isShotFlashing = false;
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
    super.dispose();
  }
}
