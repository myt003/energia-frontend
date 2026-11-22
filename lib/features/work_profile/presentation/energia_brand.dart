import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';

class EnergiaLogo extends StatelessWidget {
  const EnergiaLogo({
    this.size = 42,
    this.showWordmark = true,
    this.onDark = true,
    super.key,
  });

  final double size;
  final bool showWordmark;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? EnergiaColors.sand : EnergiaColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: EnergiaColors.sand,
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: [
              BoxShadow(
                color: EnergiaColors.electricBlue.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: EnergiaColors.violet),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 12),
          Text(
            'energia',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ],
    );
  }
}

class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRect(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: EnergiaColors.deepNavy),
              ),
            ),
            Positioned(
              right: -68,
              top: -54,
              child: _GlowCircle(
                size: 230,
                color: EnergiaColors.teal.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              left: -84,
              bottom: -115,
              child: _GlowCircle(
                size: 270,
                color: EnergiaColors.electricLime.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              right: 42,
              bottom: 28,
              child: Transform.rotate(
                angle: -0.48,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: EnergiaColors.sand.withValues(alpha: 0.10),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
