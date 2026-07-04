// Kestrel device detail screen.
//
// Shown after [KestrelScanScreen] initiates a connection.
// Displays connection progress, prompts for PIN if required,
// and shows device info when fully connected.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../models/kestrel_device.dart';
import '../providers/kestrel_provider.dart';

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
          Center(
            child: Column(
              children: [
                _DeviceIcon(state: state),
                const SizedBox(height: 14),
                Text(
                  device?.name ?? 'Kestrel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device != null
                      ? device.modelDisplay
                      : 'Ballistics Device',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── State-specific content ──────────────────────────────────────
          _buildStateContent(context, state, device, provider),

          if (device != null) ...[
            const SizedBox(height: 16),
            _BatteryThresholdCard(provider: provider),
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
          onRetry: () => provider.startScan(), // Or reconnect if MAC known
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

class _DeviceIcon extends StatelessWidget {
  final KestrelConnectionState state;
  const _DeviceIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    IconData icon;

    switch (state) {
      case KestrelConnectionState.connected:
        iconBg = const Color(0xFF00E676).withValues(alpha: 0.12);
        iconColor = const Color(0xFF00E676);
        icon = Icons.track_changes;
        break;
      case KestrelConnectionState.error:
        iconBg = const Color(0xFFFF5252).withValues(alpha: 0.12);
        iconColor = const Color(0xFFFF5252);
        icon = Icons.bluetooth_disabled;
        break;
      default:
        iconBg = const Color(0xFF007AFF).withValues(alpha: 0.12);
        iconColor = const Color(0xFF007AFF);
        icon = Icons.bluetooth_searching;
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: iconColor, size: 38),
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
