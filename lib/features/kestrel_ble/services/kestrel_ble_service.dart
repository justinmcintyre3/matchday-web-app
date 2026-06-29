// Low-level BLE service for Kestrel device communication.
//
// Responsibilities:
//   - Scan with OS-level service UUID filters (only Kestrel devices appear).
//   - Connect via GATT, discover services, and enable INDICATE on RX.
//   - Expose scan results and connection events via callbacks.
//   - Write raw bytes to the TX characteristic (max 20 bytes per chunk).
//
// This class has **no UI** and **no Provider** dependencies.
// All state updates are surfaced via [onScanResult], [onConnectionStateChanged],
// and [onRxData] callbacks — the [KestrelProvider] wires these up.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/kestrel_ble_constants.dart';
import '../models/kestrel_device.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Callback typedefs
// ──────────────────────────────────────────────────────────────────────────────

typedef KestrelScanResultCallback = void Function(KestrelDevice device);
typedef KestrelConnectionCallback = void Function(KestrelConnectionState state);
typedef KestrelRxCallback = void Function(List<int> bytes);

// ──────────────────────────────────────────────────────────────────────────────
// Model code → device type mapping
// (mirrors the reference app's managers/d.java lookup table)
// ──────────────────────────────────────────────────────────────────────────────

/// Maps the 2-byte little-endian manufacturer model code to a human-readable
/// device type string. Codes below are from the Kestrel firmware reference.
const Map<int, String> _modelCodeToType = {
  // 5700 / ELITE family
  0x5700: '5700',
  0x5701: 'ELITE',
  0x5702: 'ELITE',
  // 2700 family
  0x2700: '2700',
  // HUD
  0x4854: 'HUD',
};

String _resolveDeviceType(List<int>? manufacturerData) {
  if (manufacturerData == null || manufacturerData.length < 2) return 'Kestrel';
  // Little-endian 16-bit model code
  final code = manufacturerData[0] | (manufacturerData[1] << 8);
  return _modelCodeToType[code] ?? 'Kestrel';
}

// ──────────────────────────────────────────────────────────────────────────────
// KestrelBleService
// ──────────────────────────────────────────────────────────────────────────────

class KestrelBleService {
  // Callbacks — set by KestrelProvider
  KestrelScanResultCallback? onScanResult;
  KestrelConnectionCallback? onConnectionStateChanged;
  KestrelRxCallback? onRxData;

  // Internal state
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _rxSubscription;
  Timer? _scanTimer;

  /// Tracks addresses we have already surfaced to avoid duplicates.
  final Set<String> _discovered = {};

  // ────────────────────────────────────────────────────────────────────────────
  // Scan
  // ────────────────────────────────────────────────────────────────────────────

  /// Starts a BLE scan filtered to Kestrel service UUIDs only.
  ///
  /// Mirrors the reference app's v.java [k()] method:
  ///   - One [ScanFilter] per service UUID (OR semantics — any match surfaces).
  ///   - 30-second auto-stop (see [kestrelScanTimeout]).
  Future<void> startScan() async {
    _discovered.clear();
    await _scanSubscription?.cancel();

    // Build service UUID filters — only devices advertising these will appear
    final withServices = kestrelServiceUuids
        .map((uuid) => Guid(uuid))
        .toList();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _onScanResults,
      onError: (e) => debugPrint('[KestrelBLE] Scan error: $e'),
    );

    await FlutterBluePlus.startScan(
      withServices: withServices,
      timeout: kestrelScanTimeout,
    );

