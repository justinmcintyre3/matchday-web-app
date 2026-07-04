import 'dart:convert';

// ──────────────────────────────────────────────────────────────────────────────
// Connection state enum
// ──────────────────────────────────────────────────────────────────────────────

enum Rx5000ConnectionState {
  disconnected,
  scanning,
  connecting,
  discovering,
  authenticating,
  pinRequired,
  connected,
  error,
}

// ──────────────────────────────────────────────────────────────────────────────
// Settings & Configuration Enums
// ──────────────────────────────────────────────────────────────────────────────

enum Rx5000OutputMode {
  los,
  tbr,
  long,
  bow,
}

enum Rx5000DisplayBrightness {
  night,
  low,
  medium,
  high,
}

enum Rx5000ReticleType {
  plusPoint,
  duplexWithPlusPoint,
  duplex,
}

enum Rx5000MeasurementUnit {
  yards,
  meters,
}

enum Rx5000TbrSubMode {
  moa,
  mil,
  cds,
  trig,
  elevation,
}

// ──────────────────────────────────────────────────────────────────────────────
// Rx5000Device Model
// ──────────────────────────────────────────────────────────────────────────────

class Rx5000Device {
  final String name;
  final String address;
  final Rx5000ConnectionState state;

  // Device Info
  final String? firmwareVersion;
  final String? hardwareVersion;
  final String? serialNumber;
  final String? uniqueId;
  final int? batteryLevel;
  final double? rssi;

  // Sensor Readings
  final double? tempCelsius;
  final double? lastRange;
  final double? lastTbrDistance;
  final double? lastVerticalDistance;
  final int? lastInclination;
  final double? lastHeading;
  final String? lastDistanceType;
  final double? lastWindage;
  final bool? inPinMode;
  final bool? isLaserActive;

  // Settings
  final Rx5000OutputMode outputMode;
  final Rx5000DisplayBrightness displayBrightness;
  final Rx5000ReticleType reticleType;
  final Rx5000MeasurementUnit measurementUnit;
  final Rx5000TbrSubMode tbrSubMode;
  final int tbrLoad; // 1 to 25
  final int bleIdlePowerOffSeconds; // 30, 60, 120, 240
  final int compassCalPercentage;
  final String? compassCalStatus;
  final int compassCalQuality;
  final bool isCompassCalibrating;
  final bool lastTarget;

  final String? errorMessage;

  const Rx5000Device({
    required this.name,
    required this.address,
    this.state = Rx5000ConnectionState.disconnected,
    this.firmwareVersion,
    this.hardwareVersion,
    this.serialNumber,
    this.uniqueId,
    this.batteryLevel,
    this.rssi,
    this.tempCelsius,
    this.lastRange,
    this.lastTbrDistance,
    this.lastVerticalDistance,
    this.lastInclination,
    this.lastHeading,
    this.lastDistanceType,
    this.lastWindage,
    this.inPinMode = false,
    this.isLaserActive = false,
    this.outputMode = Rx5000OutputMode.los,
    this.displayBrightness = Rx5000DisplayBrightness.high,
    this.reticleType = Rx5000ReticleType.plusPoint,
    this.measurementUnit = Rx5000MeasurementUnit.yards,
    this.tbrSubMode = Rx5000TbrSubMode.moa,
    this.tbrLoad = 16,
    this.bleIdlePowerOffSeconds = 30,
    this.compassCalPercentage = 0,
    this.compassCalStatus,
    this.compassCalQuality = 0,
    this.isCompassCalibrating = false,
    this.lastTarget = false,
    this.errorMessage,
  });

  // ── JSON serialization for SharedPreferences persistence ──────────────────

  factory Rx5000Device.fromJson(Map<String, dynamic> json) {
    return Rx5000Device(
      name: json['name'] as String? ?? 'RX5000',
      address: json['address'] as String? ?? '',
      state: Rx5000ConnectionState.disconnected,
      firmwareVersion: json['firmwareVersion'] as String?,
      hardwareVersion: json['hardwareVersion'] as String?,
      serialNumber: json['serialNumber'] as String?,
      uniqueId: json['uniqueId'] as String?,
      batteryLevel: json['batteryLevel'] as int?,
      outputMode: Rx5000OutputMode.values[json['outputMode'] as int? ?? 0],
      displayBrightness: Rx5000DisplayBrightness.values[json['displayBrightness'] as int? ?? 3],
      reticleType: Rx5000ReticleType.values[json['reticleType'] as int? ?? 0],
      measurementUnit: Rx5000MeasurementUnit.values[json['measurementUnit'] as int? ?? 0],
      tbrSubMode: Rx5000TbrSubMode.values[json['tbrSubMode'] as int? ?? 0],
      tbrLoad: json['tbrLoad'] as int? ?? 16,
      bleIdlePowerOffSeconds: json['bleIdlePowerOffSeconds'] as int? ?? 30,
      lastTarget: json['lastTarget'] as bool? ?? false,
      compassCalQuality: json['compassCalQuality'] as int? ?? 0,
      isCompassCalibrating: json['isCompassCalibrating'] as bool? ?? false,
    );
  }

