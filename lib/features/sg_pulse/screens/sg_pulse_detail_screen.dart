// Detail screen for a connected (or saved) SG Pulse device.
//
// Shows live roll/pitch/yaw gauges, stability indicator, and shot count.
// If disconnected: shows a "Waiting to reconnect" card with a manual
// Connect button and a Forget Device option.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/sg_pulse_device.dart';
import '../models/pulse_snapshot.dart';
import '../providers/sg_pulse_provider.dart';

class SgPulseDetailScreen extends StatefulWidget {
  const SgPulseDetailScreen({super.key});

  @override
  State<SgPulseDetailScreen> createState() => _SgPulseDetailScreenState();
}

class _SgPulseDetailScreenState extends State<SgPulseDetailScreen> {
  int _localShotCount = 0;
  StreamSubscription<void>? _localShotSubscription;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SgPulseProvider>();
    provider.latestSnapshot = null;
    _localShotSubscription = provider.shotDetectedStream.listen((_) {
      if (mounted) {
        setState(() {
          _localShotCount++;
        });
      }
    });
  }

  @override
  void dispose() {
    _localShotSubscription?.cancel();
    context.read<SgPulseProvider>().latestSnapshot = null;
    super.dispose();
  }

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
            _LiveDataSection(
              provider: provider,
              shotCount: _localShotCount,
              onResetShotCount: () {
                setState(() {
                  _localShotCount = 0;
                });
              },
            )
          else
            _DisconnectedCard(device: device, provider: provider),

          const SizedBox(height: 16),
          _RollThresholdCard(provider: provider),

          const SizedBox(height: 16),
          _BatteryThresholdCard(provider: provider),

          const SizedBox(height: 16),
          _StabilityZonesCard(provider: provider),
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
    final isError = state == SgPulseConnectionState.error;
    final color = isConnected ? const Color(0xFF00E676) : Colors.white24;
    final label = switch (state) {
      SgPulseConnectionState.connected    => 'Connected',
      SgPulseConnectionState.connecting   => 'Connecting…',
      SgPulseConnectionState.discovering  => 'Discovering…',
      SgPulseConnectionState.error        => 'Error',
      _                                    => 'Disconnected',
    };

    final iconBg = isConnected 
        ? const Color(0xFF00E676).withValues(alpha: 0.12)
        : isError 
            ? const Color(0xFFFF5252).withValues(alpha: 0.12)
            : const Color(0xFF007AFF).withValues(alpha: 0.12);
            
    final iconColor = isConnected
        ? const Color(0xFF00E676)
        : isError
            ? const Color(0xFFFF5252)
            : const Color(0xFF007AFF);

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
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.sensors,
              color: iconColor,
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
                      isConnected && device?.batteryLevel != null
                          ? '$label • ${device!.batteryLevel}% Battery'
                          : label,
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
          Icon(Icons.sensors_off,
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
  final int shotCount;
  final VoidCallback onResetShotCount;

  const _LiveDataSection({
    required this.provider,
    required this.shotCount,
    required this.onResetShotCount,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = provider.latestSnapshot;

    return Column(
      children: [
        // Shot counter
        _ShotCountCard(
          shotCount: shotCount,
          provider: provider,
          onReset: onResetShotCount,
        ),
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
  final VoidCallback onReset;

  const _ShotCountCard({
    required this.shotCount,
    required this.provider,
    required this.onReset,
  });

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
              onReset();
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
    
    // Truncate to 1 decimal place without rounding
    final sign = value < 0 ? -1.0 : 1.0;
    final truncatedValue = sign * ((value.abs() * 10).floor() / 10.0);
    
    Color color = const Color(0xFF007AFF);
    if (label == 'Roll') {
      final provider = context.read<SgPulseProvider>();
      final threshold = provider.rollThreshold;
      if (truncatedValue.abs() <= threshold) {
        color = const Color(0xFF30D158); // green
      } else {
        color = truncatedValue < 0
            ? const Color(0xFFFF453A) // red (canted left)
            : const Color(0xFF0A84FF); // blue (canted right)
      }
    }

    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _ArcPainter(value: normalized, color: color),
            child: Center(
              child: Text(
                label == 'Roll' ? truncatedValue.toStringAsFixed(1) : value.toStringAsFixed(1),
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

class _RollThresholdCard extends StatelessWidget {
  final SgPulseProvider provider;
  const _RollThresholdCard({required this.provider});

  void _showConfigureDialog(BuildContext context) {
    double tempVal = provider.rollThreshold;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CONFIGURE ROLL THRESHOLD'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Values within ±Threshold degrees are considered acceptable firearm cant and will display as green. Exceeding this threshold will display as red (canted left) or blue (canted right).',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: '${provider.rollThreshold}',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    tempVal = parsed;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Threshold in Degrees (e.g. 0.3)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.setRollThreshold(tempVal);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showConfigureDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Roll Threshold (Cant Limit)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Acceptable deviation limit: ±${provider.rollThreshold}°',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StabilityZonesCard extends StatelessWidget {
  final SgPulseProvider provider;
  const _StabilityZonesCard({required this.provider});

  void _showConfigureDialog(BuildContext context) {
    double tempGreen = provider.stabilityGreenZone;
    double tempYellow = provider.stabilityYellowZone;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CONFIGURE STABILITY ZONES'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Values at or below Green Zone are green (excellent stability). Values between Green Zone and Yellow Zone are yellow (acceptable stability). Anything above Yellow Zone is red (poor stability).',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: '${provider.stabilityGreenZone}',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Green Zone limit (e.g. 1.0)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    tempGreen = parsed;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '${provider.stabilityYellowZone}',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Yellow Zone limit (e.g. 5.0)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    tempYellow = parsed;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.setStabilityGreenZone(tempGreen);
                provider.setStabilityYellowZone(tempYellow);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double liveStability = provider.latestSnapshot?.stability ?? 0.0;
    Color liveStabilityColor;
    if (liveStability <= provider.stabilityGreenZone) {
      liveStabilityColor = const Color(0xFF30D158); // green
    } else if (liveStability <= provider.stabilityYellowZone) {
      liveStabilityColor = const Color(0xFFFFD60A); // yellow
    } else {
      liveStabilityColor = const Color(0xFFFF453A); // red
    }

    return Card(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showConfigureDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights, color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stability Zones Configuration',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Green: ≤ ${provider.stabilityGreenZone} | Yellow: ≤ ${provider.stabilityYellowZone}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (provider.connectionState == SgPulseConnectionState.connected) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Live Stability: ',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            '${liveStability.toStringAsFixed(1)} MOA',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: liveStabilityColor),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryThresholdCard extends StatelessWidget {
  final SgPulseProvider provider;
  const _BatteryThresholdCard({required this.provider});

  void _showConfigureDialog(BuildContext context) {
    int tempVal = provider.batteryWarningThreshold;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CONFIGURE BATTERY THRESHOLD'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'When the SG Pulse battery level falls below this percentage, you will be prompted to charge it.',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: '${provider.batteryWarningThreshold}',
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && parsed >= 0 && parsed <= 100) {
                    tempVal = parsed;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Battery Warning Threshold (%)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.setBatteryWarningThreshold(tempVal);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showConfigureDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.battery_alert, color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Battery Alert Threshold',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prompt when battery is below ${provider.batteryWarningThreshold}%',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}


