import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EcoLottie extends StatelessWidget {
  const EcoLottie({
    required this.url,
    required this.fallbackIcon,
    this.size = 140,
    this.repeat = true,
    super.key,
  });

  final String url;
  final IconData fallbackIcon;
  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox.square(
      dimension: size,
      child: Lottie.network(
        url,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(fallbackIcon, size: size * 0.5, color: color);
        },
      ),
    );
  }
}
