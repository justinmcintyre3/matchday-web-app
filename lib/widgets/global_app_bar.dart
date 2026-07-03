import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/match_provider.dart';
import '../features/kestrel_ble/providers/kestrel_provider.dart';
import '../features/kestrel_ble/models/kestrel_device.dart';
import '../features/sg_pulse/providers/sg_pulse_provider.dart';
import '../features/sg_pulse/models/sg_pulse_device.dart';
import '../screens/settings_screen.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GlobalAppBar({super.key, this.title, this.actions, this.bottom});

  Color _iconColor(bool connected) => connected ? const Color(0xFF30D158) : Colors.grey;

  @override
  Widget build(BuildContext context) {
    final watchConnected = context.watch<MatchProvider>().isWatchConnected;
    final kestrelConnected = context.watch<KestrelProvider>().connectionState == KestrelConnectionState.connected;
    final pulseConnected = context.watch<SgPulseProvider>().connectionState == SgPulseConnectionState.connected;

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return AppBar(
      title: title,
      leadingWidth: 72,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.watch, size: 16, color: _iconColor(watchConnected)),
              const SizedBox(width: 4),
              Icon(Icons.track_changes, size: 16, color: _iconColor(kestrelConnected)),
              const SizedBox(width: 4),
              Icon(Icons.sensors, size: 16, color: _iconColor(pulseConnected)),
            ],
          ),
          if (canPop) ...[
            const SizedBox(height: 2),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.blue),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        IconButton(
          icon: const Icon(Icons.settings, size: 24),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
