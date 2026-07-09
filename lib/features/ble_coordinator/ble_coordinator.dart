// BLE Connection Coordinator
//
// Ensures Kestrel (which requires a multi-step JNI handshake) completes its
// connection before other BLE devices (e.g. Rx5000) are allowed to attempt
// their own connections. This eliminates GATT radio contention which causes
// GATT_CONNECTION_TIMEOUT errors (error codes 133/147) on Android.
//
// Usage:
//   - Call [reset] when starting a Kestrel connection attempt.
//   - Call [signal] when Kestrel reaches [connected] or [error].
//   - Call [whenReady] from any other provider that wants to connect — the
//     callback fires immediately if Kestrel is already done, or is queued
//     until [signal] is called.
//
// No timers. No polling. Purely event-driven.

import 'package:flutter/foundation.dart';

class BleCoordinator {
  BleCoordinator._();
  static final BleCoordinator instance = BleCoordinator._();

  bool _kestrelReady = true; // Starts true so first Rx5000 connect isn't blocked
  final List<VoidCallback> _queue = [];

  /// Call before initiating a new Kestrel connection attempt.
  void reset() {
    debugPrint('[BleCoordinator] Reset — Kestrel handshake starting, queuing other devices.');
    _kestrelReady = false;
  }

  /// Call when Kestrel reaches [connected] or [error] — releases queued callbacks.
  void signal() {
    if (_kestrelReady) return; // Already signalled, nothing to do
    debugPrint('[BleCoordinator] Signal — Kestrel done. Releasing ${_queue.length} queued callback(s).');
    _kestrelReady = true;
    final pending = List<VoidCallback>.from(_queue);
    _queue.clear();
    for (final cb in pending) {
      cb();
    }
  }

  /// If Kestrel is ready, [callback] fires immediately.
  /// Otherwise it is queued until [signal] is called.
  void whenReady(VoidCallback callback) {
    if (_kestrelReady) {
      debugPrint('[BleCoordinator] Kestrel already ready — firing callback immediately.');
      callback();
    } else {
      debugPrint('[BleCoordinator] Kestrel not ready — queuing callback.');
      _queue.add(callback);
    }
  }

  /// Removes all queued callbacks without firing them (e.g. on app sleep).
  void cancelQueue() {
    debugPrint('[BleCoordinator] Cancelling ${_queue.length} queued callback(s).');
    _queue.clear();
  }
}
