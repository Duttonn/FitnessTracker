import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/theme.dart';

class MacroDonutChart extends StatelessWidget {
  const MacroDonutChart({
    super.key,
    required this.carbsPct, // 0.0–1.0
    required this.fatPct, // 0.0–1.0
    required this.proteinPct, // 0.0–1.0
    required this.totalCalories,
    this.size = 180,
    this.radiusScale = 0.65,
  });

  final double carbsPct;
  final double fatPct;
  final double proteinPct;
  final int totalCalories;
  final double size;
  final double radiusScale;

  @override
  Widget build(BuildContext context) {
    final data = _sections();
    final effectiveSize = size * radiusScale;
    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90, // start at top (12 o’clock)
              centerSpaceRadius: effectiveSize * 0.35, // hole size (donut)
              sectionsSpace: 2, // gap between slices
              borderData: FlBorderData(show: false),
              sections: data,
            ),
            swapAnimationDuration: const Duration(milliseconds: 600),
            swapAnimationCurve: Curves.easeOut,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_formatKcal(totalCalories)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'calories',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _sections() {
    // guard against rounding issues: clamp to >= 0
    final carbs = (carbsPct.clamp(0, 1) * 100).toDouble();
    final fat = (fatPct.clamp(0, 1) * 100).toDouble();
    final protein = (proteinPct.clamp(0, 1) * 100).toDouble();

    return [
      PieChartSectionData(
        value: carbs,
        color: AppColors.carbs,
        radius: size * radiusScale * 0.28,
        showTitle: false,
      ),
      PieChartSectionData(
        value: fat,
        color: AppColors.fat,
        radius: size * radiusScale * 0.28,
        showTitle: false,
      ),
      PieChartSectionData(
        value: protein,
        color: AppColors.protein,
        radius: size * radiusScale * 0.28,
        showTitle: false,
      ),
    ];
  }

  String _formatKcal(int v) {
    // 1 845 look like the HTML demo (thin space grouping)
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('\u2009'); // thin space
    }
    return buf.toString();
  }
}
