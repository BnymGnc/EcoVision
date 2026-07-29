import 'dart:async';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _coldStartTimer;
  bool _wakingServer = false;

  @override
  void initState() {
    super.initState();
    _coldStartTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _wakingServer = true);
    });
  }

  @override
  void dispose() {
    _coldStartTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.eco_rounded,
                    size: 54,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'EcoVision',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _wakingServer
                        ? 'Sunucular uyandırılıyor, lütfen bekleyin...'
                        : 'Güvenli oturumun kontrol ediliyor...',
                    key: ValueKey(_wakingServer),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
