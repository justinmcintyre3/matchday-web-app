// Detail screen for a connected (or saved) SG Pulse device.
//
// Shows live roll/pitch/yaw gauges, stability indicator, and shot count.
// If disconnected: shows a "Waiting to reconnect" card with a manual
// Connect button and a Forget Device option.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/sg_pulse_device.dart';
import '../models/pulse_snapshot.dart';
import '../providers/sg_pulse_provider.dart';

class SgPulseDetailScreen extends StatelessWidget {
  const SgPulseDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SgPulseProvider>();
    final device = provider.connectedDevice;
    final state = provider.connectionState;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: Text(device?.name ?? 'SG Pulse'),
        actions: [
          if (device != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF1E1E24),
              onSelected: (value) async {
                if (value == 'forget') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Forget Device'),
                      content: const Text(
                        'This will disconnect and remove the SG Pulse. '
                        'You will need to scan and pair again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Forget',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<SgPulseProvider>().forgetDevice();
                    if (context.mounted) Navigator.of(context).pop();
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'forget',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Forget Device',
                          style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Status header card ───────────────────────────────────────────
          _StatusCard(device: device, state: state),
          const SizedBox(height: 16),

          // ── State-specific content ───────────────────────────────────────
          if (state == SgPulseConnectionState.connecting ||
              state == SgPulseConnectionState.discovering)
            _ConnectingCard(state: state)
          else if (state == SgPulseConnectionState.connected)
            _LiveDataSection(provider: provider)
          else
            _DisconnectedCard(device: device, provider: provider),
        ],
      ),
    );
  }
}

// ── Status header card ────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final SgPulseDevice? device;
  final SgPulseConnectionState state;
  const _StatusCard({required this.device, required this.state});

  @override
  Widget build(BuildContext context) {
    final isConnected = state == SgPulseConnectionState.connected;
    final color = isConnected ? const Color(0xFF00E676) : Colors.white24;
    final label = switch (state) {
      SgPulseConnectionState.connected    => 'Connected',
      SgPulseConnectionState.connecting   => 'Connecting…',
      SgPulseConnectionState.discovering  => 'Discovering…',
      SgPulseConnectionState.error        => 'Error',
      _                                    => 'Disconnected',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sensors_rounded,
              color: Color(0xFF007AFF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device?.name ?? 'SG Pulse',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isConnected
                            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isConnected ? color : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connecting card ───────────────────────────────────────────────────────────

class _ConnectingCard extends StatelessWidget {
  final SgPulseConnectionState state;
  const _ConnectingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final label = state == SgPulseConnectionState.connecting
        ? 'Connecting…'
        : 'Discovering services…';
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
              color: Color(0xFF007AFF), strokeWidth: 2.5),
          const SizedBox(height: 20),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }
}

// ── Disconnected card ─────────────────────────────────────────────────────────

class _DisconnectedCard extends StatelessWidget {
  final SgPulseDevice? device;
  final SgPulseProvider provider;
  const _DisconnectedCard({required this.device, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.sensors_off_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 36),
          const SizedBox(height: 12),
          Text(
            'Waiting for device to come in range…\nThe app will automatically reconnect.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                if (device != null) {
                  provider.connect(device!, autoConnect: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Connect Now',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live data section ─────────────────────────────────────────────────────────

class _LiveDataSection extends StatelessWidget {
  final SgPulseProvider provider;
  const _LiveDataSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final snapshot = provider.latestSnapshot;
    final shotCount = provider.shotCount;

    return Column(
      children: [
        // Shot counter
        _ShotCountCard(shotCount: shotCount, provider: provider),
        const SizedBox(height: 12),

        // IMU gauges
        _ImuGaugesCard(snapshot: snapshot),
      ],
    );
  }
}

// ── Shot count card ───────────────────────────────────────────────────────────

class _ShotCountCard extends StatelessWidget {
  final int shotCount;
  final SgPulseProvider provider;
  const _ShotCountCard({required this.shotCount, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isFlashing = provider.isShotFlashing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isFlashing
            ? const Color(0xFF00E676).withValues(alpha: 0.12)
            : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFlashing ? const Color(0xFF00E676) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.gps_fixed_rounded,
                color: Color(0xFF00E676), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shots This Session',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '$shotCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.clearSession();
            },
            child: Text(
              'Reset',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── IMU gauges card ───────────────────────────────────────────────────────────

class _ImuGaugesCard extends StatelessWidget {
  final PulseSnapshot? snapshot;
  const _ImuGaugesCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('IMU Orientation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _AxisGauge(label: 'Roll',  value: snapshot?.roll  ?? 0)),
              const SizedBox(width: 10),
              Expanded(child: _AxisGauge(label: 'Pitch', value: snapshot?.pitch ?? 0)),
              const SizedBox(width: 10),
              Expanded(child: _AxisGauge(label: 'Yaw',   value: snapshot?.yaw   ?? 0)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisGauge extends StatelessWidget {
  final String label;
  final double value;
  const _AxisGauge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Normalize -180..180 to 0..1 for progress display
    final normalized = ((value + 180) / 360).clamp(0.0, 1.0);
    final color = const Color(0xFF007AFF);

    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _ArcPainter(value: normalized, color: color),
            child: Center(
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;
  _ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    const startAngle = math.pi * 0.75;
    const sweepFull  = math.pi * 1.5;

    canvas.drawArc(
      rect,
      startAngle,
      sweepFull,
      false,
      Paint()
        ..color = Colors.white10
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      rect,
      startAngle,
      sweepFull * value,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}


