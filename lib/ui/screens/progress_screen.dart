import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/layout.dart';

enum WeightRange { d7, d30, all }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  WeightRange _range = WeightRange.d30;
  int _page = 0; // 0 = latest window, increases as we go back in time
  // Calories controls
  WeightRange _calRange = WeightRange.d30;
  int _calPage = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = [...state.weights]
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    // Calories dataset (daily totals)
    final calKeys = state.entriesByDay.keys.toList()..sort();
    final cutoffCalorie = DateTime(
      2025,
      5,
      7,
    ); // exclude days before 7 May 2025
    final allCalories = <_CalEntry>[
      for (final dk in calKeys)
        if (!DateTime.parse(dk).isBefore(cutoffCalorie))
          _CalEntry(
            day: DateTime.parse(dk),
            kcal: state.totalsForDay(dk)['kcal'] as int,
          ),
    ];
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomReserve(context)),
        child: Column(
          children: [
            _WeightCard(
              allWeights: all,
              range: _range,
              page: _page,
              onRangeChanged: (r) => setState(() {
                _range = r;
                _page = 0; // reset on range change
              }),
              onPageChanged: (p) => setState(() => _page = p),
              onAddWeight: () => _showAddWeightDialog(context),
            ),
            const SizedBox(height: 16),
            _CaloriesCard(
              all: allCalories,
              range: _calRange,
              page: _calPage,
              onRangeChanged: (r) => setState(() {
                _calRange = r;
                _calPage = 0;
              }),
              onPageChanged: (p) => setState(() => _calPage = p),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWeightDialog(BuildContext context) async {
    final controller = TextEditingController();
    DateTime when = DateTime.now();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Log weight'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: 'e.g. 78.4',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: c,
                      initialDate: when,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      when = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        when.hour,
                        when.minute,
                      );
                      (c as Element).markNeedsBuild();
                    }
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Accept both comma and dot as decimal separator
              final raw = controller.text.trim().replaceAll(',', '.');
              final v = double.tryParse(raw);
              if (v != null) {
                context.read<AppState>().addWeight(v, at: when);
                if (mounted) {
                  setState(() {
                    _page =
                        0; // reset to latest window so new weight is visible
                  });
                }
                Navigator.pop(c);
              } else {
                // Provide feedback instead of silently failing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a valid number (use a dot, e.g. 78.4)',
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final List<WeightEntry> allWeights; // full dataset
  final WeightRange range;
  final int page; // 0 = latest window
  final ValueChanged<WeightRange> onRangeChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAddWeight;
  const _WeightCard({
    required this.allWeights,
    required this.range,
    required this.page,
    required this.onRangeChanged,
    required this.onPageChanged,
    required this.onAddWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (allWeights.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Weight Progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(onPressed: onAddWeight, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'No weights logged yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onAddWeight,
              icon: const Icon(Icons.add),
              label: const Text('Log Weight'),
            ),
          ],
        ),
      );
    }

    // Compute paging limits
    final maxPage = _maxPageForRange(allWeights, range);
    final clampedPage = range == WeightRange.all ? 0 : page.clamp(0, maxPage);
    if (clampedPage != page) onPageChanged(clampedPage);

    final filtered = _applyRange(allWeights, range, clampedPage);

    // Smooth using full dataset (better edges), then filter smoothed values to range
    final smoothAll = _smoothCentered(allWeights, window: 7);
    final smoothFiltered = smoothAll
        .where(
          (e) =>
              filtered.first.loggedAt.compareTo(e.loggedAt) <= 0 &&
              filtered.last.loggedAt.compareTo(e.loggedAt) >= 0,
        )
        .toList();

    // Raw (unsmoothed) start/end for true delta
    final startRaw = filtered.first.kg;
    final endRaw = filtered.last.kg;
    final deltaRaw = endRaw - startRaw;

    final startSm = smoothFiltered.first.kg;
    final endSm = smoothFiltered.last.kg;
    final deltaSm = endSm - startSm;

    final yBounds = _boundsFor(filtered, smoothFiltered);

    final canPrev =
        range != WeightRange.all && clampedPage < maxPage; // go back in time
    final canNext =
        range != WeightRange.all &&
        clampedPage > 0; // forward (towards present)

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weight Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onPressed: onAddWeight,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RangeWithPager(
            value: range,
            onChanged: onRangeChanged,
            canPrev: canPrev,
            canNext: canNext,
            onPrev: () => onPageChanged(clampedPage + 1),
            onNext: () => onPageChanged(clampedPage - 1),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: LineChart(
              _buildChartData(context, filtered, smoothFiltered, yBounds),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Starting',
                  value: '${startRaw.toStringAsFixed(1)} kg',
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: 'Current',
                  value: '${endRaw.toStringAsFixed(1)} kg',
                ),
              ),
              // Removed redundant 'Change' tile (delta shown below in chips)
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DeltaChip(
                  label: 'True progress',
                  value: _deltaString(deltaRaw),
                ),
                const SizedBox(height: 8),
                _DeltaChip(
                  label: 'Smoothed progress',
                  value: _deltaString(deltaSm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _deltaString(double d) {
    final sign = d > 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(1)} kg';
  }

  static ({double min, double max}) _boundsFor(
    List<WeightEntry> raw,
    List<WeightEntry> smooth,
  ) {
    final all = [...raw, ...smooth];
    double minY = all.first.kg, maxY = all.first.kg;
    for (final e in all) {
      minY = math.min(minY, e.kg);
      maxY = math.max(maxY, e.kg);
    }
    final pad = (maxY - minY).clamp(0.8, 4.0);
    return (min: minY - pad, max: maxY + pad);
  }

  static int _windowDays(WeightRange r) => switch (r) {
    WeightRange.d7 => 7,
    WeightRange.d30 => 30,
    WeightRange.all => 0,
  };

  static int _maxPageForRange(List<WeightEntry> all, WeightRange r) {
    if (r == WeightRange.all || all.isEmpty) return 0;
    final daysTotal = all.last.loggedAt.difference(all.first.loggedAt).inDays;
    final w = _windowDays(r);
    return (daysTotal / w).floor().clamp(0, 1000000);
  }

  static List<WeightEntry> _applyRange(
    List<WeightEntry> all,
    WeightRange range,
    int page,
  ) {
    if (all.isEmpty) return const [];
    if (range == WeightRange.all) return all;

    final w = _windowDays(range);
    final last = all.last.loggedAt.subtract(Duration(days: w * page));
    final from = last.subtract(Duration(days: w));
    final to = last;
    return all
        .where((e) => !e.loggedAt.isBefore(from) && !e.loggedAt.isAfter(to))
        .toList();
  }

  static List<WeightEntry> _smoothCentered(
    List<WeightEntry> items, {
    int window = 7,
  }) {
    if (items.isEmpty) return const [];
    final k = window ~/ 2;
    final out = <WeightEntry>[];
    for (var i = 0; i < items.length; i++) {
      final from = math.max(0, i - k);
      final to = math.min(items.length - 1, i + k);
      final slice = items.sublist(from, to + 1);
      final avg = slice.map((e) => e.kg).reduce((a, b) => a + b) / slice.length;
      out.add(WeightEntry(loggedAt: items[i].loggedAt, kg: avg));
    }
    return out;
  }

  LineChartData _buildChartData(
    BuildContext context,
    List<WeightEntry> raw,
    List<WeightEntry> smooth,
    ({double min, double max}) y,
  ) {
    final base = raw.first.loggedAt;
    final rawSpots = raw
        .map((e) => FlSpot(e.loggedAt.difference(base).inDays.toDouble(), e.kg))
        .toList();
    final smoothSpots = smooth
        .map((e) => FlSpot(e.loggedAt.difference(base).inDays.toDouble(), e.kg))
        .toList();
    final primary = AppColors.primary;
    final smoothColor = Colors.black.withValues(alpha: .45);
    return LineChartData(
      minY: y.min,
      maxY: y.max,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((y.max - y.min) / 4).clamp(0.5, 5.0),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: (rawSpots.isEmpty
                ? 1
                : (rawSpots.last.x / 4).clamp(1, 60)),
            getTitlesWidget: (v, meta) => Text(
              _formatDay(base.add(Duration(days: v.round()))),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, meta) => Text(
              v.toStringAsFixed(0),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots
              .map(
                (s) => LineTooltipItem(
                  '${s.y.toStringAsFixed(1)} kg',
                  Theme.of(context).textTheme.bodyMedium!,
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: [
        // Smoothed line
        LineChartBarData(
          spots: smoothSpots,
          isCurved: true,
          color: smoothColor,
          barWidth: 3.5,
          dotData: const FlDotData(show: false),
        ),
        // Raw line with area fill
        LineChartBarData(
          spots: rawSpots,
          isCurved: true,
          color: primary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: primary.withValues(alpha: .15),
          ),
        ),
      ],
    );
  }

  static String _formatDay(DateTime d) => '${d.month}/${d.day}';
}

/* --------------------------- CALORIES CARD --------------------------- */
class _CalEntry {
  final DateTime day;
  final int kcal;
  const _CalEntry({required this.day, required this.kcal});
}

class _Point {
  final DateTime ts;
  final double v;
  const _Point({required this.ts, required this.v});
}

class _CaloriesCard extends StatelessWidget {
  final List<_CalEntry> all;
  final WeightRange range;
  final int page; // 0 = latest window
  final ValueChanged<WeightRange> onRangeChanged;
  final ValueChanged<int> onPageChanged;
  const _CaloriesCard({
    required this.all,
    required this.range,
    required this.page,
    required this.onRangeChanged,
    required this.onPageChanged,
  });
  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calories Over Time',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'No calories logged yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    final first = all.first.day;
    final last = all.last.day;
    final maxPage = _maxPageForRange(first, last, range);
    final clampedPage = range == WeightRange.all ? 0 : page.clamp(0, maxPage);
    if (clampedPage != page) onPageChanged(clampedPage);
    final filtered = _applyRange(all, range, clampedPage);
    // Smooth calories using point-based smoother
    final pointsAll = all
        .map((e) => _Point(ts: e.day, v: e.kcal.toDouble()))
        .toList();
    final smoothAll = _smoothCentered(pointsAll, window: 7);
    final smoothFiltered = smoothAll
        .where(
          (e) =>
              filtered.first.day.compareTo(e.ts) <= 0 &&
              filtered.last.day.compareTo(e.ts) >= 0,
        )
        .toList();
    if (smoothFiltered.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calories Over Time',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _RangeWithPager(
              value: range,
              onChanged: onRangeChanged,
              canPrev: clampedPage < maxPage,
              canNext: clampedPage > 0,
              onPrev: () => onPageChanged(clampedPage + 1),
              onNext: () => onPageChanged(clampedPage - 1),
            ),
            const SizedBox(height: 12),
            Text(
              'No data in this window.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    final start = smoothFiltered.first.v;
    final end = smoothFiltered.last.v;
    final delta = end - start;
    final y = _boundsFor(smoothFiltered);
    final canPrev = range != WeightRange.all && clampedPage < maxPage;
    final canNext = range != WeightRange.all && clampedPage > 0;
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Calories Over Time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RangeWithPager(
            value: range,
            onChanged: onRangeChanged,
            canPrev: canPrev,
            canNext: canNext,
            onPrev: () => onPageChanged(clampedPage + 1),
            onNext: () => onPageChanged(clampedPage - 1),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: LineChart(_buildChart(context, smoothFiltered, y)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Starting',
                  value: '${start.toStringAsFixed(0)} kcal',
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: 'Current',
                  value: '${end.toStringAsFixed(0)} kcal',
                ),
              ),
              Expanded(
                child: _StatTile(label: 'Change', value: _deltaString(delta)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: _DeltaChip(
              label: 'Caloric change',
              value: _deltaString(delta),
            ),
          ),
        ],
      ),
    );
  }

  static String _deltaString(double d) {
    final sign = d > 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(0)} kcal';
  }

  static ({double min, double max}) _boundsFor(List<_Point> pts) {
    double minY = pts.first.v, maxY = pts.first.v;
    for (final p in pts) {
      minY = math.min(minY, p.v);
      maxY = math.max(maxY, p.v);
    }
    final pad = (maxY - minY).clamp(40.0, 300.0);
    return (min: math.max(0, minY - pad), max: maxY + pad);
  }

  static List<_Point> _smoothCentered(List<_Point> items, {int window = 7}) {
    if (items.isEmpty) return const [];
    final k = window ~/ 2;
    final out = <_Point>[];
    for (var i = 0; i < items.length; i++) {
      final from = math.max(0, i - k);
      final to = math.min(items.length - 1, i + k);
      final slice = items.sublist(from, to + 1);
      final avg = slice.map((e) => e.v).reduce((a, b) => a + b) / slice.length;
      out.add(_Point(ts: items[i].ts, v: avg));
    }
    return out;
  }

  static int _windowDays(WeightRange r) => switch (r) {
    WeightRange.d7 => 7,
    WeightRange.d30 => 30,
    WeightRange.all => 0,
  };
  static int _maxPageForRange(DateTime first, DateTime last, WeightRange r) {
    if (r == WeightRange.all) return 0;
    final daysTotal = last.difference(first).inDays;
    final w = _windowDays(r);
    return (daysTotal / w).floor().clamp(0, 1000000);
  }

  static List<_CalEntry> _applyRange(
    List<_CalEntry> all,
    WeightRange range,
    int page,
  ) {
    if (all.isEmpty) return const [];
    if (range == WeightRange.all) return all;
    final w = _windowDays(range);
    final last = all.last.day.subtract(Duration(days: w * page));
    final from = last.subtract(Duration(days: w));
    final to = last;
    return all
        .where((e) => !e.day.isBefore(from) && !e.day.isAfter(to))
        .toList();
  }

  LineChartData _buildChart(
    BuildContext context,
    List<_Point> smooth,
    ({double min, double max}) y,
  ) {
    final base = smooth.first.ts;
    final spots = smooth
        .map((e) => FlSpot(e.ts.difference(base).inDays.toDouble(), e.v))
        .toList();
    final color = AppColors.primary;
    return LineChartData(
      minY: y.min,
      maxY: y.max,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((y.max - y.min) / 4).clamp(50.0, 600.0),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: (spots.isEmpty ? 1 : (spots.last.x / 4).clamp(1, 60)),
            getTitlesWidget: (v, meta) => Text(
              _formatDay(base.add(Duration(days: v.round()))),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => Text(
              v.toStringAsFixed(0),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots
              .map(
                (s) => LineTooltipItem(
                  '${s.y.toStringAsFixed(0)} kcal',
                  Theme.of(context).textTheme.bodyMedium!,
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: .15),
          ),
        ),
      ],
    );
  }

  static String _formatDay(DateTime d) => '${d.month}/${d.day}';
}

class _RangeWithPager extends StatelessWidget {
  final WeightRange value;
  final ValueChanged<WeightRange> onChanged;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _RangeWithPager({
    required this.value,
    required this.onChanged,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) {
    Widget chip(WeightRange r, String label) => ChoiceChip(
      label: Text(label),
      selected: value == r,
      onSelected: (_) => onChanged(r),
    );
    final showPager = value != WeightRange.all;
    return Row(
      children: [
        if (showPager)
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canPrev ? onPrev : null,
            tooltip:
                'Previous ${value == WeightRange.d7 ? "7 days" : "30 days"}',
          ),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              chip(WeightRange.d7, '7D'),
              chip(WeightRange.d30, '30D'),
              chip(WeightRange.all, 'All'),
            ],
          ),
        ),
        if (showPager)
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canNext ? onNext : null,
            tooltip: 'Next ${value == WeightRange.d7 ? "7 days" : "30 days"}',
          ),
      ],
    );
  }
}

// Removed old _RangeSelector (replaced by _RangeWithPager)

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final String value;
  const _DeltaChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value'),
      backgroundColor: AppColors.primary.withValues(alpha: .1),
      side: BorderSide(color: AppColors.primary.withValues(alpha: .2)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: appCardDecoration(),
    padding: const EdgeInsets.all(20),
    child: child,
  );
}
