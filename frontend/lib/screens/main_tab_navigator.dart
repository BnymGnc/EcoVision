import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class MainTabNavigator extends StatefulWidget {
  const MainTabNavigator({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(apiService: widget.apiService, onOpenMap: () => _selectTab(1)),
      MapScreen(apiService: widget.apiService),
      CommunityScreen(apiService: widget.apiService),
      ProfileScreen(apiService: widget.apiService),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
