import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:provider/provider.dart';
import 'device_detail_screen.dart';
import '../features/kestrel_ble/providers/kestrel_provider.dart';
import '../features/kestrel_ble/models/kestrel_device.dart';
import '../features/kestrel_ble/screens/kestrel_scan_screen.dart';
import '../features/kestrel_ble/screens/kestrel_detail_screen.dart';
import '../features/sg_pulse/providers/sg_pulse_provider.dart';
import '../features/sg_pulse/models/sg_pulse_device.dart';
import '../features/sg_pulse/screens/sg_pulse_scan_screen.dart';
import '../features/sg_pulse/screens/sg_pulse_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _wc = WatchConnectivity();
  bool? _isReachable;
  bool? _isPaired;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchStatus();
  }

  Future<void> _loadWatchStatus() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    try {
      final reachable = await _wc.isReachable;
      bool? paired;
      try {
        paired = await _wc.isPaired;
      } catch (_) {
        paired = null;
      }
      if (mounted) {
        setState(() {
          _isReachable = reachable;
          _isPaired = paired;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showAddDeviceSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AddDeviceSheet(),
    );
  }

  String _getWatchSubtitle() {
    if (_loading) return 'Wear OS • Checking status...';
    if (_isReachable == true) return 'Wear OS • Reachable';
    if (_isPaired == true) return 'Wear OS • Paired';
    if (_isPaired == false) return 'Wear OS • Disconnected';
    return 'Wear OS • Not Reachable';
  }

  Color _getWatchStatusColor() {
    if (_loading) return Colors.grey;
    if (_isReachable == true) return const Color(0xFF00E676);
    if (_isPaired == true) return const Color(0xFF007AFF);
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    final kestrel = context.watch<KestrelProvider>().connectedDevice;
    final isKestrelSaved = kestrel != null;
    final kestrelConnected = kestrel?.state == KestrelConnectionState.connected;

    final sgPulse = context.watch<SgPulseProvider>().connectedDevice;
    final isSgPulseSaved = sgPulse != null;
    final sgPulseConnected = sgPulse?.state == SgPulseConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF007AFF),
        backgroundColor: const Color(0xFF1E1E24),
        onRefresh: _loadWatchStatus,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            top: 24,
            left: 16,
            right: 16,
            bottom: kBottomNavigationBarHeight + 24,
          ),
          children: [
            // -- Section header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'DEVICES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // -- Device list card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  // ── Matchday Watch tile ──────────────────────────────────
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF007AFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: Color(0xFF007AFF),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Matchday Watch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _getWatchSubtitle(),
                      style: TextStyle(
                        color: _loading
                            ? Colors.white.withValues(alpha: 0.3)
                            : _isReachable == true
                                ? const Color(0xFF00E676)
                                    .withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_loading)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getWatchStatusColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right,
                            color: Colors.white38, size: 20),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeviceDetailScreen(
                            deviceName: 'Matchday Watch',
                            deviceType: 'Wear OS',
                          ),
                        ),
                      ).then((_) => _loadWatchStatus());
                    },
                  ),

                  // ── Kestrel tile (if a device is saved) ──────────────────
                  if (isKestrelSaved) ...[
                    Divider(
                      height: 1,
                      indent: 56,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (kestrelConnected ? const Color(0xFF00E676) : Colors.white)
                              .withValues(alpha: kestrelConnected ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          kestrelConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                          color: kestrelConnected ? const Color(0xFF00E676) : Colors.white38,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        kestrel.name,
                        style: TextStyle(
                          color: kestrelConnected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        kestrelConnected 
                          ? 'Kestrel ${kestrel.deviceType} • Connected'
                          : 'Kestrel ${kestrel.deviceType} • Disconnected',
                        style: TextStyle(
                          color: kestrelConnected ? const Color(0xFF00E676) : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (kestrelConnected)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (kestrelConnected) const SizedBox(width: 8),
                          const Icon(Icons.chevron_right,
                              color: Colors.white38, size: 20),
                        ],
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KestrelDetailScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  // ── SG Pulse tile (if a device is saved) ──────────────────
                  if (isSgPulseSaved) ...[
                    Divider(
                      height: 1,
                      indent: 56,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (sgPulseConnected ? const Color(0xFF00E676) : Colors.white)
                              .withValues(alpha: sgPulseConnected ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          sgPulseConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                          color: sgPulseConnected ? const Color(0xFF00E676) : Colors.white38,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        sgPulse.name,
                        style: TextStyle(
                          color: sgPulseConnected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        sgPulseConnected 
                          ? 'SG Pulse • Connected'
                          : 'SG Pulse • Disconnected',
                        style: TextStyle(
                          color: sgPulseConnected ? const Color(0xFF00E676) : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sgPulseConnected)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (sgPulseConnected) const SizedBox(width: 8),
                          const Icon(Icons.chevron_right,
                              color: Colors.white38, size: 20),
                        ],
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SgPulseDetailScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // -- Add Device button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showAddDeviceSheet(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E24),
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add Device',
                  style:
                      TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Add Device Bottom Sheet — device type selector
// ──────────────────────────────────────────────────────────────────────────────

class _AddDeviceSheet extends StatelessWidget {
  const _AddDeviceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Add a Device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What type of device would you like to add?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          // ── Ballistics Device tile ────────────────────────────────────
          _DeviceTypeTile(
            icon: Icons.my_location_rounded,
            iconColor: const Color(0xFF007AFF),
            title: 'Ballistics Device',
            subtitle: 'Kestrel 5700, 2700, Elite',
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const KestrelScanScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // ── IMU Device tile ───────────────────────────────────────────
          _DeviceTypeTile(
            icon: Icons.sensors,
            iconColor: const Color(0xFF007AFF),
            title: 'IMU Device',
            subtitle: 'SG Pulse',
            enabled: true,
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SgPulseScanScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Device type tile ──────────────────────────────────────────────────────────

class _DeviceTypeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _DeviceTypeTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2A32),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: enabled ? 0.15 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? iconColor : Colors.white24,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? Colors.white38 : Colors.white12,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

