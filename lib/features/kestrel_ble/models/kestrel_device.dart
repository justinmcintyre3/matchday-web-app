// Data model representing a discovered or connected Kestrel device.

// ──────────────────────────────────────────────────────────────────────────────
// Connection state enum
// ──────────────────────────────────────────────────────────────────────────────

enum KestrelConnectionState {
  /// Not connected, not scanning.
  disconnected,

  /// BLE scan running, looking for devices.
  scanning,

  /// GATT connect in progress.
  connecting,

  /// Connected at GATT level; services being discovered.
  discovering,

  /// Connected, privacy PIN required before data exchange.
  pinRequired,

  /// Fully authenticated and ready.
  connected,

  /// An error occurred; see [KestrelDevice.errorMessage].
  error,
}

// ──────────────────────────────────────────────────────────────────────────────
// KestrelDevice
// ──────────────────────────────────────────────────────────────────────────────

class KestrelDevice {
  /// BLE device name (may be null if advertisement had no name).
  final String name;

  /// MAC address (Android) or UUID (iOS).
  final String address;

  /// Human-readable type string from the scan record's model code lookup.
  /// e.g. "5700", "2700", "ELITE".
  final String deviceType;

  final KestrelConnectionState state;

  // Fields populated after connection + characteristic reads:
  final String? modelName;
  final String? serialNumber;
  final String? firmwareVersion;
  final String? hardwareVersion;

  final String? errorMessage;

  const KestrelDevice({
    required this.name,
    required this.address,
    required this.deviceType,
    this.state = KestrelConnectionState.disconnected,
    this.modelName,
    this.serialNumber,
    this.firmwareVersion,
    this.hardwareVersion,
    this.errorMessage,
  });

  /// Returns a copy with the specified fields overridden.
  KestrelDevice copyWith({
    String? name,
    String? address,
    String? deviceType,
    KestrelConnectionState? state,
    String? modelName,
    String? serialNumber,
    String? firmwareVersion,
    String? hardwareVersion,
    String? errorMessage,
  }) {
    return KestrelDevice(
      name: name ?? this.name,
      address: address ?? this.address,
      deviceType: deviceType ?? this.deviceType,
      state: state ?? this.state,
      modelName: modelName ?? this.modelName,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'KestrelDevice(name: $name, address: $address, type: $deviceType, '
      'state: $state)';
}
