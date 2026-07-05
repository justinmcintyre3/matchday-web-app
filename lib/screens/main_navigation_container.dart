import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../features/kestrel_ble/providers/kestrel_provider.dart';
import '../features/kestrel_ble/screens/kestrel_detail_screen.dart';
import '../features/sg_pulse/providers/sg_pulse_provider.dart';
import '../features/rx5000/providers/rx5000_provider.dart';
import 'matches_list_screen.dart';
import 'checklist_groups_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _selectedIndex = 0;
  StreamSubscription? _latMismatchSub;
  StreamSubscription? _sgPulseBatteryLowSub;
  StreamSubscription? _kestrelBatteryLowSub;
  StreamSubscription? _rx5000BatteryLowSub;

  final List<Widget> _screens = [
    const MatchesListScreen(),
    const HomeScreen(), // The original checklist Groups screen
  ];

  @override
  void initState() {
    super.initState();
    _latMismatchSub = context.read<KestrelProvider>().onLatitudeMismatch.listen((kestrelLat) {
      if (!mounted) return;
      _showLatitudeMismatchDialog(kestrelLat);
    });

    _sgPulseBatteryLowSub = context.read<SgPulseProvider>().onBatteryLow.listen((batteryLevel) {
      if (!mounted) return;
      _showSgPulseBatteryLowDialog(batteryLevel);
    });

    _kestrelBatteryLowSub = context.read<KestrelProvider>().onBatteryLow.listen((batteryLevel) {
      if (!mounted) return;
      _showKestrelBatteryLowDialog(batteryLevel);
    });

    _rx5000BatteryLowSub = context.read<Rx5000Provider>().onBatteryLow.listen((batteryLevel) {
      if (!mounted) return;
      _showRx5000BatteryLowDialog(batteryLevel);
    });
  }

  @override
  void dispose() {
    _latMismatchSub?.cancel();
    _sgPulseBatteryLowSub?.cancel();
    _kestrelBatteryLowSub?.cancel();
    _rx5000BatteryLowSub?.cancel();
    super.dispose();
  }

  void _showLatitudeMismatchDialog(double kestrelLat) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Latitude Mismatch'),
        content: Text(
          'It appears your phone\'s GPS location does not match the latitude stored in your connected Kestrel '
          '(${kestrelLat.toStringAsFixed(2)}).\n\n'
          'Press "Ignore" if this is on purpose (you won\'t be reminded again unless you update it later). '
          'Press "Update" to go to the Kestrel settings and sync your location.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<KestrelProvider>().silenceLatitudeMismatch();
              Navigator.pop(ctx);
            },
            child: const Text('Ignore', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KestrelDetailScreen()),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  void _showSgPulseBatteryLowDialog(int batteryLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('SG Pulse Battery Low'),
        content: Text(
          'Your SG Pulse battery is at $batteryLevel%.\n\n'
          'Please connect your device to a charger.\n'
          'Press "Ignore" to mute this warning until the next full charge.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<SgPulseProvider>().silenceBatteryLowWarning();
              Navigator.pop(ctx);
            },
            child: const Text('Ignore', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showKestrelBatteryLowDialog(int batteryLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Kestrel Battery Low'),
        content: Text(
          'Your Kestrel battery is at $batteryLevel%.\n\n'
          'Please connect your device to a charger / swap batteries.\n'
          'Press "Ignore" to mute this warning until the next full charge.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<KestrelProvider>().silenceBatteryLowWarning();
              Navigator.pop(ctx);
            },
            child: const Text('Ignore', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRx5000BatteryLowDialog(int batteryLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('RX5000 Battery Low'),
        content: Text(
          'Your Leupold RX5000 battery is at $batteryLevel%.\n\n'
          'Please connect your device to a charger / swap batteries.\n'
          'Press "Ignore" to mute this warning until the next full charge.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<Rx5000Provider>().silenceBatteryLowWarning();
              Navigator.pop(ctx);
            },
            child: const Text('Ignore', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.stars_outlined, size: 24),
              activeIcon: Icon(Icons.stars, size: 24),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined, size: 24),
              activeIcon: Icon(Icons.fact_check, size: 24),
              label: 'Checklists',
            ),
          ],
        ),
      ),
    );
  }
}

