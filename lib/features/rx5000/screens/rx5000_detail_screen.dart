import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rx5000_device.dart';
import '../providers/rx5000_provider.dart';

class Rx5000DetailScreen extends StatefulWidget {
  const Rx5000DetailScreen({super.key});

  @override
  State<Rx5000DetailScreen> createState() => _Rx5000DetailScreenState();
}

class _Rx5000DetailScreenState extends State<Rx5000DetailScreen> {
  late Rx5000Provider _rxProvider;

  @override
  void initState() {
    super.initState();
    _rxProvider = context.read<Rx5000Provider>();
    _rxProvider.incrementActivePages();
  }

  @override
  void dispose() {
    _rxProvider.decrementActivePages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Rx5000Provider>();
    final device = provider.connectedDevice;
    final state = provider.connectionState;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: const Text('Leupold RX5000'),
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
                        'This will disconnect and remove the RX5000 rangefinder. '
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
                    await context.read<Rx5000Provider>().forgetDevice();
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
                      Text('Forget Device', style: TextStyle(color: Colors.redAccent)),
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
          _StatusCard(device: device, state: state),
          const SizedBox(height: 16),

          if (state == Rx5000ConnectionState.connecting ||
              state == Rx5000ConnectionState.discovering)
            _ConnectingCard(state: state)
          else if (state == Rx5000ConnectionState.connected) ...[
            _MeasurementCard(device: device!, provider: provider),
            const SizedBox(height: 16),
            _DeviceSettingsCard(device: device, provider: provider),
            const SizedBox(height: 16),
            _CompassCalCard(device: device, provider: provider),
          ] else
            _DisconnectedCard(device: device, provider: provider),

          if (device != null) ...[
            const SizedBox(height: 16),
            _BatteryThresholdCard(provider: provider),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Status Card
// ──────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final Rx5000Device? device;
  final Rx5000ConnectionState state;
  const _StatusCard({required this.device, required this.state});

  @override
  Widget build(BuildContext context) {
    final isConnected = state == Rx5000ConnectionState.connected;
    final color = isConnected ? const Color(0xFF00E676) : Colors.white24;
    final label = switch (state) {
      Rx5000ConnectionState.connected => 'Connected',
      Rx5000ConnectionState.connecting => 'Connecting…',
      Rx5000ConnectionState.discovering => 'Syncing…',
      _ => 'Disconnected',
    };

    final iconBg = isConnected
        ? const Color(0xFF00E676).withValues(alpha: 0.12)
        : const Color(0xFF007AFF).withValues(alpha: 0.12);

    final iconColor = isConnected
        ? const Color(0xFF00E676)
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
              Icons.radar,
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
                  device?.name ?? 'Leupold RX5000',
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

// ──────────────────────────────────────────────────────────────────────────────
// Connecting Card
// ──────────────────────────────────────────────────────────────────────────────

class _ConnectingCard extends StatelessWidget {
  final Rx5000ConnectionState state;
  const _ConnectingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final label = state == Rx5000ConnectionState.connecting
        ? 'Connecting to rangefinder…'
        : 'Securing connection & syncing data…';
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF007AFF), strokeWidth: 2.5),
          const SizedBox(height: 20),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Disconnected Card
// ──────────────────────────────────────────────────────────────────────────────

class _DisconnectedCard extends StatelessWidget {
  final Rx5000Device? device;
  final Rx5000Provider provider;
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
          Icon(Icons.portable_wifi_off, color: Colors.white.withValues(alpha: 0.3), size: 36),
          const SizedBox(height: 12),
          Text(
            'Waiting for rangefinder to come in range…\nPress the power button to turn it on.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.4,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Connect Now', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Measurement Card (Live Sensor Readings)
// ──────────────────────────────────────────────────────────────────────────────

class _MeasurementCard extends StatelessWidget {
  final Rx5000Device device;
  final Rx5000Provider provider;
  const _MeasurementCard({required this.device, required this.provider});

  @override
  Widget build(BuildContext context) {
    final unit = device.measurementUnit == Rx5000MeasurementUnit.yards ? 'yd' : 'm';
    final hasRange = device.lastRange != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Ranging Measurements',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (device.tempCelsius != null)
                Text(
                  '${((device.tempCelsius! * 9 / 5) + 32).toStringAsFixed(1)}°F',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0A84FF), fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 18),

          _buildMeasureItem(
            'Line of Sight',
            hasRange ? '${device.lastRange!.toStringAsFixed(1)} $unit' : '--',
            Icons.straighten,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMeasureItem(
                  'Inclination',
                  device.lastInclination != null ? '${device.lastInclination}°' : '--',
                  Icons.navigation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMeasureItem(
                  'Heading',
                  device.lastHeading != null ? '${device.lastHeading!.toStringAsFixed(0)}°' : '--',
                  Icons.explore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                provider.triggerTestFire();
              },
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: const Text('Test Fire Rangefinder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF007AFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF007AFF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Device Settings Configuration Card
// ──────────────────────────────────────────────────────────────────────────────

class _DeviceSettingsCard extends StatelessWidget {
  final Rx5000Device device;
  final Rx5000Provider provider;
  const _DeviceSettingsCard({required this.device, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'DEVICE CONFIGURATION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38),
            ),
          ),

          // Output Mode Selector
          _buildDropdownTile(
            title: 'Output Mode',
            value: device.outputMode.name.toUpperCase(),
            icon: Icons.tune_rounded,
            onTap: () => _showSelectionDialog(
              context,
              'Output Mode',
              Rx5000OutputMode.values.map((v) => v.name.toUpperCase()).toList(),
              device.outputMode.index,
              (idx) => provider.setOutputMode(Rx5000OutputMode.values[idx]),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Display Brightness Selector
          _buildDropdownTile(
            title: 'Display Brightness',
            value: device.displayBrightness.name.toUpperCase(),
            icon: Icons.brightness_medium_rounded,
            onTap: () => _showSelectionDialog(
              context,
              'Display Brightness',
              Rx5000DisplayBrightness.values.map((v) => v.name.toUpperCase()).toList(),
              device.displayBrightness.index,
              (idx) => provider.setDisplayBrightness(Rx5000DisplayBrightness.values[idx]),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Reticle Type Selector
          _buildDropdownTile(
            title: 'Reticle Type',
            value: switch (device.reticleType) {
              Rx5000ReticleType.plusPoint => 'PLUS POINT',
              Rx5000ReticleType.duplexWithPlusPoint => 'DUPLEX WITH PLUS POINT',
              Rx5000ReticleType.duplex => 'DUPLEX',
            },
            icon: Icons.filter_center_focus_rounded,
            onTap: () => _showSelectionDialog(
              context,
              'Reticle Type',
              ['PLUS POINT', 'DUPLEX WITH PLUS POINT', 'DUPLEX'],
              device.reticleType.index,
              (idx) => provider.setReticleType(Rx5000ReticleType.values[idx]),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Measurement Unit Selector
          _buildDropdownTile(
            title: 'Measurement Unit',
            value: device.measurementUnit.name.toUpperCase(),
            icon: Icons.scale_rounded,
            onTap: () => _showSelectionDialog(
              context,
              'Measurement Unit',
              Rx5000MeasurementUnit.values.map((v) => v.name.toUpperCase()).toList(),
              device.measurementUnit.index,
              (idx) => provider.setMeasurementUnit(Rx5000MeasurementUnit.values[idx]),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Bluetooth Timeout Selector
          _buildDropdownTile(
            title: 'Bluetooth Timeout',
            value: '${device.bleIdlePowerOffSeconds}S',
            icon: Icons.bluetooth_searching_rounded,
            onTap: () => _showSelectionDialog(
              context,
              'Bluetooth Timeout',
              ['30S', '60S', '120S', '240S'],
              switch (device.bleIdlePowerOffSeconds) {
                30 => 0,
                60 => 1,
                120 => 2,
                240 => 3,
                _ => 0,
              },
              (idx) {
                final secs = [30, 60, 120, 240][idx];
                provider.setBleIdlePowerOffSeconds(secs);
              },
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Last Target Switch
          _buildSwitchTile(
            title: 'Last Target Priority',
            value: device.lastTarget,
            icon: Icons.track_changes_rounded,
            onChanged: (val) => provider.setLastTarget(val),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Include Heading Switch
          _buildSwitchTile(
            title: 'Include Heading (Pin Mode)',
            value: device.inPinMode ?? false,
            icon: Icons.explore_rounded,
            onChanged: (val) => provider.setInPinMode(val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.white)),
      trailing: Switch(
        value: value,
        onChanged: (val) {
          HapticFeedback.lightImpact();
          onChanged(val);
        },
        activeColor: const Color(0xFF007AFF),
        activeTrackColor: const Color(0xFF007AFF).withValues(alpha: 0.2),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.white10,
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showSelectionDialog(
    BuildContext context,
    String title,
    List<String> options,
    int selectedIdx,
    Function(int) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('SELECT $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = idx == selectedIdx;
            return ListTile(
              title: Text(option, style: TextStyle(color: isSelected ? const Color(0xFF007AFF) : Colors.white)),
              trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF007AFF)) : null,
              onTap: () {
                HapticFeedback.lightImpact();
                onSelected(idx);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Compass Calibration Card
// ──────────────────────────────────────────────────────────────────────────────

class _CompassCalCard extends StatefulWidget {
  final Rx5000Device device;
  final Rx5000Provider provider;
  const _CompassCalCard({required this.device, required this.provider});

  @override
  State<_CompassCalCard> createState() => _CompassCalCardState();
}

class _CompassCalCardState extends State<_CompassCalCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.device.isCompassCalibrating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _CompassCalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.isCompassCalibrating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.device.isCompassCalibrating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getQualityLabel(int level) {
    if (level <= 0) return 'None';
    const labels = ['None', 'Least', 'Poor', 'Low', 'OK', 'Good', 'Best'];
    if (level < labels.length) {
      return labels[level];
    }
    return 'Best';
  }

  @override
  Widget build(BuildContext context) {
    final calibrating = widget.device.isCompassCalibrating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'COMPASS CALIBRATION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38),
            ),
          ),

          Row(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateY(calibrating ? _controller.value * 2 * 3.14159265 : 0)
                      ..rotateZ(calibrating ? _controller.value * 2 * 3.14159265 : 0),
                    alignment: Alignment.center,
                    child: child,
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.explore_rounded, color: Colors.white70, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calibration Status',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      calibrating
                          ? 'Tumble Device (Quality: ${_getQualityLabel(widget.device.compassCalQuality)})'
                          : (widget.device.compassCalStatus ?? 'Not Calibrated'),
                      style: TextStyle(
                        fontSize: 12,
                        color: calibrating ? const Color(0xFFFFD60A) : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              if (calibrating) ...[
                Text(
                  '${widget.device.compassCalPercentage}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD60A),
                  ),
                ),
                const SizedBox(width: 10),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFD60A),
                  ),
                ),
              ],
            ],
          ),
          
          if (calibrating) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: widget.device.compassCalPercentage / 100,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD60A)),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              if (calibrating)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.provider.abortCompassCalibration();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF5252)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Abort Calibration', style: TextStyle(color: Color(0xFFFF5252))),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.provider.startCompassCalibration();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Start Calibration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
class _BatteryThresholdCard extends StatelessWidget {
  final Rx5000Provider provider;
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
                'When the Leupold RX5000 battery level falls below this percentage, you will be prompted to swap batteries.',
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