  factory Rx5000Device.fromJsonString(String jsonStr) =>
      Rx5000Device.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'firmwareVersion': firmwareVersion,
        'hardwareVersion': hardwareVersion,
        'uniqueId': uniqueId,
        'serialNumber': serialNumber,
        'batteryLevel': batteryLevel,
        'outputMode': outputMode.index,
        'displayBrightness': displayBrightness.index,
        'reticleType': reticleType.index,
        'measurementUnit': measurementUnit.index,
        'tbrSubMode': tbrSubMode.index,
        'tbrLoad': tbrLoad,
        'bleIdlePowerOffSeconds': bleIdlePowerOffSeconds,
        'lastTarget': lastTarget,
        'compassCalQuality': compassCalQuality,
        'isCompassCalibrating': isCompassCalibrating,
      };

  String toJsonString() => jsonEncode(toJson());

  // ── copyWith ──────────────────────────────────────────────────────────────

  Rx5000Device copyWith({
    String? name,
    String? address,
    Rx5000ConnectionState? state,
    String? firmwareVersion,
    String? hardwareVersion,
    String? serialNumber,
    String? uniqueId,
    int? batteryLevel,
    double? rssi,
    double? tempCelsius,
    double? lastRange,
    double? lastTbrDistance,
    double? lastVerticalDistance,
    int? lastInclination,
    double? lastHeading,
    String? lastDistanceType,
    double? lastWindage,
    bool? inPinMode,
    bool? isLaserActive,
    Rx5000OutputMode? outputMode,
    Rx5000DisplayBrightness? displayBrightness,
    Rx5000ReticleType? reticleType,
    Rx5000MeasurementUnit? measurementUnit,
    Rx5000TbrSubMode? tbrSubMode,
    int? tbrLoad,
    int? bleIdlePowerOffSeconds,
    int? compassCalPercentage,
    String? compassCalStatus,
    int? compassCalQuality,
    bool? isCompassCalibrating,
    bool? lastTarget,
    bool clearHeading = false,
    String? errorMessage,
  }) {
    return Rx5000Device(
      name: name ?? this.name,
      address: address ?? this.address,
      state: state ?? this.state,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      uniqueId: uniqueId ?? this.uniqueId,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      tempCelsius: tempCelsius ?? this.tempCelsius,
      lastRange: lastRange ?? this.lastRange,
      lastTbrDistance: lastTbrDistance ?? this.lastTbrDistance,
      lastVerticalDistance: lastVerticalDistance ?? this.lastVerticalDistance,
      lastInclination: lastInclination ?? this.lastInclination,
      lastHeading: clearHeading ? null : (lastHeading ?? this.lastHeading),
      lastDistanceType: lastDistanceType ?? this.lastDistanceType,
      lastWindage: lastWindage ?? this.lastWindage,
      inPinMode: inPinMode ?? this.inPinMode,
      isLaserActive: isLaserActive ?? this.isLaserActive,
      outputMode: outputMode ?? this.outputMode,
      displayBrightness: displayBrightness ?? this.displayBrightness,
      reticleType: reticleType ?? this.reticleType,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      tbrSubMode: tbrSubMode ?? this.tbrSubMode,
      tbrLoad: tbrLoad ?? this.tbrLoad,
      bleIdlePowerOffSeconds: bleIdlePowerOffSeconds ?? this.bleIdlePowerOffSeconds,
      compassCalPercentage: compassCalPercentage ?? this.compassCalPercentage,
      compassCalStatus: compassCalStatus ?? this.compassCalStatus,
      compassCalQuality: compassCalQuality ?? this.compassCalQuality,
      isCompassCalibrating: isCompassCalibrating ?? this.isCompassCalibrating,
      lastTarget: lastTarget ?? this.lastTarget,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() => 'Rx5000Device(name: $name, address: $address, state: $state)';
}
