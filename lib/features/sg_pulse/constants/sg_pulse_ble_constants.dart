// SG Pulse BLE protocol constants.
//
// Service UUID and characteristic UUIDs sourced from the decompiled
// udtech.drills APK (C4818a.java / p381Ol package), confirmed against
// live HCI capture (btsnoop_hci.log).
//
// Filter strategy:
//   OS-level scan filter by [sgPulseServiceUuid] — only SG Pulse devices
//   advertising this service UUID will appear.

// ──────────────────────────────────────────────────────────────────────────────
// GATT Service UUID
// ──────────────────────────────────────────────────────────────────────────────

/// Primary custom service UUID for all SG Pulse / Shooters Global devices.
const String sgPulseServiceUuid = '9f59ffff-acdf-4eb0-8558-984ffb0a46d4';

// ──────────────────────────────────────────────────────────────────────────────
// Streaming Characteristics (device → phone, NOTIFY)
// ──────────────────────────────────────────────────────────────────────────────

/// IMU pulse stream — fires at ~50–100 Hz with roll/pitch/yaw/stability data.
/// Each notification delivers a [PulseSnapshot].
const String sgPulseCharPulseStream = '9f590000-acdf-4eb0-8558-984ffb0a46d4';

/// Shot event stream — fires when the device detects a trigger pull.
const String sgPulseCharShotEvent = '9f590006-acdf-4eb0-8558-984ffb0a46d4';

// ──────────────────────────────────────────────────────────────────────────────
// Control Characteristics (phone → device, WRITE)
// ──────────────────────────────────────────────────────────────────────────────

/// General command / control point characteristic.
const String sgPulseCharControl = '9f590002-acdf-4eb0-8558-984ffb0a46d4';

/// Horizontal sensitivity configuration.
const String sgPulseCharHorizSensitivity = '9f590003-acdf-4eb0-8558-984ffb0a46d4';

/// Stability green zone threshold.
const String sgPulseCharGreenZone = '9f590004-acdf-4eb0-8558-984ffb0a46d4';

/// Stability yellow zone threshold.
const String sgPulseCharYellowZone = '9f590005-acdf-4eb0-8558-984ffb0a46d4';

/// Shot sensitivity threshold.
const String sgPulseCharShotSensitivity = '9f590007-acdf-4eb0-8558-984ffb0a46d4';

// ──────────────────────────────────────────────────────────────────────────────
// Standard Device Info Characteristics (Bluetooth SIG)
// ──────────────────────────────────────────────────────────────────────────────

const String sgPulseCharModelNumber  = '00002a24-0000-1000-8000-00805f9b34fb';
const String sgPulseCharSerialNumber = '00002a25-0000-1000-8000-00805f9b34fb';
const String sgPulseCharFirmwareRev  = '00002a26-0000-1000-8000-00805f9b34fb';
const String sgPulseCharHardwareRev  = '00002a27-0000-1000-8000-00805f9b34fb';
const String sgPulseCharBattery      = '00002a19-0000-1000-8000-00805f9b34fb';

// ──────────────────────────────────────────────────────────────────────────────
// Protocol / timing constants
// ──────────────────────────────────────────────────────────────────────────────

/// How long to scan before auto-stopping.
const Duration sgPulseScanTimeout = Duration(seconds: 30);

/// Delay after GATT connect before calling discoverServices.
const Duration sgPulseServiceDiscoveryDelay = Duration(milliseconds: 600);
