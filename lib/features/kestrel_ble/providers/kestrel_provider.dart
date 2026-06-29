// State management for Kestrel BLE connectivity.
//
// This [ChangeNotifier] sits between [KestrelBleService] (BLE layer) and
// the UI (scan screen, detail screen, settings screen).
//
// UI calls:   startScan()  connect()  disconnect()
// UI watches: scannedDevices, connectedDevice, connectionState, isScanning

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/kestrel_device.dart';
import '../services/kestrel_ble_service.dart';

class KestrelProvider extends ChangeNotifier {
  static const _savedDeviceKey = 'saved_kestrel_device';
  final KestrelBleService _service;

  KestrelProvider({KestrelBleService? service})
      : _service = service ?? KestrelBleService() {
    _service.onScanResult = _onScanResult;
    _service.onConnectionStateChanged = _onConnectionStateChanged;
    _service.onRxData = _onRxData;
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_savedDeviceKey);
    if (savedJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        connectedDevice = KestrelDevice.fromJson(data);
        notifyListeners();
        
        // Give the UI a moment, then attempt auto-reconnect
        Future.delayed(const Duration(milliseconds: 500), _autoReconnect);
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

  Future<void> _autoReconnect() async {
    if (connectedDevice == null || isConnected) return;
    debugPrint('[KestrelProvider] Attempting auto-reconnect to ${connectedDevice?.name}');
    try {
      await connect(connectedDevice!, autoConnect: true);
    } catch (e) {
      debugPrint('[KestrelProvider] Auto-reconnect failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // State exposed to UI
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
    connectedDevice = device.copyWith(state: KestrelConnectionState.connecting);
    notifyListeners();
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
    if (savePin) {
      connectedDevice = connectedDevice?.copyWith(pin: pin);
    } else if (connectedDevice != null) {
      connectedDevice = KestrelDevice(
        name: connectedDevice!.name,
        address: connectedDevice!.address,
        deviceType: connectedDevice!.deviceType,
        state: connectedDevice!.state,
        modelName: connectedDevice!.modelName,
        serialNumber: connectedDevice!.serialNumber,
        firmwareVersion: connectedDevice!.firmwareVersion,
        hardwareVersion: connectedDevice!.hardwareVersion,
        errorMessage: connectedDevice!.errorMessage,
        pin: null, // explicitly wipe the pin
      );
    }
    await _service.authenticateWithPin(pin);
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
      _saveDevice();
    } 
    // Auto-authenticate if we already have the PIN saved
    else if (state == KestrelConnectionState.pinRequired) {
      if (connectedDevice?.pin != null) {
        debugPrint('[KestrelProvider] Auto-authenticating with saved PIN...');
        authenticateWithPin(connectedDevice!.pin!, savePin: true);
      }
    }
    // Set up a pending connection if it drops unexpectedly
    else if (state == KestrelConnectionState.disconnected && connectedDevice != null) {
      debugPrint('[KestrelProvider] Device disconnected. Setting up background auto-reconnect...');
      Future.delayed(const Duration(seconds: 1), _autoReconnect);
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

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
