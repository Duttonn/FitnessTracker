import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fitness_app/theme.dart';

/// A compact water-tracking strip for the dashboard.
/// Shows a fill bar + glass icons + add/remove buttons.
class WaterTrackerWidget extends StatelessWidget {
  const WaterTrackerWidget({
    super.key,
    required this.mlConsumed,
    required this.mlGoal,
    required this.onAdd,
    required this.onRemove,
  });

  final int mlConsumed;
  final int mlGoal;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const int _glassSize = 250; // ml per glass

  @override
  Widget build(BuildContext context) {
    final safeGoal = mlGoal <= 0 ? 2000 : mlGoal;
    final pct = (mlConsumed / safeGoal).clamp(0.0, 1.0);
    final glasses = (mlConsumed / _glassSize).floor();
    final goalGlasses = (safeGoal / _glassSize).ceil();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Water drop icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.water_drop_rounded,
            color: AppColors.secondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Water',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '$mlConsumed / ${safeGoal} ml',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Progress bar
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: pct),
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(
                          color: isDark
                              ? Colors.white.withValues(alpha: .1)
                              : Colors.black.withValues(alpha: .07),
                        ),
                        FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.secondary, Color(0xFF0096C7)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Glass icons
              Wrap(
                spacing: 4,
                children: List.generate(goalGlasses.clamp(0, 10), (i) {
                  final filled = i < glasses;
                  return Icon(
                    filled
                        ? Icons.local_drink_rounded
                        : Icons.local_drink_outlined,
                    size: 14,
                    color: filled
                        ? AppColors.secondary
                        : (isDark
                            ? Colors.white24
                            : Colors.black.withValues(alpha: .2)),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Minus
        Semantics(
          label: 'Remove 250ml water',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: mlConsumed <= 0
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onRemove();
                  },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: .08)
                    : Colors.black.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.remove,
                size: 16,
                color: mlConsumed <= 0
                    ? (isDark ? Colors.white24 : Colors.black26)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Plus
        Semantics(
          label: 'Add 250ml water',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.lightImpact();
              onAdd();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: AppColors.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
