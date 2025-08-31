import 'package:flutter/material.dart';

// ==== SHARED: view mode + tiny toggle pill ====
/// Indicates whether macro bars display consumed amounts or remaining amounts.
enum MacroViewMode { consumed, remaining }

/// Simple toggle using ChoiceChips to switch between macro view modes.
class MacroModeToggle extends StatelessWidget {
  final MacroViewMode value;
  final ValueChanged<MacroViewMode> onChanged;
  const MacroModeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(MacroViewMode m, String label) => ChoiceChip(
      label: Text(label),
      selected: value == m,
      onSelected: (_) => onChanged(m),
    );
    return Wrap(
      spacing: 8,
      children: [
        chip(MacroViewMode.consumed, 'Consumed'),
        chip(MacroViewMode.remaining, 'Remaining'),
      ],
    );
  }
}

// Helper to compute bar value / color / right-side text for one macro row.
class _MacroPresent {
  final double barValue; // value to pass to MacroProgressBar.value
  final double goal; // pass through to MacroProgressBar.goal
  final String rightText; // e.g. "48/176g" or "128 left" / "Over by 12g"
  final Color color; // normal color or red when over limit
  const _MacroPresent(this.barValue, this.goal, this.rightText, this.color);
}

_MacroPresent presentMacro({
  required double consumed, // today’s amount
  required double goal,
  required Color baseColor,
  required MacroViewMode mode,
  String unit = 'g', // or 'kcal'
}) {
  final double over = (consumed - goal).clamp(0, double.infinity).toDouble();
  final double remaining = (goal - consumed)
      .clamp(0, double.infinity)
      .toDouble();
  final bool isOver = consumed > goal;

  String fmt(double v) =>
      unit == 'kcal' ? v.toStringAsFixed(0) : v.toStringAsFixed(0);

  if (mode == MacroViewMode.consumed) {
    final double barVal = goal == 0
        ? 0.0
        : consumed
              .clamp(0, goal)
              .toDouble(); // clamp so the bar doesn’t overflow
    final String txt = isOver
        ? '${fmt(consumed)}/${fmt(goal)}$unit (+${fmt(over)})'
        : '${fmt(consumed)}/${fmt(goal)}$unit';
    return _MacroPresent(
      barVal,
      goal,
      txt,
      isOver ? Colors.redAccent : baseColor,
    );
  } else {
    // Remaining mode
    final String txt = isOver
        ? 'Over by ${fmt(over)}$unit'
        : '${fmt(remaining)} left';
    // Bar shows what’s left (0 when over)
    return _MacroPresent(
      remaining,
      goal,
      txt,
      isOver ? Colors.redAccent : baseColor,
    );
  }
}
