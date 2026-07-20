import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../widgets/wind_clock_picker.dart';
import '../../../models/match.dart';
import '../models/kestrel_device.dart';
import '../providers/kestrel_provider.dart';
import '../../../providers/match_provider.dart';

class KestrelDetailScreen extends StatelessWidget {
  const KestrelDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KestrelProvider>();
    final device = provider.connectedDevice;
    final state = provider.connectionState;

    return Scaffold(
      appBar: AppBar(
        title: Text(device?.name ?? 'Kestrel'),
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
                        'This will disconnect and remove the Kestrel device. '
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
                    await context.read<KestrelProvider>().forgetDevice();
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          // ── Device header ───────────────────────────────────────────────
          _StatusCard(device: device, state: state),

          const SizedBox(height: 16),

          // ── State-specific content ──────────────────────────────────────
          _buildStateContent(context, state, device, provider),

          if (device != null) ...[
            const SizedBox(height: 16),
            _RangeCardGenerationCard(
              provider: provider,
              isConnected: state == KestrelConnectionState.connected,
            ),
            const SizedBox(height: 16),
            _BatteryThresholdCard(provider: provider),
            const SizedBox(height: 8),
            _BackgroundConnectionCard(provider: provider),
          ],
        ],
      ),
    );
  }

  Widget _buildStateContent(
    BuildContext context,
    KestrelConnectionState state,
    KestrelDevice? device,
    KestrelProvider provider,
  ) {
    switch (state) {
      case KestrelConnectionState.connecting:
      case KestrelConnectionState.discovering:
      case KestrelConnectionState.synchronizing:
        return _ConnectingCard(state: state);

      case KestrelConnectionState.pinRequired:
        return _PinEntryCard(provider: provider);

      case KestrelConnectionState.connected:
        return _ConnectedInfoCard(device: device);

      case KestrelConnectionState.error:
        return _ErrorCard(
          message: device?.errorMessage ?? 'An unexpected error occurred.',
          onRetry: () {
            if (device != null) {
              provider.connect(device, autoConnect: false);
            } else {
              provider.startScan();
            }
          },
        );

      case KestrelConnectionState.disconnected:
        return _DisconnectedCard(device: device, provider: provider);

      default:
        return const SizedBox.shrink();
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final KestrelDevice? device;
  final KestrelConnectionState state;
  const _StatusCard({required this.device, required this.state});

  @override
  Widget build(BuildContext context) {
    final isConnected = state == KestrelConnectionState.connected;
    final isError = state == KestrelConnectionState.error;
    final color = isConnected ? const Color(0xFF00E676) : Colors.white24;
    final label = switch (state) {
      KestrelConnectionState.connected    => 'Connected',
      KestrelConnectionState.connecting   => 'Connecting…',
      KestrelConnectionState.synchronizing => 'Synchronizing…',
      KestrelConnectionState.discovering  => 'Discovering…',
      KestrelConnectionState.error        => 'Error',
      KestrelConnectionState.pinRequired  => 'PIN Required',
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
              Icons.track_changes,
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
                  device?.name ?? 'Kestrel',
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

// ── Connecting / Discovering card ─────────────────────────────────────────────

class _ConnectingCard extends StatelessWidget {
  final KestrelConnectionState state;
  const _ConnectingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final label = state == KestrelConnectionState.connecting
        ? 'Connecting…'
        : state == KestrelConnectionState.synchronizing
            ? 'Synchronizing data…'
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
            color: Color(0xFF007AFF),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── PIN entry card ────────────────────────────────────────────────────────────

class _PinEntryCard extends StatefulWidget {
  final KestrelProvider provider;
  const _PinEntryCard({required this.provider});

  @override
  State<_PinEntryCard> createState() => _PinEntryCardState();
}

class _PinEntryCardState extends State<_PinEntryCard> {
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _rememberPin = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    
    await widget.provider.authenticateWithPin(pin, savePin: _rememberPin);
    
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PIN Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This Kestrel has privacy mode enabled.\nEnter the device PIN to continue.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 8,
            style: const TextStyle(color: Colors.white, letterSpacing: 4),
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                letterSpacing: 4,
              ),
              filled: true,
              fillColor: const Color(0xFF121214),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _rememberPin,
                activeColor: const Color(0xFF007AFF),
                onChanged: (val) {
                  setState(() {
                    _rememberPin = val ?? false;
                  });
                },
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _rememberPin = !_rememberPin;
                  });
                },
                child: Text(
                  'Remember PIN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Connect',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connected info card ───────────────────────────────────────────────────────

class _ConnectedInfoCard extends StatefulWidget {
  final KestrelDevice? device;
  const _ConnectedInfoCard({this.device});

  @override
  State<_ConnectedInfoCard> createState() => _ConnectedInfoCardState();
}

class _ConnectedInfoCardState extends State<_ConnectedInfoCard> {
  bool _isUpdatingLocation = false;

  Future<void> _updateLatitudeFromGps() async {
    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          setState(() {
            _isUpdatingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
          );
        }
        setState(() {
          _isUpdatingLocation = false;
        });
        return;
      } 

      // Get location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acquiring GPS location...')),
        );
      }
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sending Latitude: ${position.latitude.toStringAsFixed(6)}...')),
      );
      
      final provider = context.read<KestrelProvider>();
      await provider.updateKestrelLatitude(position.latitude);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Latitude updated successfully!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _InfoRow(
            label: 'Connection',
            value: 'Connected',
            valueColor: const Color(0xFF00E676),
            dot: const Color(0xFF00E676),
            showDivider: true,
          ),
          if (widget.device?.batteryLevel != null)
            _InfoRow(
              label: 'Battery',
              value: '${widget.device!.batteryLevel}%',
              showDivider: true,
            ),
          if (widget.device?.modelName != null)
            _InfoRow(
              label: 'Model',
              value: widget.device!.modelName!,
              showDivider: true,
            ),
          if (widget.device?.serialNumber != null)
            _InfoRow(
              label: 'Serial',
              value: widget.device!.serialNumber!,
              showDivider: true,
            ),
          if (widget.device?.firmwareVersion != null)
            _InfoRow(
              label: 'Firmware',
              value: widget.device!.firmwareVersion!,
              showDivider: true,
            ),
          if (widget.device?.hardwareVersion != null)
            _InfoRow(
              label: 'Hardware',
              value: widget.device!.hardwareVersion!,
              showDivider: false,
            ),
          // Fallback if no info yet
          if (widget.device?.modelName == null && widget.device?.serialNumber == null)
            _InfoRow(
              label: 'Address',
              value: widget.device?.address ?? '—',
              showDivider: false,
            ),
          
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdatingLocation ? null : _updateLatitudeFromGps,
                icon: _isUpdatingLocation 
                    ? const SizedBox(
                        width: 18, 
                        height: 18, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  _isUpdatingLocation ? 'Updating...' : 'Update Latitude from GPS',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

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
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF5252), size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                onRetry();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                side: const BorderSide(color: Color(0xFF007AFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared info row ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color? dot;
  final bool showDivider;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white70,
    this.dot,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 15)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(value,
                      style: TextStyle(color: valueColor, fontSize: 15)),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

// ── Disconnected card ─────────────────────────────────────────────────────────

class _DisconnectedCard extends StatelessWidget {
  final KestrelDevice? device;
  final KestrelProvider provider;
  
  const _DisconnectedCard({this.device, required this.provider});

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
          Icon(Icons.bluetooth_disabled_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 36),
          const SizedBox(height: 12),
          Text(
            'Waiting for device to come in range...\nThe app will automatically reconnect.',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Connect',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryThresholdCard extends StatelessWidget {
  final KestrelProvider provider;
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
                'When the Kestrel battery level falls below this percentage, you will be prompted to charge it or swap batteries.',
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

class _BackgroundConnectionCard extends StatelessWidget {
  final KestrelProvider provider;
  const _BackgroundConnectionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final keepAlive = provider.keepConnectedDuringSleep;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bluetooth_connected_rounded,
                      color: Color(0xFF30D158), size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Connection',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kestrel behaviour when app sleeps',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RadioOption(
              label: 'Disconnect when app sleeps',
              sublabel: 'Saves Kestrel battery. Reconnects on wake.',
              selected: !keepAlive,
              onTap: () {
                HapticFeedback.lightImpact();
                provider.setKeepConnectedDuringSleep(false);
              },
            ),
            const SizedBox(height: 6),
            _RadioOption(
              label: 'Stay connected in background',
              sublabel: 'Instant wake. Uses more Kestrel battery.',
              selected: keepAlive,
              onTap: () {
                HapticFeedback.lightImpact();
                provider.setKeepConnectedDuringSleep(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _RadioOption({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF30D158).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF30D158) : Colors.white12,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF30D158) : Colors.white38,
                  width: 2,
                ),
                color: selected ? const Color(0xFF30D158) : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sublabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Range Card Generation Widgets
// ──────────────────────────────────────────────────────────────────────────────

class _RangeCardGenerationCard extends StatefulWidget {
  final KestrelProvider provider;
  final bool isConnected;
  const _RangeCardGenerationCard({required this.provider, required this.isConnected});

  @override
  State<_RangeCardGenerationCard> createState() => _RangeCardGenerationCardState();
}

class _RangeCardGenerationCardState extends State<_RangeCardGenerationCard> {
  Map<String, dynamic>? _savedCard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCard();
  }

  Future<void> _loadSavedCard() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('kestrel_range_card_data');
    if (jsonStr != null) {
      try {
        setState(() {
          _savedCard = jsonDecode(jsonStr);
        });
      } catch (e) {
        debugPrint('[RangeCard] Error loading saved card: $e');
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteSavedCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kestrel_range_card_data');
    setState(() {
      _savedCard = null;
    });
  }

  Future<void> _syncToWatch() async {
    if (_savedCard == null) return;
    HapticFeedback.mediumImpact();
    final matchProvider = context.read<MatchProvider>();

    final rows = List<dynamic>.from(_savedCard!['rows']);
    final watchRows = rows.map((r) {
      return {
        'distance': '${r['range']}',
        'elevation': '${r['elevation']}',
        'wind1': '${r['wind1']}',
        'wind2': '${r['wind2']}',
      };
    }).toList();

    final activeGunName = _savedCard!['activeGunName'] as String?;
    await matchProvider.syncRangeCardToWatch(watchRows, activeGunName: activeGunName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Range Card synced to Matchday Watch App!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    }
  }

  void _showGenerateDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GenerateRangeCardDialog(
        provider: widget.provider,
        onGenerated: (cardData) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('kestrel_range_card_data', jsonEncode(cardData));
          setState(() {
            _savedCard = cardData;
          });
        },
      ),
    );
  }

  void _showViewerDialog() {
    if (_savedCard == null) return;
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => _RangeCardViewerDialog(cardData: _savedCard!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        color: Color(0xFF1E1E24),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF007AFF)),
          ),
        ),
      );
    }

    final hasCard = _savedCard != null;
    final activeGunName = hasCard 
        ? (_savedCard!['activeGunName'] as String? ?? 'Active Profile')
        : (widget.provider.activeGunName ?? 'Active Profile');
    final cardTitle = hasCard 
        ? 'Range Card: $activeGunName' 
        : 'Generate Range Card ($activeGunName)';
    final cardSubtitle = hasCard
        ? 'Generated at ${_savedCard!['timestamp']}\n'
            'Ranges: ${_savedCard!['startRange']}–${_savedCard!['endRange']} yd '
            '• Step: ${_savedCard!['stepSize']} yd'
        : 'Connect Kestrel to calculate and save a new range card';

    return Card(
      color: const Color(0xFF1E1E24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFFFF9F0A), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cardSubtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (hasCard)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _deleteSavedCard();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.isConnected ? _showGenerateDialog : null,
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: Text(hasCard ? 'Recalculate Range Card' : 'Generate Range Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                      disabledForegroundColor: Colors.white30,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                if (hasCard) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showViewerDialog,
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View Card'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _syncToWatch,
                          icon: const Icon(Icons.watch_rounded, size: 16),
                          label: const Text('Send to Watch'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF30D158),
                            side: const BorderSide(color: Color(0xFF30D158)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Generate Range Card Dialog Flow
// ──────────────────────────────────────────────────────────────────────────────

class _GenerateRangeCardDialog extends StatefulWidget {
  final KestrelProvider provider;
  final Function(Map<String, dynamic>) onGenerated;
  const _GenerateRangeCardDialog({required this.provider, required this.onGenerated});

  @override
  State<_GenerateRangeCardDialog> createState() => _GenerateRangeCardDialogState();
}

class _GenerateRangeCardDialogState extends State<_GenerateRangeCardDialog> {
  final _startRangeController = TextEditingController(text: '100');
  final _endRangeController = TextEditingController(text: '1000');
  int _selectedStep = 50; // default 50yd
  final _windSpeedController = TextEditingController(text: '0');
  final _windDirController = TextEditingController(text: '0');
  final _dofController = TextEditingController(text: '0');
  final _incController = TextEditingController(text: '0');

  bool _showConfirmStep = false;
  bool _calculating = false;
  String _calcProgressText = '';
  double _calcProgressPercent = 0.0;

  @override
  void dispose() {
    _startRangeController.dispose();
    _endRangeController.dispose();
    _windSpeedController.dispose();
    _windDirController.dispose();
    _dofController.dispose();
    _incController.dispose();
    super.dispose();
  }

  String _getCardinalDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return '';
  }

  String _getWindDirHelper() {
    final deg = double.tryParse(_windDirController.text) ?? 0.0;
    final slot = TargetArray.degreesToClockSlot(deg);
    return TargetArray.formatClockSlot(slot);
  }

  void _showWindClockPickerDialogFlow() async {
    final double currentDeg = double.tryParse(_windDirController.text) ?? 0.0;
    final int currentSlot = TargetArray.degreesToClockSlot(currentDeg);
    final pickedSlot = await showWindClockPickerDialog(context, initialSlot: currentSlot);
    if (pickedSlot != null) {
      final double deg = TargetArray.clockSlotToDegrees(pickedSlot);
      setState(() {
        _windDirController.text = deg.toStringAsFixed(0);
      });
    }
  }

  void _showCompassDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        double currentHeading = 0.0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<CompassEvent>(
              stream: FlutterCompass.events,
              builder: (context, snapshot) {
                double? heading = snapshot.data?.heading;
                if (heading != null) {
                  currentHeading = heading;
                }

                double displayHeading = (currentHeading < 0)
                    ? (360 + currentHeading)
                    : currentHeading;
                String cardinal = _getCardinalDirection(displayHeading);

                return Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ALIGN TO TARGET',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Point your device directly at the target silhouette.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: -((heading ?? 0.0) * (3.141592653589793 / 180)),
                            child: Container(
                              height: 160,
                              width: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 2),
                                color: const Color(0xFF121214),
                              ),
                              child: const Stack(
                                children: [
                                  Positioned(
                                    top: 8,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Text(
                                        'N',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Text(
                                        'S',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Text(
                                        'W',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Text(
                                        'E',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            height: 180,
                            width: 180,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.navigation,
                              color: Color(0xFF00E676),
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF121214),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${displayHeading.round()}°',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                cardinal,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dofController.text = '${displayHeading.round()}';
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Confirm Heading', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _sendAndWaitForBalSolution({
    required KestrelProvider provider,
    required int targetNumber,
    required Future<void> Function() send,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription<Map<String, dynamic>> subscription;
    subscription = provider.onBalFullSolution.listen((data) {
      final slot = (data['targetNumber'] as num?)?.toInt();
      if (slot == targetNumber && !completer.isCompleted) {
        completer.complete(data);
      }
    });
    try {
      await send();
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _startCalculation() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _calculating = true;
      _calcProgressText = 'Initiating Range Card calculation...';
      _calcProgressPercent = 0.05;
    });

    final startVal = int.tryParse(_startRangeController.text) ?? 100;
    final endVal = int.tryParse(_endRangeController.text) ?? 1000;
    final stepVal = _selectedStep;
    final windSpeed = double.tryParse(_windSpeedController.text) ?? 0.0;
    final windDirection = double.tryParse(_windDirController.text) ?? 0.0;
    final dof = double.tryParse(_dofController.text) ?? 0.0;
    final inc = double.tryParse(_incController.text) ?? 0.0;

    // Build the ranges list
    final ranges = <int>[];
    for (int r = startVal; r <= endVal; r += stepVal) {
      ranges.add(r);
    }
    if (ranges.isEmpty) {
      setState(() => _calculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid range span configuration.')),
      );
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        _calcProgressText = 'Reading active gun profile from Kestrel...';
        _calcProgressPercent = 0.08;
      });
      final activeGunName = await widget.provider.refreshActiveGunName()
          ?? widget.provider.activeGunName
          ?? 'Active Profile';

      final rowsData = <Map<String, dynamic>>[];

      // Loop ranges and calculate using Kestrel's active profile
      for (int i = 0; i < ranges.length; i++) {
        final currentRange = ranges[i];
        if (!mounted) return;

        setState(() {
          _calcProgressText = 'Calculating range ${currentRange}yd (${i + 1}/${ranges.length})...';
          _calcProgressPercent = 0.1 + (0.9 * (i / ranges.length));
        });

        var result = await _sendAndWaitForBalSolution(
          provider: widget.provider,
          targetNumber: 0, // sequential queries in slot 0
          send: () => widget.provider.sendCmdSetBalFullInputs(
            targetNumber: 0,
            targetRangeYards: currentRange.toDouble(),
            directionOfFire: dof,
            windSpeed1Mph: windSpeed,
            windSpeed2Mph: windSpeed,
            windDirection: windDirection,
            inclinationAngle: inc,
          ),
        );

        // Fallback calculation trigger
        if (result['elevation'] == null) {
          result = await _sendAndWaitForBalSolution(
            provider: widget.provider,
            targetNumber: 0,
            timeout: const Duration(seconds: 3),
            send: () => widget.provider.sendCalcFullSolution(targetNumber: 0),
          );
        }

        if (result['elevation'] != null) {
          final el = (result['elevation'] as num).toDouble();
          final w1 = (result['windage1'] as num).toDouble();
          final w2 = (result['windage2'] as num).toDouble();
          final ld = (result['lead'] as num?)?.toDouble() ?? 0.0;
          final vel = (result['velocity'] as num?)?.toDouble() ?? 0.0;
          final eng = (result['energy'] as num?)?.toDouble() ?? 0.0;
          final tofVal = (result['tof'] as num?)?.toDouble() ?? 0.0;
          final spD = (result['spinD'] as num?)?.toDouble() ?? 0.0;

          // Format elevation: negative is U, positive is D
          String formattedEl;
          if (el.abs() < 0.005) {
            formattedEl = '0.00';
          } else {
            formattedEl = '${el.abs().toStringAsFixed(2)} ${el < 0 ? "U" : "D"}';
          }

          // Format wind 1: negative is R, positive is L
          String formattedW1;
          if (w1.abs() < 0.005) {
            formattedW1 = '0.00';
          } else {
            formattedW1 = '${w1.abs().toStringAsFixed(2)} ${w1 < 0 ? "R" : "L"}';
          }

          // Format wind 2: negative is R, positive is L
          String formattedW2;
          if (w2.abs() < 0.005) {
            formattedW2 = '0.00';
          } else {
            formattedW2 = '${w2.abs().toStringAsFixed(2)} ${w2 < 0 ? "R" : "L"}';
          }

          rowsData.add({
            'range': currentRange,
            'elevation': formattedEl,
            'wind1': formattedW1,
            'wind2': formattedW2,
            'lead': ld.toStringAsFixed(2),
            'velocity': vel.toStringAsFixed(0),
            'energy': eng.toStringAsFixed(0),
            'tof': tofVal.toStringAsFixed(3),
            'spinD': spD.toStringAsFixed(2),
          });
        } else {
          rowsData.add({
            'range': currentRange,
            'elevation': '—',
            'wind1': '—',
            'wind2': '—',
            'lead': '—',
            'velocity': '—',
            'energy': '—',
            'tof': '—',
            'spinD': '—',
          });
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final cardData = {
        'activeGunName': activeGunName,
        'timestamp': dateStr,
        'startRange': startVal,
        'endRange': endVal,
        'stepSize': stepVal,
        'windSpeed': windSpeed,
        'windDirection': windDirection,
        'dof': dof,
        'inc': inc,
        'rows': rowsData,
      };

      widget.onGenerated(cardData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Range Card Generated Successfully!'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _calculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating range card: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_calculating) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF007AFF)),
              const SizedBox(height: 20),
              Text(
                _calcProgressText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _calcProgressPercent,
                  color: const Color(0xFF30D158),
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showConfirmStep) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.thermostat_rounded, color: Color(0xFFFF9F0A), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirm Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Have you updated your Kestrel environmentals (temp, pressure, humidity)?\n\n'
          'Also, please verify that the proper gun profile is currently selected '
          'on your Kestrel device, as calculations will run against the active profile.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startCalculation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Yes, Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() => _showConfirmStep = false);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Not Yet — Back'),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Generate Range Card',
        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ranges layout
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startRangeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start Range (yd)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _endRangeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'End Range (yd)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Steps layout
            DropdownButtonFormField<int>(
              initialValue: _selectedStep,
              decoration: const InputDecoration(
                labelText: 'Range Step Increment',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              dropdownColor: const Color(0xFF1E1E24),
              items: [25, 50, 100].map((step) {
                return DropdownMenuItem(
                  value: step,
                  child: Text('$step yards', style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedStep = val);
              },
            ),
            const SizedBox(height: 12),

            // Wind parameters
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _windSpeedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wind Speed (mph)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _windDirController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Wind Dir: ${_getWindDirHelper()} (${_windDirController.text}°)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time_rounded, color: Color(0xFF007AFF), size: 20),
                        onPressed: _showWindClockPickerDialogFlow,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Direction of fire & Inclination
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dofController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'DOF (deg)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.compass_calibration, color: Color(0xFF007AFF), size: 20),
                        onPressed: _showCompassDialog,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _incController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Inclination (deg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showConfirmStep = true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Range Card Viewer Table Display
// ──────────────────────────────────────────────────────────────────────────────

class _RangeCardViewerDialog extends StatefulWidget {
  final Map<String, dynamic> cardData;
  const _RangeCardViewerDialog({required this.cardData});

  @override
  State<_RangeCardViewerDialog> createState() => _RangeCardViewerDialogState();
}

class _RangeCardViewerDialogState extends State<_RangeCardViewerDialog> {
  late final ScrollController _leftController;
  late final ScrollController _rightController;
  bool _syncingLeft = false;
  bool _syncingRight = false;

  @override
  void initState() {
    super.initState();
    _leftController = ScrollController();
    _rightController = ScrollController();

    _leftController.addListener(() {
      if (_syncingRight) return;
      _syncingLeft = true;
      if (_rightController.hasClients) {
        _rightController.jumpTo(_leftController.offset);
      }
      _syncingLeft = false;
    });

    _rightController.addListener(() {
      if (_syncingLeft) return;
      _syncingRight = true;
      if (_leftController.hasClients) {
        _leftController.jumpTo(_rightController.offset);
      }
      _syncingRight = false;
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = List<dynamic>.from(widget.cardData['rows']);

    // Column widths
    const double rangeWidth = 85.0;
    const double elevWidth = 70.0;
    const double wind1Width = 75.0;
    const double wind2Width = 75.0;
    const double leadWidth = 65.0;
    const double velWidth = 80.0;
    const double engWidth = 90.0;
    const double tofWidth = 70.0;
    const double spinDWidth = 65.0;

    const double headerHeight = 38.0;
    const double rowHeight = 34.0;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${widget.cardData['activeGunName'] ?? 'Active Profile'} Range Card',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Created: ${widget.cardData['timestamp']}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            'Wind: ${widget.cardData['windSpeed']} mph @ ${_getWindClockString(widget.cardData['windDirection'])} (${widget.cardData['windDirection']}°) • '
                'DOF: ${widget.cardData['dof']}° • Inc: ${widget.cardData['inc']}°',
            style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3),
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Row(
          children: [
            // Left Frozen Column (Range)
            Container(
              width: rangeWidth,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Range Header
                  Container(
                    height: headerHeight,
                    width: rangeWidth,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                    ),
                    child: const Text(
                      'Range (yd)',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Range Rows
                  Expanded(
                    child: ListView.builder(
                      controller: _leftController,
                      itemCount: rows.length,
                      itemExtent: rowHeight,
                      itemBuilder: (context, index) {
                        final r = rows[index];
                        final isOdd = index % 2 == 1;
                        return Container(
                          height: rowHeight,
                          width: rangeWidth,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isOdd ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                            ),
                          ),
                          child: Text(
                            '${r['range']}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Right Scrollable Columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: elevWidth + wind1Width + wind2Width + leadWidth + velWidth + engWidth + tofWidth + spinDWidth,
                  child: Column(
                    children: [
                      // Headers Row
                      Container(
                        height: headerHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildHeaderCell('Elev', elevWidth),
                            _buildHeaderCell('Wind 1', wind1Width),
                            _buildHeaderCell('Wind 2', wind2Width),
                            _buildHeaderCell('Lead', leadWidth),
                            _buildHeaderCell('Vel (fps)', velWidth),
                            _buildHeaderCell('Eng (ft-lb)', engWidth),
                            _buildHeaderCell('ToF (s)', tofWidth),
                            _buildHeaderCell('SpinD', spinDWidth),
                          ],
                        ),
                      ),
                      // Data Rows
                      Expanded(
                        child: ListView.builder(
                          controller: _rightController,
                          itemCount: rows.length,
                          itemExtent: rowHeight,
                          itemBuilder: (context, index) {
                            final r = rows[index];
                            final isOdd = index % 2 == 1;
                            return Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: isOdd ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildDataCell('${r['elevation']}', elevWidth, isGreen: true),
                                  _buildDataCell('${r['wind1']}', wind1Width),
                                  _buildDataCell('${r['wind2']}', wind2Width),
                                  _buildDataCell('${r['lead']}', leadWidth, isGrey: true),
                                  _buildDataCell('${r['velocity']}', velWidth, isGrey: true),
                                  _buildDataCell('${r['energy']}', engWidth, isGrey: true),
                                  _buildDataCell('${r['tof']}', tofWidth, isGrey: true),
                                  _buildDataCell('${r['spinD']}', spinDWidth, isGrey: true),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.only(bottom: 12, right: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Color(0xFF007AFF))),
        ),
      ],
    );
  }

  String _getWindClockString(dynamic deg) {
    final dVal = double.tryParse(deg.toString()) ?? 0.0;
    final slot = TargetArray.degreesToClockSlot(dVal);
    return TargetArray.formatClockSlot(slot);
  }

  Widget _buildHeaderCell(String label, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF007AFF),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDataCell(String value, double width, {bool isGreen = false, bool isGrey = false}) {
    Color txtColor = Colors.white;
    if (isGreen) {
      txtColor = const Color(0xFF30D158);
    } else if (isGrey) {
      txtColor = Colors.white60;
    }
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        value,
        style: TextStyle(color: txtColor, fontSize: 12),
      ),
    );
  }
}

