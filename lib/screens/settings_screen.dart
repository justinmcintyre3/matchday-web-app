import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'device_detail_screen.dart';

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

  // Devices list - will be populated dynamically in the future.
  static const List<Map<String, String>> _devices = [
    {'name': 'Matchday Watch', 'type': 'Wear OS'},
  ];

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

  String _getSubtitle(Map<String, String> device) {
    if (_loading) return 'Checking status...';
    String status = device['type']!;
    if (_isReachable == true) {
      status += ' • Reachable';
    } else if (_isPaired == true) {
      status += ' • Paired';
    } else if (_isPaired == false) {
      status += ' • Disconnected';
    } else {
      status += ' • Not Reachable';
    }
    return status;
  }

  Color _getStatusColor() {
    if (_loading) return Colors.grey;
    if (_isReachable == true) return const Color(0xFF00E676); // Green
    if (_isPaired == true) return const Color(0xFF007AFF); // Blue
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
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
                children: _devices.asMap().entries.map((entry) {
                  final i = entry.key;
                  final device = entry.value;
                  final isLast = i == _devices.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.watch_rounded,
                            color: Color(0xFF007AFF),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          device['name']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _getSubtitle(device),
                          style: TextStyle(
                            color: _loading
                                ? Colors.white.withValues(alpha: 0.3)
                                : _isReachable == true
                                    ? const Color(0xFF00E676).withValues(alpha: 0.8)
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
                                  color: _getStatusColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                              size: 20,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeviceDetailScreen(
                                deviceName: device['name']!,
                                deviceType: device['type']!,
                              ),
                            ),
                          ).then((_) {
                            // Reload when returning from device details
                            _loadWatchStatus();
                          });
                        },
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 0,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                    ],
                  );
                }).toList(),
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
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Add Device Bottom Sheet
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

          // Icon
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.bluetooth_searching,
              color: Color(0xFF007AFF),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Add a Device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bluetooth device pairing is coming soon.\nYou\'ll be able to discover and connect\nnew devices from here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
