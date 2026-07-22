import 'package:flutter/material.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({
    required this.count,
    required this.onPressed,
    super.key,
  });
  final int count;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Bildirimler',
    onPressed: onPressed,
    icon: count <= 0
        ? const Icon(Icons.notifications_none_rounded)
        : Badge.count(
            count: count.clamp(1, 99),
            backgroundColor: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.notifications_outlined),
          ),
  );
}
