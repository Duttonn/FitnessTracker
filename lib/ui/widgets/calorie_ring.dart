import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/theme.dart';

/// A circular calorie ring that animates fill from 0 → [consumed/goal].
/// Shows consumed, goal, and remaining values inside.
class CalorieRingWidget extends StatelessWidget {
  const CalorieRingWidget({
    super.key,
    required this.consumed,
    required this.goal,
    this.size = 180.0,
    this.strokeWidth = 16.0,
  });

  final int consumed;
  final int goal;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final safeGoal = goal <= 0 ? 1 : goal;
    final pct = (consumed / safeGoal).clamp(0.0, 1.0);
    final remaining = (goal - consumed).clamp(-99999, 99999);
    final isOver = consumed > goal;
    final ringColor = isOver
        ? AppColors.danger
        : Color.lerp(AppColors.primary, AppColors.success, 1 - pct)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: pct),
      builder: (context, animPct, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: 1.0,
                  color: isDark
                      ? Colors.white.withValues(alpha: .08)
                      : Colors.black.withValues(alpha: .06),
                  strokeWidth: strokeWidth,
                ),
              ),
              // Progress arc
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: animPct,
                  color: ringColor,
                  strokeWidth: strokeWidth,
                  withGlow: !isOver,
                ),
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<int>(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    tween: IntTween(begin: 0, end: remaining.abs()),
                    builder: (_, val, __) => Text(
                      isOver ? '+$val' : '$val',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isOver ? AppColors.danger : null,
                          ),
                    ),
                  ),
                  Text(
                    isOver ? 'over goal' : 'kcal left',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.withGlow = false,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final bool withGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track / arc paint
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;

    if (withGlow && progress > 0.02) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth + 6
        ..color = color.withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        glowPaint,
      );
    }

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
