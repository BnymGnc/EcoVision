import 'package:flutter/material.dart';

class StubScreenScaffold extends StatelessWidget {
  const StubScreenScaffold({
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
    super.key,
  });

  final String title;
  final IconData icon;
  final String heading;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 44, color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 22),
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 18),
                Chip(
                  avatar: const Icon(Icons.eco_outlined, size: 18),
                  label: const Text('Coming Soon'),
                  backgroundColor: colors.secondaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
