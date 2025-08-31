import 'package:flutter/material.dart';

class MacroProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;
  final bool compact;
  final String unit;
  // Added optional override + color for right-side text.
  final String? rightTextOverride;
  final Color? rightTextColor;
  const MacroProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    this.compact = false,
    this.unit = 'g',
    this.rightTextOverride,
    this.rightTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeGoal = goal <= 0 ? 1.0 : goal; // avoid div by zero
    final pct = (value / safeGoal).clamp(0.0, 1.0);
    final barHeight = compact ? 6.0 : 14.0;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final rightStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: rightTextColor);
    final defaultRight =
        '${value.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}$unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textStyle)),
              const SizedBox(width: 8),
              Text(rightTextOverride ?? defaultRight, style: rightStyle),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: pct),
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: SizedBox(
                height: barHeight,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
