import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/rx5000_device.dart';

// ──────────────────────────────────────────────────────────────────────────────
// CRC32 Helper
// ──────────────────────────────────────────────────────────────────────────────

class Crc32 {
  static const int polynomial = 0xEDB88320;
  static final List<int> _table = List<int>.generate(256, (i) {
    int crc = i;
    for (int j = 8; j > 0; j--) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ polynomial;
      } else {
        crc >>= 1;
      }
    }
    return crc;
  });

  static int compute(List<int> data) {
    int crc = 0xFFFFFFFF;
    for (final b in data) {
      crc = (crc >> 8) ^ _table[(crc ^ b) & 0xFF];
    }
    return crc ^ 0xFFFFFFFF;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Radix64 Utilities
// ──────────────────────────────────────────────────────────────────────────────

class Radix64Util {
  static const String radix64Character =
      "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+-";

  static final List<int> radix64Value = List<int>.generate(256, (i) {
    final char = String.fromCharCode(i);
    final idx = radix64Character.indexOf(char);
    return idx != -1 ? idx : 0;
  });

  static String toRadix64(int val) {
    return radix64Character[val & 0x3F];
  }

  static int fromRadix64(int asciiCode) {
    return radix64Value[asciiCode & 0xFF];
  }

  static String radix64EncodeValue(int bits, int x) {
    final sb = StringBuffer();
    switch (bits) {
      case 8:
        final b = x & 0xFF;
        sb.write(toRadix64(b >> 6));
        sb.write(toRadix64(b & 0x3F));
        break;
      case 12:
        final b = x & 0xFF;
        final b2 = (x >> 8) & 0xFF;
        sb.write(toRadix64(((b2 & 0xF) << 2) | (b >> 6)));
        sb.write(toRadix64(b & 0x3F));
        break;
      case 16:
        final b = x & 0xFF;
        final b2 = (x >> 8) & 0xFF;
        sb.write(toRadix64(b2 >> 4));
        sb.write(toRadix64(((b2 & 0xF) << 2) | (b >> 6)));
        sb.write(toRadix64(b & 0x3F));
        break;
      case 32:
        final b = x & 0xFF;
        final b2 = (x >> 8) & 0xFF;
        final b3 = (x >> 16) & 0xFF;
        final b4 = (x >> 24) & 0xFF;
        sb.write(toRadix64(b4 >> 6));
        sb.write(toRadix64(b4 & 0x3F));
        sb.write(toRadix64(b3 >> 2));
        sb.write(toRadix64((b2 >> 4) | ((b3 & 3) << 4)));
        sb.write(toRadix64(((b2 & 0xF) << 2) | (b >> 6)));
        sb.write(toRadix64(b & 0x3F));
        break;
    }
    return sb.toString();
  }

  static int radix64DecodeValue(int bits, List<int> a, Position pos, ExtraBits extraBits) {
    int num = 0;
    switch (bits) {
      case 8:
        num |= a[pos.value + 1] | ((a[pos.value] << 6) & 0xFF);
        extraBits.value = a[pos.value] >> 2;
        pos.value += 2;
        break;
      case 12:
        num |= a[pos.value + 1] | ((a[pos.value] << 6) & 0xFF);
        num |= (a[pos.value] >> 2 << 8);
        extraBits.value = 0;
        pos.value += 2;
        break;
      case 16:
        num |= a[pos.value + 2] | ((a[pos.value + 1] << 6) & 0xFF);
        num |= (((a[pos.value + 1] >> 2) | ((a[pos.value] << 4) & 0xFF)) << 8);
        extraBits.value = a[pos.value] >> 4;
        pos.value += 3;
        break;
      case 32:
        num |= a[pos.value + 5] | ((a[pos.value + 4] << 6) & 0xFF);
        num |= (((a[pos.value + 4] >> 2) | ((a[pos.value + 3] << 4) & 0xFF)) << 8);
        num |= (((a[pos.value + 3] >> 4) | ((a[pos.value + 2] << 2) & 0xFF)) << 16);
        num |= ((a[pos.value + 1] | ((a[pos.value] << 6) & 0xFF)) << 24);
        extraBits.value = a[pos.value] >> 2;
        pos.value += 6;
        break;
    }
    return num;
  }

  static String computeChecksum(String s) {
    final bytes = ascii.encode(s);
    int num = 0;
    for (int i = 3; i < bytes.length; i++) {
      num += bytes[i];
    }
    return toRadix64(num & 0x3F);
  }

  static bool verifyChecksum(String s) {
    final length = s.length;
    final bytes = ascii.encode(s);
    int num = 0;
    for (int i = 0; i < length - 1; i++) {
      num += bytes[i];
    }
    return fromRadix64(bytes[length - 1]) == (num & 0x3F);
  }

  static String assembleReadRequest(String req, int sequenceNumber, List<int> regs) {
    final sb = StringBuffer();
    sb.write(req);
    sb.write(toRadix64(sequenceNumber));
    sb.write(toRadix64(regs.length));
    for (final x in regs) {
      sb.write(radix64EncodeValue(12, x));
    }
    final text = sb.toString();
    return '$text${computeChecksum(text)}?';
  }

  static String assembleWriteRequest(String req, int sequenceNumber, List<int> regs, List<int> data, int bits) {
    final sb = StringBuffer();
    sb.write(req);
    sb.write(toRadix64(sequenceNumber));
    sb.write(toRadix64(regs.length));
    for (int i = 0; i < regs.length; i++) {
      sb.write(radix64EncodeValue(12, regs[i]));
      sb.write(radix64EncodeValue(bits, data[i]));
    }
    final text = sb.toString();
    return '$text${computeChecksum(text)}?';
  }
}

class Position {
  int value;
  Position(this.value);
}

class ExtraBits {
  int value = 0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Guid Cryptography Utilities (to match .NET Guid/SecurityUtil)
// ──────────────────────────────────────────────────────────────────────────────

class SecurityUtil {
  static const String lookup = "ACEFHLPSU";

  static Uint8List uuidToGuidBytes(String uuidString) {
    final clean = uuidString.replaceAll('-', '').toLowerCase();
    if (clean.length != 32) return Uint8List(16);
    final bytes = Uint8List(16);
    bytes[0] = int.parse(clean.substring(6, 8), radix: 16);
    bytes[1] = int.parse(clean.substring(4, 6), radix: 16);
    bytes[2] = int.parse(clean.substring(2, 4), radix: 16);
    bytes[3] = int.parse(clean.substring(0, 2), radix: 16);
    bytes[4] = int.parse(clean.substring(10, 12), radix: 16);
    bytes[5] = int.parse(clean.substring(8, 10), radix: 16);
    bytes[6] = int.parse(clean.substring(14, 16), radix: 16);
    bytes[7] = int.parse(clean.substring(12, 14), radix: 16);
    for (int i = 0; i < 8; i++) {
      bytes[8 + i] = int.parse(clean.substring(16 + i * 2, 18 + i * 2), radix: 16);
    }
    return bytes;
  }

  static String guidBytesToUuid(Uint8List bytes) {
    if (bytes.length != 16) return '';
    String byteToHex(int b) => b.toRadixString(16).padLeft(2, '0');
    final d1 = byteToHex(bytes[3]) + byteToHex(bytes[2]) + byteToHex(bytes[1]) + byteToHex(bytes[0]);
    final d2 = byteToHex(bytes[5]) + byteToHex(bytes[4]);
    final d3 = byteToHex(bytes[7]) + byteToHex(bytes[6]);
    final d4 = byteToHex(bytes[8]) + byteToHex(bytes[9]);
    final d5 = byteToHex(bytes[10]) + byteToHex(bytes[11]) + byteToHex(bytes[12]) + byteToHex(bytes[13]) + byteToHex(bytes[14]) + byteToHex(bytes[15]);
    return '$d1-$d2-$d3-$d4-$d5';
  }

  static int encryptPin(int pin, int salt) {
    final bytes = ascii.encode(pin.toString());
    final bytes2 = Uint8List(4)..buffer.asByteData().setUint32(0, salt, Endian.little);
    final buffer = <int>[];
    for (int i = 0; i < 10; i++) {
      buffer.addAll(bytes);
      buffer.addAll(bytes2);
    }
    return Crc32.compute(buffer);
  }

  static int encryptTokenChallenge(int challenge, Uint8List keyBytes) {
    final array2 = Uint8List(128);
    int num = 0;
    int tempChallenge = challenge;
    for (int i = 0; i < 8; i++) {
      final num2 = tempChallenge & 0xF;
      for (int j = 0; j < 16; j++) {
        array2[num++] = keyBytes[(num2 + j) % 16];
      }
      tempChallenge >>= 4;
    }
    return Crc32.compute(array2);
  }

  static String decryptToken(String encodedGuidStr, int pin) {
    final bytes = uuidToGuidBytes(encodedGuidStr);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] ^= ((pin * (i + 1)) & 0xFF);
    }
    return guidBytesToUuid(bytes);
  }

  static String getAlphaCode(int code) {
    final firstIdx = ((code >> 4) & 0xF) % lookup.length;
    final secondIdx = (code & 0xF) % lookup.length;
    return "${lookup[firstIdx]}${lookup[secondIdx]}";
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Rx5000NotificationBuffer
// ──────────────────────────────────────────────────────────────────────────────

class Rx5000NotificationBuffer {
  final List<int> _buffer = [];

  List<String> addDataAndGetMessages(List<int> data) {
    _buffer.addAll(data);
    final messages = <String>[];

    while (true) {
      final text = ascii.decode(_buffer, allowInvalid: true);
      final startIdx = text.indexOf('\$');
      if (startIdx == -1) {
        _buffer.clear();
        break;
      }

      int endIdx = -1;
      for (int i = startIdx; i < text.length; i++) {
        final char = text[i];
        if (char == '!' || char == '\n') {
          endIdx = i;
          break;
        }
      }

      if (endIdx == -1) {
        if (startIdx > 0) {
          _buffer.removeRange(0, startIdx);
        }
        break;
      }

      final message = text.substring(startIdx, endIdx + 1);
      messages.add(message);

      final consumedBytes = ascii.encode(text.substring(0, endIdx + 1)).length;
      _buffer.removeRange(0, consumedBytes);
    }

    return messages;
  }

  void clear() {
    _buffer.clear();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Low-Level BLE Service
// ──────────────────────────────────────────────────────────────────────────────

typedef Rx5000ScanResultCallback = void Function(Rx5000Device device, bool inPairingMode);
typedef Rx5000ConnectionCallback = void Function(Rx5000ConnectionState state);
typedef Rx5000RegisterCallback = void Function(int register, int value);
typedef Rx5000RangeCallback = void Function(Map<String, dynamic> rangeData);
typedef Rx5000TokenCallback = void Function(String encryptedTokenGuid);

class Rx5000BleService {
  static const String serviceDataUuid = "0000FCF9-0000-1000-8000-00805F9B34FB";
  static const String dfuServiceUuid = "0000FE59-0000-1000-8000-00805F9B34FB";

  static const String dataService = "38400001-7537-4a20-b134-6762e12627bf";
  static const String writeChar = "38400002-7537-4a20-b134-6762e12627bf";
  static const String notifyChar = "38400003-7537-4a20-b134-6762e12627bf";

  Rx5000ScanResultCallback? onScanResult;
  Rx5000ConnectionCallback? onConnectionStateChanged;
  Rx5000RegisterCallback? onRegisterReceived;
  Rx5000RangeCallback? onRangeReceived;
  Rx5000TokenCallback? onTokenReceived;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  Timer? _scanTimer;
  bool _isAutoConnecting = false;
  bool _isDiscoveringOrConnected = false;
  int _sequenceNumber = 0;

  final Set<String> _discovered = {};
  final Rx5000NotificationBuffer _notificationBuffer = Rx5000NotificationBuffer();

  // Track pending responses by sequence number
  final Map<int, Completer<String>> _pendingRequests = {};

  int _nextSeq() {
    _sequenceNumber = (_sequenceNumber + 1) % 64;
    return _sequenceNumber;
  }

  // ── Scan ────────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    _discovered.clear();
    await _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _onScanResults,
      onError: (e) => debugPrint('[Rx5000BLE] Scan error: $e'),
    );

    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceDataUuid)],
      timeout: const Duration(seconds: 10),
    );

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 10), stopScan);
  }

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

      final address = result.device.remoteId.str;
      if (_discovered.contains(address)) continue;

      // Filter and parse Service Data for FCF9
      List<int>? serviceData;
      for (final entry in result.advertisementData.serviceData.entries) {
        final uuidStr = entry.key.str.toLowerCase();
        if (uuidStr == 'fcf9' || uuidStr == '0000fcf9-0000-1000-8000-00805f9b34fb') {
          serviceData = entry.value;
          break;
        }
      }

      if (serviceData == null || serviceData.length < 19) continue;

      final productId = serviceData[2];
      if (productId != 1) continue; // Must match Leupold Product ID 1

      final inPairingMode = (serviceData[18] & 1) > 0;
      final uniqueIdBytes = serviceData.sublist(4, 12);
      final uniqueId = uniqueIdBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

      _discovered.add(address);
      onScanResult?.call(
        Rx5000Device(
          name: name,
          address: address,
          uniqueId: uniqueId,
        ),
        inPairingMode,
      );
    }
  }

  // ── Connect ─────────────────────────────────────────────────────────────────

  Future<void> connect(Rx5000Device device, {bool autoConnect = false}) async {
    if (!autoConnect) {
      await stopScan();
    }

    final btDevice = BluetoothDevice.fromId(device.address);
    _connectedDevice = btDevice;
    _isAutoConnecting = autoConnect;
    _isDiscoveringOrConnected = false;

    if (!autoConnect) {
      onConnectionStateChanged?.call(Rx5000ConnectionState.connecting);
    }

    await _connectionSubscription?.cancel();
    _connectionSubscription = btDevice.connectionState.listen(_onConnectionStateChange);

    await btDevice.connect(
      autoConnect: autoConnect,
      timeout: autoConnect ? const Duration(days: 365) : const Duration(seconds: 15),
    );
  }

  void _onConnectionStateChange(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.connected) {
      _isAutoConnecting = false;
      if (_isDiscoveringOrConnected) return;
      _isDiscoveringOrConnected = true;
      onConnectionStateChanged?.call(Rx5000ConnectionState.discovering);
      Future.delayed(const Duration(milliseconds: 600), _discoverServices);
    } else if (state == BluetoothConnectionState.disconnected) {
      _isDiscoveringOrConnected = false;
      _notifySubscription?.cancel();
      _notifySubscription = null;
      _writeCharacteristic = null;
      _notificationBuffer.clear();
      _pendingRequests.clear();
      if (!_isAutoConnecting) {
        onConnectionStateChanged?.call(Rx5000ConnectionState.disconnected);
      }
    }
  }

  Future<void> _discoverServices() async {
    final device = _connectedDevice;
    if (device == null) return;

    try {
      try {
        await device.requestMtu(244);
        debugPrint('[Rx5000BLE] Requested MTU 244 successfully.');
      } catch (e) {
        debugPrint('[Rx5000BLE] MTU request not supported/failed: $e');
      }

      final services = await device.discoverServices();
      BluetoothCharacteristic? readChar;

      for (final service in services) {
        final serviceUuid = service.serviceUuid.str.toLowerCase();
        if (serviceUuid == dataService.toLowerCase()) {
          for (final char in service.characteristics) {
            final uuid = char.characteristicUuid.str.toLowerCase();
            if (uuid == writeChar.toLowerCase()) {
              _writeCharacteristic = char;
            } else if (uuid == notifyChar.toLowerCase()) {
              readChar = char;
            }
          }
        }
      }

      if (_writeCharacteristic != null && readChar != null) {
        await _enableNotify(readChar);
        onConnectionStateChanged?.call(Rx5000ConnectionState.connected);
      } else {
        debugPrint('[Rx5000BLE] RX5000 Data characteristics not found.');
        onConnectionStateChanged?.call(Rx5000ConnectionState.error);
      }
    } catch (e) {
      debugPrint('[Rx5000BLE] Service discovery error: $e');
      _isDiscoveringOrConnected = false;
      onConnectionStateChanged?.call(Rx5000ConnectionState.error);
    }
  }

  Future<void> _enableNotify(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      await _notifySubscription?.cancel();
      _notifySubscription = characteristic.onValueReceived.listen((bytes) {
        if (bytes.isEmpty) return;
        debugPrint('[Rx5000BLE] Notify bytes received: $bytes');
        final messages = _notificationBuffer.addDataAndGetMessages(bytes);
        for (final msg in messages) {
          _handleMessage(msg);
        }
      });
    } catch (e) {
      debugPrint('[Rx5000BLE] Failed to enable notify: $e');
    }
  }

  // ── Message Handler ──────────────────────────────────────────────────────────

  void _handleMessage(String rawMsg) {
    debugPrint('[Rx5000BLE] Message Received: $rawMsg');
    var text = rawMsg.trim();
    if (text.length < 2) return;
    
    // Trim the single character delimiter ('!' or '\n') if present at the end
    if (text.endsWith('!') || text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
    }
    
    final textWithoutDelim = text;

    // 1. Encrypted Token packet
    if (textWithoutDelim.startsWith('\$K=')) {
      final token = textWithoutDelim.split('=')[1];
      onTokenReceived?.call(token);
      return;
    }

    // 2. Read response packets ($R4=)
    if (textWithoutDelim.startsWith('\$R4=')) {
      final rawPayload = textWithoutDelim.replaceAll('\$R4=', '');
      if (Radix64Util.verifyChecksum(rawPayload)) {
        final payloadBytes = ascii.encode(rawPayload);
        final bytes = payloadBytes.map((b) => Radix64Util.fromRadix64(b)).toList();
        
        // Offset indices by 0 and 1 since prefix is stripped from rawPayload
        final seq = bytes[0];
        final count = bytes[1];
        
        final list = <int>[];
        final pos = Position(2);
        final extra = ExtraBits();
        for (int i = 0; i < count; i++) {
          list.add(Radix64Util.radix64DecodeValue(32, bytes, pos, extra));
        }

        final responseStr = list.isNotEmpty ? list.join(',') : '';
        final completer = _pendingRequests.remove(seq);
        completer?.complete(responseStr);
      }
      return;
    }

    // 3. Write response packets ($W4=)
    if (textWithoutDelim.startsWith('\$W4=')) {
      final rawPayload = textWithoutDelim.replaceAll('\$W4=', '');
      if (Radix64Util.verifyChecksum(rawPayload)) {
        final payloadBytes = ascii.encode(rawPayload);
        final bytes = payloadBytes.map((b) => Radix64Util.fromRadix64(b)).toList();
        
        // Offset indices by 0 and 1 since prefix is stripped from rawPayload
        final seq = bytes[0];
        final count = bytes[1];

        final returnCodes = <int>[];
        for (int i = 0; i < count; i++) {
          returnCodes.add(bytes[2 + i]);
        }

        final responseStr = returnCodes.isNotEmpty ? returnCodes.join(',') : '';
        final completer = _pendingRequests.remove(seq);
        completer?.complete(responseStr);
      }
      return;
    }

    // 4. Register update packet ($N=)
    if (textWithoutDelim.startsWith('\$N=')) {
      final payload = textWithoutDelim.substring(3);
      if (Radix64Util.verifyChecksum(payload)) {
        final payloadBytes = ascii.encode(payload);
        final bytes = payloadBytes.map((b) => Radix64Util.fromRadix64(b)).toList();
        final pos = Position(0);
        final extra = ExtraBits();
        final reg = Radix64Util.radix64DecodeValue(12, bytes, pos, extra);
        final val = Radix64Util.radix64DecodeValue(32, bytes, pos, extra);
        onRegisterReceived?.call(reg, val);
      }
      return;
    }

    // 5. Range measurement packet ($R=)
    if (textWithoutDelim.startsWith('\$R=')) {
      try {
        final params = textWithoutDelim.split('=')[1].split(',');
        if (params.length >= 12) {
          final isPin = int.tryParse(params[0]) == 1;
          final range = double.tryParse(params[1]);
          final accuracy = double.tryParse(params[2]);
          final inclination = int.tryParse(params[3]);
          final inclinationAccuracy = int.tryParse(params[4]);
          final heading = isPin ? double.tryParse(params[5]) : null;
          final headingAccuracy = isPin ? int.tryParse(params[6]) : null;
          final compassCal = isPin ? int.tryParse(params[7]) : null;
          final magField = isPin ? int.tryParse(params[8]) : null;
          final distance = double.tryParse(params[9]);
          final verticalDistance = double.tryParse(params[10]);
          final windage = double.tryParse(params[11]);
          final id = params.length > 12 ? params[12] : '';

          onRangeReceived?.call({
            'isPin': isPin,
            'range': range,
            'accuracy': accuracy,
            'inclination': inclination,
            'inclinationAccuracy': inclinationAccuracy,
            'heading': heading,
            'headingAccuracy': headingAccuracy,
            'compassCal': compassCal,
            'magField': magField,
            'distance': distance,
            'verticalDistance': verticalDistance,
            'windage': windage,
            'id': id,
          });
        }
      } catch (e) {
        debugPrint('[Rx5000BLE] Failed to parse range notification: $e');
      }
      return;
    }
  }

  // ── Write / Requests ────────────────────────────────────────────────────────

  Future<String> writeAndAwaitNotification(int register, {int? value}) async {
    final seq = _nextSeq();
    final requestStr = Radix64Util.assembleWriteRequest('\$W4', seq, [register], value != null ? [value] : [], value != null ? 32 : 12);
    
    final completer = Completer<String>();
    _pendingRequests[seq] = completer;

    debugPrint('[Rx5000BLE] Write Register: $register, Value: $value, Seq: $seq, Raw: $requestStr');
    await _writeRaw(requestStr);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(seq);
        throw TimeoutException('Timeout waiting for register $register response');
      },
    );
  }

  Future<String> readRegister(int register) async {
    final seq = _nextSeq();
    final requestStr = Radix64Util.assembleReadRequest('\$R4', seq, [register]);

    final completer = Completer<String>();
    _pendingRequests[seq] = completer;

    debugPrint('[Rx5000BLE] Read Register: $register, Seq: $seq, Raw: $requestStr');
    await _writeRaw(requestStr);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(seq);
        throw TimeoutException('Timeout waiting for register $register response');
      },
    );
  }

  Future<void> _writeRaw(String data) async {
    final char = _writeCharacteristic;
    if (char == null) throw Exception('Write characteristic is null (disconnected)');
    final bytes = ascii.encode(data);
    await char.write(bytes, withoutResponse: true);
  }

  // ── Disconnect ──────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _isAutoConnecting = false;
    _isDiscoveringOrConnected = false;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _writeCharacteristic = null;
    _pendingRequests.clear();

    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }

  void dispose() {
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
