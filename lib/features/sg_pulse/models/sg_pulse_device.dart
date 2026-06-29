// Data model representing a discovered or connected SG Pulse device.

import 'dart:convert';

// ──────────────────────────────────────────────────────────────────────────────
// Connection state enum
// ──────────────────────────────────────────────────────────────────────────────

enum SgPulseConnectionState {
  /// Not connected, not scanning.
  disconnected,

  /// BLE scan running, looking for devices.
  scanning,

  /// GATT connect in progress.
  connecting,

  /// Connected at GATT level; services being discovered.
  discovering,

  /// Fully connected and streaming data.
  connected,

  /// An error occurred; see [SgPulseDevice.errorMessage].
  error,
}

// ──────────────────────────────────────────────────────────────────────────────
// SgPulseDevice
// ──────────────────────────────────────────────────────────────────────────────

class SgPulseDevice {
  /// BLE device name from the advertisement.
  final String name;

  /// MAC address (Android) or UUID (iOS).
  final String address;

  final SgPulseConnectionState state;

  // Fields populated after connection + characteristic reads:
  final String? firmwareVersion;
  final String? hardwareVersion;
  final String? serialNumber;
  final String? modelNumber;
  final int? batteryLevel;

  final String? errorMessage;

  const SgPulseDevice({
    required this.name,
    required this.address,
    this.state = SgPulseConnectionState.disconnected,
    this.firmwareVersion,
    this.hardwareVersion,
    this.serialNumber,
    this.modelNumber,
    this.batteryLevel,
    this.errorMessage,
  });

  // ── JSON serialization for SharedPreferences persistence ──────────────────

  factory SgPulseDevice.fromJson(Map<String, dynamic> json) {
    return SgPulseDevice(
      name: json['name'] as String? ?? 'SG Pulse',
      address: json['address'] as String? ?? '',
      state: SgPulseConnectionState.disconnected,
      firmwareVersion: json['firmwareVersion'] as String?,
      hardwareVersion: json['hardwareVersion'] as String?,
      serialNumber: json['serialNumber'] as String?,
      modelNumber: json['modelNumber'] as String?,
      batteryLevel: json['batteryLevel'] as int?,
    );
  }

  factory SgPulseDevice.fromJsonString(String jsonStr) =>
      SgPulseDevice.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'firmwareVersion': firmwareVersion,
        'hardwareVersion': hardwareVersion,
        'serialNumber': serialNumber,
        'modelNumber': modelNumber,
        'batteryLevel': batteryLevel,
      };

  String toJsonString() => jsonEncode(toJson());

  // ── copyWith ──────────────────────────────────────────────────────────────

  SgPulseDevice copyWith({
    String? name,
    String? address,
    SgPulseConnectionState? state,
    String? firmwareVersion,
    String? hardwareVersion,
    String? serialNumber,
    String? modelNumber,
    int? batteryLevel,
    String? errorMessage,
  }) {
    return SgPulseDevice(
      name: name ?? this.name,
      address: address ?? this.address,
      state: state ?? this.state,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      modelNumber: modelNumber ?? this.modelNumber,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'SgPulseDevice(name: $name, address: $address, state: $state)';
}
