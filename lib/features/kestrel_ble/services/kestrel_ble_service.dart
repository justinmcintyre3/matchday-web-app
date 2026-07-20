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
import 'kestrel_jni_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Callback typedefs
// ──────────────────────────────────────────────────────────────────────────────

typedef KestrelScanResultCallback = void Function(KestrelDevice device);
typedef KestrelConnectionCallback = void Function(KestrelConnectionState state);
typedef KestrelRxCallback = void Function(List<int> bytes);
typedef KestrelBatteryCallback = void Function(int batteryLevel);

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
  KestrelBatteryCallback? onBatteryLevelReceived;

  // Internal state
  final KestrelJniService _jni = KestrelJniService();
  bool _isResettingHostPin = false;
  String? _currentPin;

  KestrelBleService() {
    _jni.onTxBytes.listen((bytes) {
      writeBytes(bytes);
    });
    
    _jni.onPrivacyStatus.listen((isPrivacy) {
      if (isPrivacy) {
        onConnectionStateChanged?.call(KestrelConnectionState.pinRequired);
      } else {
        if (!_hasSentAuthRequest) {
          _hasSentAuthRequest = true;
          _jni.sendRequestAuth();
        }
      }
    });

    _jni.onAuthRequestAck.listen((success) {
      debugPrint('[KestrelBLE] onAuthRequestAck: $success');
      if (!success) {
        onConnectionStateChanged?.call(KestrelConnectionState.error);
        disconnect();
      }
    });

    _jni.onPrivacyAuthAck.listen((success) {
      if (success) {
        if (_isResettingHostPin && _currentPin != null) {
          debugPrint('[KestrelBLE] Reset successful. Setting new Host PIN...');
          _isResettingHostPin = false;
          // After a successful reset, we immediately re-authenticate with our actual hostId
          authenticateWithPin(_currentPin!);
        } else if (!_hasAcknowledgedPin) {
          _hasAcknowledgedPin = true;
          debugPrint('[KestrelBLE] PIN accepted, waiting for native auth complete...');
          onConnectionStateChanged?.call(KestrelConnectionState.synchronizing);
          _jni.sendRequestAuth();
        }
      } else {
        if (!_isResettingHostPin && _currentPin != null) {
          debugPrint('[KestrelBLE] Auth failed. Attempting Host PIN reset...');
          // NACK received. If we haven't tried a reset yet, try it now
          authenticateWithPin(_currentPin!, resetHostPin: true);
        } else {
          debugPrint('[KestrelBLE] Auth failed even after reset (or reset failed). Disconnecting.');
          onConnectionStateChanged?.call(KestrelConnectionState.error);
          disconnect();
        }
      }
    });

    _jni.onAuthComplete.listen((success) {
      if (success) {
        debugPrint('[KestrelBLE] Native Auth complete, starting sync chain...');
        _jni.sendCmdGetTgtInfoSettings();
      } else {
        onConnectionStateChanged?.call(KestrelConnectionState.error);
        disconnect();
      }
    });

    _jni.onTgtInfoSettingsReceived.listen((_) {
      debugPrint('[KestrelBLE] onTgtInfoSettingsReceived');
      _jni.sendCmdGetGunTransferSettings();
    });

    _jni.onGunTransferSettingsReceived.listen((map) {
      final idx = map['activeGunIdx'] as int? ?? 0;
      final fmt = map['gunFormat'] as int? ?? 0;
      final ver = map['gunVersion'] as int? ?? 0;
      debugPrint('[KestrelBLE] onGunTransferSettingsReceived activeGunIdx: $idx');
      
      // Query active gun profile details during handshake
      _jni.sendCmdGetGun(index: idx, format: fmt, version: ver);
      _jni.sendCmdGetBalInfoSettings();
    });

    _jni.onBalInfoSettingsReceived.listen((_) {
      debugPrint('[KestrelBLE] onBalInfoSettingsReceived, sync complete!');
      onConnectionStateChanged?.call(KestrelConnectionState.connected);
    });
  }

  Stream<Map<String, dynamic>> get onGunTransferSettingsReceived => _jni.onGunTransferSettingsReceived;
  Stream<Map<String, dynamic>> get onActiveGunProfileReceived => _jni.onActiveGunProfileReceived;
  Stream<void> get onBalInfoSettingsReceived => _jni.onBalInfoSettingsReceived;
  Stream<Map<String, dynamic>> get onBalFullSolution => _jni.onBalFullSolution;
  Stream<bool> get onCalcFullSolnAck => _jni.onCalcFullSolnAck;

  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState? _lastBleState;
  BluetoothCharacteristic? _txCharacteristic;
  bool _hasSentAuthRequest = false;
  bool _hasAcknowledgedPin = false;
  bool _isDiscovering = false;

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

      final debugName = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : result.advertisementData.advName;
          
      debugPrint('[KestrelBLE] Scan result: $debugName ($address) - mfrData: ${result.advertisementData.manufacturerData.keys.toList()}');

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
  Future<void> connect(KestrelDevice device, {bool autoConnect = false}) async {
    await stopScan();

    if (_connectedDevice != null || _connectionSubscription != null) {
      debugPrint('[KestrelBLE] Existing connection resources found. Cleaning up first...');
      await disconnect();
    }

    final btDevice = BluetoothDevice.fromId(device.address);
    _connectedDevice = btDevice;
    _hasSentAuthRequest = false;
    _hasAcknowledgedPin = false;
    _lastBleState = BluetoothConnectionState.disconnected;

    // Only show the connecting spinner immediately if this is a manual connection attempt.
    // If it's a background auto-reconnect, stay in the disconnected state until the device is actually found.
    if (!autoConnect) {
      onConnectionStateChanged?.call(KestrelConnectionState.connecting);
    }

    // Listen for connection state changes before connecting
    await _connectionSubscription?.cancel();
    _connectionSubscription =
        btDevice.connectionState.listen(_onConnectionStateChange);

    await btDevice.connect(
      autoConnect: autoConnect,
      // 8s for direct connects — fast-fail if device is off, releasing GATT slot quickly.
      // autoConnect uses OS-managed background scanning, no active slot held.
      timeout: autoConnect ? const Duration(days: 365) : const Duration(seconds: 8),
    );
  }

  void _onConnectionStateChange(BluetoothConnectionState state) {
    if (state == _lastBleState) return;
    _lastBleState = state;

    if (state == BluetoothConnectionState.connected) {
      if (_isDiscovering) {
        debugPrint('[KestrelBLE] Already discovering/connected. Ignoring duplicate connection event.');
        return;
      }
      _isDiscovering = true;
      onConnectionStateChanged?.call(KestrelConnectionState.discovering);
      // Delay matches reference app (600 ms) before discoverServices
      Future.delayed(kestrelServiceDiscoveryDelay, _discoverServices);
    } else if (state == BluetoothConnectionState.disconnected) {
      _txCharacteristic = null;
      _isDiscovering = false; // Reset debounce flag on natural drop
      _jni.disconnectJni(); // CRITICAL: Reset the native state machine
      onConnectionStateChanged?.call(KestrelConnectionState.disconnected);
    }
  }

  Future<void> _discoverServices() async {
    _isDiscovering = true;
    
    try {
      debugPrint('[KestrelBLE] Discovering services...');
      final device = _connectedDevice;
      if (device == null) return;

      final services = await device.discoverServices();
      BluetoothCharacteristic? batteryChar;

      for (final service in services) {
        final serviceUuid = service.serviceUuid.str.toLowerCase();
        if (serviceUuid == '180f' || serviceUuid == '0000180f-0000-1000-8000-00805f9b34fb') {
          for (final char in service.characteristics) {
            final charUuid = char.characteristicUuid.str.toLowerCase();
            if (charUuid == '2a19' || charUuid == '00002a19-0000-1000-8000-00805f9b34fb') {
              batteryChar = char;
            }
          }
        }

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

      // Read battery in background so it doesn't delay JNI auth
      if (batteryChar != null) {
        batteryChar.read().then((bytes) {
          if (bytes.isNotEmpty) {
            final level = bytes[0];
            debugPrint('[KestrelBLE] Battery level read: $level%');
            onBatteryLevelReceived?.call(level);
          }
        }).catchError((e) {
          debugPrint('[KestrelBLE] Failed to read battery level: $e');
        });
      }

      // Begin Phase 2 Authentication Flow via JNI
      await Future.delayed(const Duration(milliseconds: 500));
      await _jni.connectJni();
      await _jni.sendCmdStopEncrypting();
      await Future.delayed(const Duration(milliseconds: 200));
      await _jni.sendCmdGetPrivacyStatus();
    } catch (e) {
      debugPrint('[KestrelBLE] Service discovery error: $e');
      _isDiscovering = false;
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
          if (bytes.isNotEmpty) {
            onRxData?.call(bytes);
            _jni.setRxBytes(bytes); // Feed BLE data into JNI state machine
          }
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

  Future<void> authenticateWithPin(String pin, {bool resetHostPin = false}) async {
    _currentPin = pin;
    _isResettingHostPin = resetHostPin;
    
    // Fetch the 4-digit hashed Host ID computed in native code matching the Link App algorithm
    // If we are resetting the host PIN, we send an empty string for hostId.
    final hostId = resetHostPin ? "" : await _jni.getHostId();
    debugPrint('[KestrelBLE] Authenticating with PIN: $pin and HostID: $hostId');
    await _jni.sendCmdPrivacyAuthenticate(pin, hostId);
  }

  /// Sends a latitude update to the Kestrel's global environment
  Future<void> updateLatitude(double latitude) async {
    await _jni.sendSetEnvironment(latitude);
  }

  /// Requests the Kestrel to send its current environment settings.
  Future<void> getEnvironment() async {
    await _jni.sendCmdGetEnvironment();
  }

  /// Requests the Kestrel to send its device name.
  Future<void> getDeviceName() async {
    await _jni.sendCmdGetDeviceName();
  }

  /// Requests the Kestrel to send its serial number.
  Future<void> getDeviceSerialNum() async {
    await _jni.sendCmdGetDeviceSerialNum();
  }

  /// Stream of environment data received from the Kestrel.
  Stream<Map<String, dynamic>> get onEnvironmentReceived => _jni.onEnvironmentReceived;

  /// Stream of device name received from the Kestrel.
  Stream<String?> get onDeviceNameReceived => _jni.onDeviceNameReceived;

  /// Stream of device serial number received from the Kestrel.
  Stream<String?> get onDeviceSNReceived => _jni.onDeviceSNReceived;

  /// Phase 1: write target inputs to a Kestrel slot (yards/mph/degrees from UI).
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
    await _jni.sendCmdSetBalFullInputs(
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

  /// Phase 2: request ballistics solution for a slot already on the Kestrel.
  Future<void> sendCalcFullSolution({required int targetNumber}) async {
    await _jni.sendCalcFullSolution(targetNumber: targetNumber);
  }

  Future<void> setActiveGunIdx(int index) async {
    await _jni.sendCmdSetActiveGunIdx(index);
  }

  Future<void> getGun({required int index, required int format, required int version}) async {
    await _jni.sendCmdGetGun(index: index, format: format, version: version);
  }

  Future<void> getRemoteDisplayData({required int gunFormat}) async {
    await _jni.sendCmdGetRemoteDisplayData(gunFormat: gunFormat);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Disconnect / cleanup
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _isDiscovering = false;
    await _jni.disconnectJni();
    await _rxSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _rxSubscription = null;
    _connectionSubscription = null;
    _txCharacteristic = null;

    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }

  void dispose() {
    _jni.dispose();
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    _rxSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
