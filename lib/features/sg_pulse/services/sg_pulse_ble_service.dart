// Low-level BLE service for SG Pulse device communication.
//
// Responsibilities:
//   - Scan with OS-level service UUID filter (only SG Pulse devices appear).
//   - Connect via GATT, discover services, enable NOTIFY on pulse + shot chars.
//   - Expose scan results, connection events, and live data via callbacks.
//
// This class has no UI and no Provider dependencies.
// All state is surfaced via callbacks — [SgPulseProvider] wires these up.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/sg_pulse_ble_constants.dart';
import '../models/sg_pulse_device.dart';
import '../models/pulse_snapshot.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Callback typedefs
// ──────────────────────────────────────────────────────────────────────────────

typedef SgPulseScanResultCallback      = void Function(SgPulseDevice device);
typedef SgPulseConnectionCallback      = void Function(SgPulseConnectionState state);
typedef SgPulsePulseDataCallback       = void Function(PulseSnapshot snapshot);
typedef SgPulseShotDetectedCallback    = void Function();

// ──────────────────────────────────────────────────────────────────────────────
// SgPulseBleService
// ──────────────────────────────────────────────────────────────────────────────

class SgPulseBleService {
  // Callbacks — set by SgPulseProvider
  SgPulseScanResultCallback?   onScanResult;
  SgPulseConnectionCallback?   onConnectionStateChanged;
  SgPulsePulseDataCallback?    onPulseData;
  SgPulseShotDetectedCallback? onShotDetected;

  // Internal state
  BluetoothDevice? _connectedDevice;

  StreamSubscription<List<ScanResult>>?       _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>?              _pulseSubscription;
  StreamSubscription<List<int>>?              _shotSubscription;
  Timer? _scanTimer;

  /// Tracks addresses already surfaced to avoid duplicates.
  final Set<String> _discovered = {};

  // ────────────────────────────────────────────────────────────────────────────
  // Scan
  // ────────────────────────────────────────────────────────────────────────────

  /// Starts a BLE scan filtered to the SG Pulse service UUID only.
  Future<void> startScan() async {
    _discovered.clear();
    await _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _onScanResults,
      onError: (e) => debugPrint('[SgPulseBLE] Scan error: $e'),
    );

    await FlutterBluePlus.startScan(
      timeout: sgPulseScanTimeout,
    );

    _scanTimer?.cancel();
    _scanTimer = Timer(sgPulseScanTimeout, stopScan);
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
      final name = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : (result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Unknown Device');

      // Filter to only show SG devices (e.g. "sg-PL1A01882")
      if (!name.toUpperCase().startsWith('SG')) continue;

      final address = result.device.remoteId.str;
      if (_discovered.contains(address)) continue;
      _discovered.add(address);

      onScanResult?.call(SgPulseDevice(name: name, address: address));
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Connect
  // ────────────────────────────────────────────────────────────────────────────

  /// Connects to a discovered [device].
  Future<void> connect(SgPulseDevice device, {bool autoConnect = false}) async {
    if (!autoConnect) {
      await stopScan();
    }

    final btDevice = BluetoothDevice.fromId(device.address);
    _connectedDevice = btDevice;

    onConnectionStateChanged?.call(SgPulseConnectionState.connecting);

    await _connectionSubscription?.cancel();
    _connectionSubscription =
        btDevice.connectionState.listen(_onConnectionStateChange);

    await btDevice.connect(
      autoConnect: autoConnect,
      timeout: autoConnect
          ? const Duration(days: 365)
          : const Duration(seconds: 15),
    );
  }

  void _onConnectionStateChange(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.connected) {
      onConnectionStateChanged?.call(SgPulseConnectionState.discovering);
      Future.delayed(sgPulseServiceDiscoveryDelay, _discoverServices);
    } else if (state == BluetoothConnectionState.disconnected) {
      _pulseSubscription?.cancel();
      _shotSubscription?.cancel();
      _pulseSubscription = null;
      _shotSubscription = null;
      onConnectionStateChanged?.call(SgPulseConnectionState.disconnected);
    }
  }

  Future<void> _discoverServices() async {
    final device = _connectedDevice;
    if (device == null) return;

    try {
      final services = await device.discoverServices();

      for (final service in services) {
        debugPrint('[SgPulseBLE] Found service: ${service.serviceUuid.str}');
        for (final char in service.characteristics) {
          final uuid = char.characteristicUuid.str.toLowerCase();
          final p = char.properties;
          debugPrint('[SgPulseBLE]   -> Found char: $uuid (N:${p.notify}, I:${p.indicate}, R:${p.read}, W:${p.write}, WWoR:${p.writeWithoutResponse})');

          if (uuid == sgPulseCharPulseStream.toLowerCase()) {
            debugPrint('[SgPulseBLE] Pulse stream characteristic found');
            await _enableNotify(char, isPulse: true);
          }

          if (uuid == sgPulseCharShotEvent.toLowerCase()) {
            debugPrint('[SgPulseBLE] Shot event characteristic found');
            await _enableNotify(char, isPulse: false);
          }
        }
      }

      // Request high-priority connection for low-latency streaming
      await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );

      onConnectionStateChanged?.call(SgPulseConnectionState.connected);
      debugPrint('[SgPulseBLE] Connected and streaming');
    } catch (e) {
      debugPrint('[SgPulseBLE] Service discovery error: $e');
      onConnectionStateChanged?.call(SgPulseConnectionState.error);
    }
  }

  Future<void> _enableNotify(
    BluetoothCharacteristic characteristic, {
    required bool isPulse,
  }) async {
    try {
      await characteristic.setNotifyValue(true);
      final sub = characteristic.lastValueStream.listen((bytes) {
        if (bytes.isEmpty) return;
        if (isPulse) {
          final snapshot = PulseSnapshot.fromBytes(bytes);
          if (snapshot != null) {
            onPulseData?.call(snapshot);
            // Also fire shot callback from pulse stream if isShoot is set
            if (snapshot.isShoot) onShotDetected?.call();
          } else {
            debugPrint('[SgPulseBLE] Unrecognised pulse payload '
                '(${bytes.length} bytes): '
                '${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          }
        } else {
          // Dedicated shot-event characteristic
          onShotDetected?.call();
        }
      });

      if (isPulse) {
        await _pulseSubscription?.cancel();
        _pulseSubscription = sub;
      } else {
        await _shotSubscription?.cancel();
        _shotSubscription = sub;
      }

      debugPrint('[SgPulseBLE] NOTIFY enabled on '
          '${isPulse ? 'pulse' : 'shot'} characteristic');
    } catch (e) {
      debugPrint('[SgPulseBLE] Failed to enable NOTIFY: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Disconnect / cleanup
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _pulseSubscription?.cancel();
    await _shotSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _pulseSubscription = null;
    _shotSubscription = null;
    _connectionSubscription = null;

    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }

  void dispose() {
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    _pulseSubscription?.cancel();
    _shotSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
