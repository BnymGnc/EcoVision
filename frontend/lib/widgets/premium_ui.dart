import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

abstract final class EcoHaptics {
  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> heavy() => HapticFeedback.heavyImpact();
  static Future<void> selection() => HapticFeedback.selectionClick();
}

Future<T?> showEcoGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  EcoHaptics.light();
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: colors.surface.withValues(alpha: 0),
    barrierColor: colors.scrim.withValues(alpha: 0.28),
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: builder(context),
        ),
      ),
    ),
  );
}

class EcoSheetHandle extends StatelessWidget {
  const EcoSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class EcoShimmerList extends StatelessWidget {
  const EcoShimmerList({
    this.itemCount = 5,
    this.showHeader = false,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final int itemCount;
  final bool showHeader;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest.withValues(alpha: 0.72),
      highlightColor: Color.alphaBlend(
        colors.primary.withValues(alpha: 0.06),
        colors.surface,
      ),
      period: const Duration(milliseconds: 1450),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: padding,
        children: [
          if (showHeader) ...[
            const _Skeleton(height: 112),
            const SizedBox(height: 18),
          ],
          for (var i = 0; i < itemCount; i++) ...[
            const _Skeleton(height: 78),
            if (i < itemCount - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class EcoChatShimmer extends StatelessWidget {
  const EcoChatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest.withValues(alpha: 0.72),
      highlightColor: Color.alphaBlend(
        colors.primary.withValues(alpha: 0.06),
        colors.surface,
      ),
      period: const Duration(milliseconds: 1450),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
        itemCount: 7,
        itemBuilder: (context, index) => Align(
          alignment: index.isEven
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Container(
            width: index % 3 == 0 ? 235 : 175,
            height: index % 3 == 0 ? 72 : 54,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding,
    this.tint,
    this.borderRadius = 24,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? tint;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (tint ?? colors.surface).withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
    ),
  );
}
