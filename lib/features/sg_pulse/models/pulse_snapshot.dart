// Data model for a single IMU measurement frame received from the SG Pulse.
//
// The SG Pulse streams [PulseSnapshot] notifications at ~50–100 Hz via the
// pulse stream GATT characteristic. Each notification encodes:
//
//   Offset  Size  Type    Field
//   0       8     float64 roll      (degrees)
//   8       8     float64 pitch     (degrees)
//   16      8     float64 yaw       (degrees)
//   24      8     float64 stability (0.0 – 1.0)
//   32      1     bool    isShoot   (1 = shot detected)
//   33      8     float64 stabilityX
//   41      8     float64 stabilityY
//   (total ~49 bytes)
//
// Note: Encoding confirmed from the decompiled PulseSnapshot.java constructor.
// If the wire format differs (e.g., float32 instead of float64), adjust the
// byte strides in [fromBytes] accordingly after a live test.

import 'dart:typed_data';

class PulseSnapshot {
  final double roll;
  final double pitch;
  final double yaw;
  final double stability;

  /// True when the device detects a trigger pull in this frame.
  final bool isShoot;

  /// 2D stability cursor coordinates [x, y].
  final double stabilityX;
  final double stabilityY;

  const PulseSnapshot({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.stability,
    required this.isShoot,
    required this.stabilityX,
    required this.stabilityY,
  });

  // ── Wire format parser ────────────────────────────────────────────────────

  /// Parse a raw BLE notification payload into a [PulseSnapshot].
  ///
  /// Returns null if [bytes] is too short or malformed.
  static PulseSnapshot? fromBytes(List<int> bytes) {
    if (bytes.length < 14) return null;

    try {
      final bd = ByteData.sublistView(Uint8List.fromList(bytes));

      // SG Pulse 14-byte format:
      // Byte 0: sequence number
      // Byte 1: 0x55 (magic/flags)
      // Bytes 2-5: Yaw (Int32 LE, thousandths of a degree)
      // Bytes 6-9: Pitch (Int32 LE, thousandths of a degree)
      // Bytes 10-13: Roll (Int32 LE, thousandths of a degree)
      
      if (bytes.length == 14) {
        return PulseSnapshot(
          roll:        bd.getInt32(10, Endian.little) / 1000.0,
          pitch:       bd.getInt32(6,  Endian.little) / 1000.0,
          yaw:         bd.getInt32(2,  Endian.little) / 1000.0,
          stability:   1.0, // Calculated locally by Drills app; defaulting to 1.0 for now
          isShoot:     false, // Handled by separate characteristic
          stabilityX:  0.0,
          stabilityY:  0.0,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  /// Clamp stability to [0, 1] in case of floating-point imprecision.
  double get stabilityNormalized => stability.clamp(0.0, 1.0);

  @override
  String toString() =>
      'PulseSnapshot(roll: ${roll.toStringAsFixed(1)}, '
      'pitch: ${pitch.toStringAsFixed(1)}, '
      'yaw: ${yaw.toStringAsFixed(1)}, '
      'stability: ${stability.toStringAsFixed(2)}, '
      'isShoot: $isShoot)';
}
