// State management for Kestrel BLE connectivity.
//
// This [ChangeNotifier] sits between [KestrelBleService] (BLE layer) and
// the UI (scan screen, detail screen, settings screen).
//
// UI calls:   startScan()  connect()  disconnect()
// UI watches: scannedDevices, connectedDevice, connectionState, isScanning

import 'package:flutter/foundation.dart';

import '../models/kestrel_device.dart';
import '../services/kestrel_ble_service.dart';

class KestrelProvider extends ChangeNotifier {
  final KestrelBleService _service;

  KestrelProvider({KestrelBleService? service})
      : _service = service ?? KestrelBleService() {
    _service.onScanResult = _onScanResult;
    _service.onConnectionStateChanged = _onConnectionStateChanged;
    _service.onRxData = _onRxData;
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
  Future<void> connect(KestrelDevice device) async {
    connectedDevice = device.copyWith(state: KestrelConnectionState.connecting);
    notifyListeners();
    await _service.connect(device);
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    await _service.disconnect();
    connectedDevice = connectedDevice?.copyWith(
      state: KestrelConnectionState.disconnected,
    );
    notifyListeners();
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
