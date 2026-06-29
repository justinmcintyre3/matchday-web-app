// Kestrel BLE scan screen.
//
// Opened when the user taps "Ballistics Device" in the Add Device sheet.
// Shows a filtered list of nearby Kestrel devices only.
// On tap → connects; shows inline progress then navigates to detail screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/kestrel_device.dart';
import '../providers/kestrel_provider.dart';
import 'kestrel_detail_screen.dart';

class KestrelScanScreen extends StatefulWidget {
  const KestrelScanScreen({super.key});

  @override
  State<KestrelScanScreen> createState() => _KestrelScanScreenState();
}

class _KestrelScanScreenState extends State<KestrelScanScreen> {
  @override
  void initState() {
    super.initState();
    // Start scan as soon as the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KestrelProvider>().startScan();
    });
  }

  @override
  void dispose() {
    // Stop scan if user backs out without connecting
    context.read<KestrelProvider>().stopScan();
    super.dispose();
  }

  Future<void> _onDeviceTapped(
      BuildContext context, KestrelDevice device) async {
    HapticFeedback.mediumImpact();
    final provider = context.read<KestrelProvider>();
    await provider.connect(device);

    if (!context.mounted) return;

    // Navigate to detail screen — it will show connecting/connected/pinRequired
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const KestrelDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KestrelProvider>();
    final devices = provider.scannedDevices;
    final isScanning = provider.isScanning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Ballistics Device'),
        actions: [
          if (isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Color(0xFF007AFF),
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.startScan();
              },
              child: const Text(
                'Scan',
                style: TextStyle(color: Color(0xFF007AFF)),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Scanning indicator bar ─────────────────────────────────────
          if (isScanning)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF1E1E24),
              color: Color(0xFF007AFF),
              minHeight: 2,
            ),

          // ── Section header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
            child: Text(
              isScanning
                  ? 'SEARCHING FOR KESTREL DEVICES...'
                  : devices.isEmpty
                      ? 'NO DEVICES FOUND'
                      : 'NEARBY KESTREL DEVICES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),

          // ── Device list ────────────────────────────────────────────────
          if (devices.isEmpty && !isScanning) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    size: 52,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Kestrel devices found.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Make sure your Kestrel is powered on\nand nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: devices.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 56,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, i) {
                  final device = devices[i];
                  return _KestrelDeviceTile(
                    device: device,
                    onTap: () => _onDeviceTapped(context, device),
                  );
                },
              ),
            ),

          // ── Bottom hint ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Text(
              'Only Kestrel ballistics devices are shown.\n'
              'Ensure your device is powered on and within range.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Device tile widget
// ──────────────────────────────────────────────────────────────────────────────

class _KestrelDeviceTile extends StatelessWidget {
  final KestrelDevice device;
  final VoidCallback onTap;

  const _KestrelDeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.bluetooth,
            color: Color(0xFF007AFF),
            size: 20,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Kestrel ${device.deviceType} · ${device.address}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white38,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
