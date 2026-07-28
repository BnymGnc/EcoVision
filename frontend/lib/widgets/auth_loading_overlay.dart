import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AuthLoadingOverlay extends StatelessWidget {
  const AuthLoadingOverlay({
    required this.visible,
    required this.child,
    this.message = 'Güvenli bağlantı kuruluyor...',
    super.key,
  });

  final bool visible;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.22),
                  child: Center(
                    child: Container(
                      width: 230,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The lightweight web renderer can recurse on this
                          // Lottie trim-path animation. Keep the native Lottie
                          // experience while using a stable web fallback.
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: kIsWeb
                                ? const Center(
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : Lottie.asset('assets/animations/loading.json'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
