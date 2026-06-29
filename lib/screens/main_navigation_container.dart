import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'matches_list_screen.dart';
import 'checklist_groups_screen.dart';
import 'settings_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MatchesListScreen(),
    const HomeScreen(), // The original checklist Groups screen
    const SettingsScreen(),
  ];

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
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, size: 24),
              activeIcon: Icon(Icons.settings, size: 24),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
