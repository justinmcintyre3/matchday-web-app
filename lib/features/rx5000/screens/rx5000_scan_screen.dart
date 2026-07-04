import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rx5000_device.dart';
import '../providers/rx5000_provider.dart';

class Rx5000ScanScreen extends StatefulWidget {
  const Rx5000ScanScreen({super.key});

  @override
  State<Rx5000ScanScreen> createState() => _Rx5000ScanScreenState();
}

class _Rx5000ScanScreenState extends State<Rx5000ScanScreen> {
  final TextEditingController _pinController = TextEditingController();
  late Rx5000Provider _provider;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.startScan();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<Rx5000Provider>(context, listen: false);
  }

  @override
  void dispose() {
    _provider.stopScan();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Rx5000Provider>();
    final isScanning = provider.isScanning;
    final devices = provider.scannedDevices;
    final state = provider.connectionState;
    final pairingCode = provider.pairingDeviceCode;

    // Auto-navigate to settings once fully connected
    if (state == Rx5000ConnectionState.connected && !_hasPopped) {
      _hasPopped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: const Text('Add Rangefinder'),
        actions: [
          if (!isScanning && pairingCode == null)
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
          // Scanning progress bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: (isScanning && pairingCode == null) ? 4 : 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                if (pairingCode != null)
                  _buildPairingView(provider, pairingCode)
                else ...[
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          isScanning ? 'SCANNING FOR RX5000...' : 'NEARBY DEVICES',
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

                  // Device list
                  if (devices.isEmpty && isScanning)
                    const _EmptyState(isScanning: true)
                  else if (devices.isEmpty)
                    const _EmptyState(isScanning: false)
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingView(Rx5000Provider provider, String pairingCode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              color: Color(0xFF007AFF),
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Pairing Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your Leupold RX5000 screen for the 4-digit PIN code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Code Confirmation block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Device Match Code: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  pairingCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E676),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PIN Input field
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '0000',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                letterSpacing: 8,
              ),
              counterText: '',
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              style: const TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 12,
              ),
            ),
          ],
          
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    provider.disconnect();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final pinText = _pinController.text;
                    final pin = int.tryParse(pinText);
                    if (pin != null && pinText.isNotEmpty) {
                      HapticFeedback.mediumImpact();
                      provider.submitPin(pin);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Pair',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────────────────────────────────────

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
              Icons.radar,
              color: Color(0xFF007AFF),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Looking for rangefinders…' : 'No devices found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isScanning
                ? 'Make sure your RX5000 is powered on\nand in pairing mode.'
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

// ──────────────────────────────────────────────────────────────────────────────
// Device tile
// ──────────────────────────────────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  final Rx5000Device device;
  final bool isLast;

  const _DeviceTile({required this.device, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<Rx5000Provider>();
    final isConnecting =
        provider.connectionState == Rx5000ConnectionState.connecting ||
        provider.connectionState == Rx5000ConnectionState.discovering;

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.radar,
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
