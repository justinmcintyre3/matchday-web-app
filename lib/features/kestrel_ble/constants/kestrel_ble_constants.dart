// Kestrel BLE protocol constants.
//
// UUIDs are sourced directly from the Kestrel LiNK app's [E.java] and
// confirmed against BLE traffic captures.
//
// Filter strategy (mirrors the reference app's v.java scanner):
//   1. OS-level ScanFilter by [kestrelServiceUuids] — only devices
//      advertising one of these four service UUIDs pass through.
//   2. Manufacturer ID [kestrelManufacturerId] (0xEA / 234) check — used
//      to read the 2-byte little-endian model code and resolve device type.

// ──────────────────────────────────────────────────────────────────────────────
// GATT Service UUIDs (one per Kestrel hardware variant)
// ──────────────────────────────────────────────────────────────────────────────

/// Kestrel 5700 / Elite series (primary target).
const String kestrelServiceUuidK5 = '03290000-eab4-dea1-b24e-44ec023874db';

/// Kestrel 2700 series.
const String kestrelServiceUuid2700 = 'fed00000-a679-43a4-8141-d08305614e45';

/// Kestrel HUD variant.
const String kestrelServiceUuidHud = '41540000-2053-5341-4d20-445548204b4e';

/// Kestrel KST variant.
const String kestrelServiceUuidKst = '79c30000-d911-4fef-bd38-1c8ad3750449';

/// All service UUIDs used for BLE scan filtering.
const List<String> kestrelServiceUuids = [
  kestrelServiceUuidK5,
  kestrelServiceUuid2700,
  kestrelServiceUuidHud,
  kestrelServiceUuidKst,
];

// ──────────────────────────────────────────────────────────────────────────────
// Custom NK RT-Serial GATT Characteristics
// ──────────────────────────────────────────────────────────────────────────────

/// Custom RT-Serial GATT service (shared across all variants).
const String kestrelCharRtService = '85920000-0338-4b83-ae4a-ac1d217adb03';

/// RX characteristic — data flows Kestrel → phone (INDICATE).
const String kestrelCharRxBuf = '85920100-0338-4b83-ae4a-ac1d217adb03';

/// TX characteristic — data flows phone → Kestrel (WRITE).
const String kestrelCharTxBuf = '85920200-0338-4b83-ae4a-ac1d217adb03';

// ──────────────────────────────────────────────────────────────────────────────
// Standard Device Info Characteristics (Bluetooth SIG)
// ──────────────────────────────────────────────────────────────────────────────

const String kestrelCharModelNumber  = '00002a24-0000-1000-8000-00805f9b34fb';
const String kestrelCharSerialNumber = '00002a25-0000-1000-8000-00805f9b34fb';
const String kestrelCharFirmwareRev  = '00002a26-0000-1000-8000-00805f9b34fb';
const String kestrelCharHardwareRev  = '00002a27-0000-1000-8000-00805f9b34fb';

// ──────────────────────────────────────────────────────────────────────────────
// Standard CCCD Descriptor (enables INDICATE/NOTIFY)
// ──────────────────────────────────────────────────────────────────────────────

const String kestrelCccd = '00002902-0000-1000-8000-00805f9b34fb';

// ──────────────────────────────────────────────────────────────────────────────
// Manufacturer filter
// ──────────────────────────────────────────────────────────────────────────────

/// NK manufacturer ID embedded in BLE advertisement (decimal 234 / hex 0xEA).
/// Used to validate that a device advertising a Kestrel service UUID is
/// genuinely an NK device and to read its model code.
const int kestrelManufacturerId = 234;

// ──────────────────────────────────────────────────────────────────────────────
// Protocol / timing
// ──────────────────────────────────────────────────────────────────────────────

/// Maximum BLE MTU payload per write (20 bytes, pre-negotiation default).
const int kestrelMaxPacketBytes = 20;

/// How long to scan before auto-stopping (matches reference app: 30 s).
const Duration kestrelScanTimeout = Duration(seconds: 30);

/// Delay after GATT connect before calling discoverServices (matches ref: 600 ms).
const Duration kestrelServiceDiscoveryDelay = Duration(milliseconds: 600);