    // Auto-stop safety timer
    _scanTimer?.cancel();
    _scanTimer = Timer(kestrelScanTimeout, stopScan);
  }

  /// Stops the active BLE scan.
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  void _onScanResults(List<ScanResult> results) {
    for (final result in results) {
      final address = result.device.remoteId.str;
      if (_discovered.contains(address)) continue;

      // Secondary check: manufacturer ID 0xEA (234) must be present
      final mfrData = result.advertisementData
          .manufacturerData[kestrelManufacturerId];

      if (mfrData == null) continue; // Not a genuine NK device

      _discovered.add(address);

      final deviceType = _resolveDeviceType(mfrData);
      final name = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : (result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Kestrel $deviceType');

      final device = KestrelDevice(
        name: name,
        address: address,
        deviceType: deviceType,
        state: KestrelConnectionState.disconnected,
      );

      onScanResult?.call(device);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Connect
  // ────────────────────────────────────────────────────────────────────────────

  /// Connects to a discovered [device] and discovers GATT services.
  ///
  /// After a successful connection the caller will receive a
  /// [KestrelConnectionState.discovering] callback, then either
  /// [KestrelConnectionState.connected] (if no PIN required) or
  /// [KestrelConnectionState.pinRequired] once the privacy-status check
  /// is wired up (Phase 2).
  Future<void> connect(KestrelDevice device) async {
    await stopScan();

    final btDevice = BluetoothDevice.fromId(device.address);
    _connectedDevice = btDevice;

    onConnectionStateChanged?.call(KestrelConnectionState.connecting);

    // Listen for connection state changes before connecting
    await _connectionSubscription?.cancel();
    _connectionSubscription =
        btDevice.connectionState.listen(_onConnectionStateChange);

    await btDevice.connect(
      autoConnect: false,
      timeout: const Duration(seconds: 15),
    );
  }

  void _onConnectionStateChange(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.connected) {
      onConnectionStateChanged?.call(KestrelConnectionState.discovering);
      // Delay matches reference app (600 ms) before discoverServices
      Future.delayed(kestrelServiceDiscoveryDelay, _discoverServices);
    } else if (state == BluetoothConnectionState.disconnected) {
      _txCharacteristic = null;
      onConnectionStateChanged?.call(KestrelConnectionState.disconnected);
    }
  }

  Future<void> _discoverServices() async {
    final device = _connectedDevice;
    if (device == null) return;

    try {
      final services = await device.discoverServices();

      for (final service in services) {
        for (final char in service.characteristics) {
          final uuid = char.characteristicUuid.str.toLowerCase();

          if (uuid == kestrelCharTxBuf.toLowerCase()) {
            _txCharacteristic = char;
            debugPrint('[KestrelBLE] TX characteristic found');
          }

          if (uuid == kestrelCharRxBuf.toLowerCase()) {
            debugPrint('[KestrelBLE] RX characteristic found');
            await _enableIndicate(char);
          }
        }
      }

      // Request high-priority connection (matches reference app)
      await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );

      // For Phase 1 we surface as connected; PIN check comes when we
      // send the getPrivacyStatus command in Phase 2.
      onConnectionStateChanged?.call(KestrelConnectionState.connected);
    } catch (e) {
      debugPrint('[KestrelBLE] Service discovery error: $e');
      onConnectionStateChanged?.call(KestrelConnectionState.error);
    }
  }

  /// Enables INDICATE on the RX characteristic (mirrors reference app z() method).
  /// RX uses INDICATE, not NOTIFY.
  Future<void> _enableIndicate(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      await _rxSubscription?.cancel();
      _rxSubscription = characteristic.lastValueStream.listen(
        (bytes) {
          if (bytes.isNotEmpty) onRxData?.call(bytes);
        },
      );
      debugPrint('[KestrelBLE] INDICATE enabled on RX characteristic');
    } catch (e) {
      debugPrint('[KestrelBLE] Failed to enable INDICATE: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Write (for Phase 2 — PIN entry, ballistics data, etc.)
  // ────────────────────────────────────────────────────────────────────────────

  /// Writes [bytes] to the TX characteristic in [kestrelMaxPacketBytes]-byte
  /// chunks (mirrors BluetoothLeService.A() in the reference app).
  Future<void> writeBytes(List<int> bytes) async {
    final tx = _txCharacteristic;
    if (tx == null) {
      debugPrint('[KestrelBLE] writeBytes() — TX characteristic not ready');
      return;
    }

    // Chunk into 20-byte packets
    for (int i = 0; i < bytes.length; i += kestrelMaxPacketBytes) {
      final end = (i + kestrelMaxPacketBytes).clamp(0, bytes.length);
      final chunk = bytes.sublist(i, end);
      await tx.write(chunk, withoutResponse: false);
      debugPrint(
        '[KestrelBLE] Wrote ${chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()} '
        'to TX characteristic',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Disconnect / cleanup
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _rxSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _rxSubscription = null;
    _connectionSubscription = null;
    _txCharacteristic = null;

    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }

  void dispose() {
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    _rxSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
