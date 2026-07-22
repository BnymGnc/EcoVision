import 'package:flutter/material.dart';

class MascotCelebration {
  const MascotCelebration._();

  static Future<void> show(
    BuildContext context, {
    String detail = 'Yeni başarın profilindeki yolculuğa eklendi.',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary, width: 2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tebrikler! Doğayı kurtarıyorsun!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Harika!'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
