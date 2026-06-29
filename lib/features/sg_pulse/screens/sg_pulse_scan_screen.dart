// Scan screen for discovering and connecting to SG Pulse devices.
//
// Launched from Settings → Add Device → IMU Device.
// Filters BLE scan to only show SG Pulse devices (9f59ffff service UUID).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/sg_pulse_device.dart';
import '../providers/sg_pulse_provider.dart';

class SgPulseScanScreen extends StatefulWidget {
  const SgPulseScanScreen({super.key});

  @override
  State<SgPulseScanScreen> createState() => _SgPulseScanScreenState();
}

class _SgPulseScanScreenState extends State<SgPulseScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SgPulseProvider>().startScan();
    });
  }

  @override
  void dispose() {
    // Stop scan if user backs out mid-scan
    context.read<SgPulseProvider>().stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SgPulseProvider>();
    final isScanning = provider.isScanning;
    final devices = provider.scannedDevices;
    final state = provider.connectionState;

    // Auto-navigate to detail screen once connected
    if (state == SgPulseConnectionState.connected ||
        state == SgPulseConnectionState.connecting ||
        state == SgPulseConnectionState.discovering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(); // Return to Settings, tile updates
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: const Text('Add IMU Device'),
        actions: [
          if (!isScanning)
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
        children: [
          // ── Scanning indicator ───────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isScanning ? 4 : 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        isScanning
                            ? 'SCANNING FOR SG PULSE...'
                            : 'NEARBY DEVICES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (isScanning) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Device list ───────────────────────────────────────────
                if (devices.isEmpty && isScanning)
                  _EmptyState(isScanning: isScanning)
                else if (devices.isEmpty)
                  _EmptyState(isScanning: false)
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: devices
                          .asMap()
                          .entries
                          .map((entry) => _DeviceTile(
                                device: entry.value,
                                isLast: entry.key == devices.length - 1,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isScanning;
  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_rounded,
              color: Color(0xFF007AFF),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Looking for devices…' : 'No devices found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isScanning
                ? 'Make sure your SG Pulse is powered on\nand in range.'
                : 'Tap Scan to try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device tile ───────────────────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  final SgPulseDevice device;
  final bool isLast;

  const _DeviceTile({required this.device, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SgPulseProvider>();
    final isConnecting =
        provider.connectionState == SgPulseConnectionState.connecting ||
        provider.connectionState == SgPulseConnectionState.discovering;

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sensors_rounded,
              color: Color(0xFF007AFF),
              size: 22,
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
            device.address,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          trailing: isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF007AFF),
                  ),
                )
              : const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                  size: 20,
                ),
          onTap: isConnecting
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  provider.connect(device);
                },
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 68,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}
