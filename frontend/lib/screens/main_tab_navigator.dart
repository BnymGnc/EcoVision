import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/premium_ui.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

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
  String? _requestedMapMaterial;
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

  void _selectTab(int index, {String? mapMaterial}) {
    EcoHaptics.selection();
    setState(() {
      _selectedIndex = index;
      if (index == 1 && mapMaterial != null) {
        _requestedMapMaterial = mapMaterial;
      }
    });
    if (index == 2 && (widget.apiService.currentUser?.adult ?? false)) {
      setState(() => _unreadCommunityCount = 0);
      unawaited(widget.apiService.markCommunityRead());
    }
  }

  Widget _communityIcon(IconData icon) {
    if (_unreadCommunityCount == 0) return Icon(icon);
    return Badge.count(
      count: _unreadCommunityCount.clamp(1, 99),
      backgroundColor: Theme.of(context).colorScheme.error,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adult = widget.apiService.currentUser?.adult ?? false;
    final colors = Theme.of(context).colorScheme;
    final screens = <Widget>[
      HomeScreen(
        apiService: widget.apiService,
        onOpenMap: (material) => _selectTab(1, mapMaterial: material),
        notificationCount: _unreadNotificationCount,
        onNotifications: _openNotifications,
      ),
      MapScreen(
        apiService: widget.apiService,
        requestedMaterial: _requestedMapMaterial,
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
      extendBody: false,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: NavigationBar(
                height: 72,
                backgroundColor: colors.surface.withValues(alpha: 0),
                elevation: 0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectTab,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.document_scanner_outlined),
                    selectedIcon: Icon(Icons.document_scanner_rounded),
                    label: 'Tarayıcı',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map_rounded),
                    label: 'Harita',
                  ),
                  if (adult)
                    NavigationDestination(
                      icon: _communityIcon(Icons.groups_outlined),
                      selectedIcon: _communityIcon(Icons.groups_rounded),
                      label: 'Topluluk',
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profil',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
