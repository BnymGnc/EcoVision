import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainTabNavigator extends StatefulWidget {
  const MainTabNavigator({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _selectedIndex = 0;
  int _unreadCommunityCount = 0;
  int _unreadNotificationCount = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    if (widget.apiService.currentUser?.adult ?? false) {
      unawaited(_refreshUnread());
    }
    unawaited(_refreshNotifications());
    _unreadTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshUnread();
      _refreshNotifications();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    if (!(widget.apiService.currentUser?.adult ?? false)) return;
    try {
      if (_selectedIndex == 2) {
        await widget.apiService.markCommunityRead();
        if (mounted) setState(() => _unreadCommunityCount = 0);
        return;
      }
      final count = await widget.apiService.fetchUnreadCommunityCount();
      if (mounted) setState(() => _unreadCommunityCount = count);
    } catch (_) {
      // Navigation remains usable while unread state retries in the background.
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      final count = await widget.apiService.fetchUnreadNotificationCount();
      if (mounted) setState(() => _unreadNotificationCount = count);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(apiService: widget.apiService),
      ),
    );
    if (mounted) {
      setState(() => _unreadNotificationCount = 0);
      await _refreshNotifications();
    }
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 2 && (widget.apiService.currentUser?.adult ?? false)) {
      setState(() => _unreadCommunityCount = 0);
      unawaited(widget.apiService.markCommunityRead());
    }
  }

  Widget _communityIcon(IconData icon) {
    if (_unreadCommunityCount == 0) return Icon(icon);
    return Badge.count(
      count: _unreadCommunityCount.clamp(1, 99),
      backgroundColor: Colors.red.shade700,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adult = widget.apiService.currentUser?.adult ?? false;
    final screens = <Widget>[
      HomeScreen(
        apiService: widget.apiService,
        onOpenMap: () => _selectTab(1),
        notificationCount: _unreadNotificationCount,
        onNotifications: _openNotifications,
      ),
      MapScreen(
        apiService: widget.apiService,
        notificationCount: _unreadNotificationCount,
        onNotifications: _openNotifications,
      ),
      if (adult)
        CommunityScreen(
          apiService: widget.apiService,
          notificationCount: _unreadNotificationCount,
          onNotifications: _openNotifications,
        ),
      ProfileScreen(
        apiService: widget.apiService,
        notificationCount: _unreadNotificationCount,
        onNotifications: _openNotifications,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Tarayıcı',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Harita',
          ),
          if (adult)
            NavigationDestination(
              icon: _communityIcon(Icons.groups_outlined),
              selectedIcon: _communityIcon(Icons.groups),
              label: 'Topluluk',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
