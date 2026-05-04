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
  int _page = 0;
  WeightRange _calRange = WeightRange.d30;
  int _calPage = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = [...state.weights]
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final calKeys = state.entriesByDay.keys.toList()..sort();
    final allCalories = <_CalEntry>[
      for (final dk in calKeys)
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _WeightCard(
              allWeights: all,
              weightGoal: state.goals.weightGoal,
              range: _range,
              page: _page,
              onRangeChanged: (r) => setState(() {
                _range = r;
                _page = 0;
              }),
              onPageChanged: (p) => setState(() => _page = p),
              onAddWeight: () => _showWeightDialog(context),
              onSetGoal: () => _showWeightGoalDialog(context, state),
              onEditWeight: (e) => _showWeightDialog(context, editing: e),
              onDeleteWeight: (e) {
                final app = context.read<AppState>();
                app.deleteWeight(e.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Deleted ${e.kg.toStringAsFixed(1)} kg entry'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => app.addWeight(e.kg,
                          at: e.loggedAt, id: e.id),
                    ),
                  ),
                );
              },
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

  // ── Add / Edit weight dialog ──────────────────────────────────────────────
  Future<void> _showWeightDialog(
    BuildContext context, {
    WeightEntry? editing,
  }) async {
    final controller = TextEditingController(
      text: editing != null ? editing.kg.toStringAsFixed(1) : '',
    );
    DateTime when = editing?.loggedAt ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text(editing == null ? 'Log weight' : 'Edit weight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
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
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSt(() => when = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              when.hour,
                              when.minute,
                            ));
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
                final raw =
                    controller.text.trim().replaceAll(',', '.');
                final v = double.tryParse(raw);
                if (v == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid number (e.g. 78.4)'),
                    ),
                  );
                  return;
                }
                final app = context.read<AppState>();
                if (editing == null) {
                  app.addWeight(v, at: when);
                  if (mounted) setState(() => _page = 0);
                } else {
                  app.updateWeight(editing.id, kg: v, at: when);
                }
                Navigator.pop(c);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  // ── Weight goal dialog ────────────────────────────────────────────────────
  Future<void> _showWeightGoalDialog(
      BuildContext context, AppState state) async {
    final existing = state.goals.weightGoal;
    final sortedWeights = [...state.weights]
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    bool isRateMode = existing?.isRateBased ?? false;
    final targetKgCtrl = TextEditingController(
      text: existing != null && !existing.isRateBased ? existing.targetKg.toStringAsFixed(1) : '',
    );
    final rateCtrl = TextEditingController(
      text: existing?.rateKgPerWeek?.toStringAsFixed(2) ?? '',
    );
    final manualKgCtrl = TextEditingController(
      text: existing?.startKg?.toStringAsFixed(1) ?? '',
    );
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? targetDate = existing?.targetDate;

    // Resolve start weight from a given date against the weight history.
    // Returns (kg, isEstimated, needsManual).
    ({double? kg, bool estimated, bool needsManual}) resolveStart(DateTime date) {
      if (sortedWeights.isEmpty) return (kg: null, estimated: false, needsManual: true);

      final dayStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';

      // Exact match on that day
      for (final w in sortedWeights) {
        final ws = '${w.loggedAt.year}-${w.loggedAt.month.toString().padLeft(2,'0')}-${w.loggedAt.day.toString().padLeft(2,'0')}';
        if (ws == dayStr) return (kg: w.kg, estimated: false, needsManual: false);
      }

      // Interpolate between nearest before/after
      WeightEntry? before, after;
      for (final w in sortedWeights) {
        if (!w.loggedAt.isAfter(date)) {
          if (before == null || w.loggedAt.isAfter(before.loggedAt)) before = w;
        } else {
          if (after == null || w.loggedAt.isBefore(after.loggedAt)) after = w;
        }
      }
      if (before != null && after != null) {
        final total = after.loggedAt.difference(before.loggedAt).inSeconds;
        final elapsed = date.difference(before.loggedAt).inSeconds;
        final kg = total > 0
            ? before.kg + (after.kg - before.kg) * elapsed / total
            : before.kg;
        return (kg: kg, estimated: true, needsManual: false);
      }
      if (before != null) return (kg: before.kg, estimated: true, needsManual: false);
      if (after != null) return (kg: after.kg, estimated: true, needsManual: false);
      return (kg: null, estimated: false, needsManual: true);
    }

    var resolved = resolveStart(startDate);

    String _fmt(DateTime? d) => d == null
        ? 'not set'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('Weight Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${_fmt(startDate)}', style: const TextStyle(fontSize: 13))),
                    TextButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: c,
                          initialDate: startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                          lastDate: DateTime.now(),
                        );
                        if (p != null) setSt(() {
                          startDate = p;
                          resolved = resolveStart(p);
                        });
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (resolved.needsManual) ...[
                  TextField(
                    controller: manualKgCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Starting weight (kg)',
                      hintText: 'No data for this date — enter manually',
                      helperText: 'No recorded weight found for this date',
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: resolved.estimated
                          ? Colors.orange.withValues(alpha: .08)
                          : AppColors.success.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: resolved.estimated
                            ? Colors.orange.withValues(alpha: .3)
                            : AppColors.success.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          resolved.estimated ? Icons.auto_graph : Icons.check_circle_outline,
                          size: 16,
                          color: resolved.estimated ? Colors.orange : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${resolved.kg!.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: resolved.estimated ? Colors.orange.shade800 : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          resolved.estimated ? '(estimated)' : '(recorded)',
                          style: TextStyle(
                            fontSize: 12,
                            color: resolved.estimated ? Colors.orange.shade700 : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24),
                // Mode toggle
                Row(
                  children: [
                    const Text('Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                    const Spacer(),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Fixed weight')),
                        ButtonSegment(value: true, label: Text('Weekly rate')),
                      ],
                      selected: {isRateMode},
                      onSelectionChanged: (s) => setSt(() => isRateMode = s.first),
                      style: ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isRateMode) ...[
                  TextField(
                    controller: rateCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Rate (kg/week)',
                      hintText: 'e.g. +0.15 or -0.20',
                      helperText: 'Positive = gain, negative = loss',
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: targetKgCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Target weight (kg)', hintText: 'e.g. 80.0'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('By: ${_fmt(targetDate)}', style: const TextStyle(fontSize: 13))),
                      TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: c,
                            initialDate: targetDate ?? DateTime.now().add(const Duration(days: 60)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                          );
                          if (p != null) setSt(() => targetDate = p);
                        },
                        child: Text(targetDate == null ? 'Pick date' : 'Change'),
                      ),
                      if (targetDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear',
                          onPressed: () => setSt(() => targetDate = null),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () { context.read<AppState>().setWeightGoal(null); Navigator.pop(c); },
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Remove Goal'),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final startKg = resolved.needsManual
                    ? double.tryParse(manualKgCtrl.text.trim().replaceAll(',', '.'))
                    : resolved.kg;
                if (startKg == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your starting weight')));
                  return;
                }
                if (isRateMode) {
                  final rate = double.tryParse(rateCtrl.text.trim().replaceAll(',', '.'));
                  if (rate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid rate (e.g. 0.15)')));
                    return;
                  }
                  context.read<AppState>().setWeightGoal(WeightGoal(
                    targetKg: startKg, // unused for rate mode but required
                    startKg: startKg,
                    startDate: startDate,
                    rateKgPerWeek: rate,
                  ));
                } else {
                  final target = double.tryParse(targetKgCtrl.text.trim().replaceAll(',', '.'));
                  if (target == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid target weight')));
                    return;
                  }
                  context.read<AppState>().setWeightGoal(WeightGoal(
                    targetKg: target,
                    targetDate: targetDate,
                    startKg: startKg,
                    startDate: startDate,
                  ));
                }
                Navigator.pop(c);
              },
              child: const Text('Save Goal'),
            ),
          ],
        ),
      ),
    );
    targetKgCtrl.dispose();
    manualKgCtrl.dispose();
    rateCtrl.dispose();
  }
}



class _WeightCard extends StatelessWidget {
  final List<WeightEntry> allWeights;
  final WeightGoal? weightGoal;
  final WeightRange range;
  final int page;
  final ValueChanged<WeightRange> onRangeChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAddWeight;
  final VoidCallback onSetGoal;
  final ValueChanged<WeightEntry> onEditWeight;
  final ValueChanged<WeightEntry> onDeleteWeight;
  const _WeightCard({
    required this.allWeights,
    this.weightGoal,
    required this.range,
    required this.page,
    required this.onRangeChanged,
    required this.onPageChanged,
    required this.onAddWeight,
    required this.onSetGoal,
    required this.onEditWeight,
    required this.onDeleteWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (allWeights.isEmpty) {
      return _Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
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
                Semantics(
                  label: 'Log weight',
                  child: IconButton(
                    tooltip: 'Log weight',
                    onPressed: onAddWeight,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Icon(Icons.monitor_weight_outlined,
                size: 52, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No weight logged yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.black45,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Track your weight progress over time',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black38,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onAddWeight,
                  icon: const Icon(Icons.add),
                  label: const Text('Log Weight'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onSetGoal,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Set Goal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    final maxPage = _maxPageForRange(allWeights, range);
    final clampedPage = range == WeightRange.all ? 0 : page.clamp(0, maxPage);
    if (clampedPage != page) onPageChanged(clampedPage);

    final filtered = _applyRange(allWeights, range, clampedPage);
    final smoothAll = _smoothCentered(allWeights, window: 7);
    final smoothFiltered = smoothAll
        .where(
          (e) =>
              filtered.first.loggedAt.compareTo(e.loggedAt) <= 0 &&
              filtered.last.loggedAt.compareTo(e.loggedAt) >= 0,
        )
        .toList();

    final startRaw = filtered.first.kg;
    final endRaw = filtered.last.kg;
    final deltaRaw = endRaw - startRaw;
    final startSm = smoothFiltered.first.kg;
    final endSm = smoothFiltered.last.kg;
    final deltaSm = endSm - startSm;

    final yBounds = _boundsFor(filtered, smoothFiltered, weightGoal);

    final canPrev = range != WeightRange.all && clampedPage < maxPage;
    final canNext = range != WeightRange.all && clampedPage > 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                tooltip: weightGoal != null ? 'Edit Goal' : 'Set Goal',
                icon: Icon(weightGoal != null ? Icons.flag : Icons.flag_outlined, color: AppColors.primary),
                onPressed: onSetGoal,
              ),
              IconButton(
                tooltip: 'Add Weight',
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
                  label: 'Current',
                  value: '${endRaw.toStringAsFixed(1)} kg',
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onSetGoal,
                  behavior: HitTestBehavior.opaque,
                  child: _StatTile(
                    label: 'Goal',
                    value: weightGoal == null
                        ? 'Set Goal'
                        : weightGoal!.isRateBased
                            ? '${weightGoal!.rateKgPerWeek! >= 0 ? '+' : ''}${weightGoal!.rateKgPerWeek!.toStringAsFixed(2)} kg/w'
                            : '${weightGoal!.targetKg.toStringAsFixed(1)} kg',
                    valueColor: AppColors.primary,
                  ),
                ),
              ),
              if (weightGoal != null && allWeights.isNotEmpty)
                Expanded(
                  child: _StatTile(
                    label: 'On Track',
                    value: '${_targetToday(allWeights, weightGoal!).toStringAsFixed(1)} kg',
                    valueColor: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DeltaChip(
                label: 'True',
                value: _deltaString(deltaRaw),
              ),
              _DeltaChip(
                label: 'Smoothed',
                value: _deltaString(deltaSm),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'History',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...filtered.reversed.map((e) => Dismissible(
                key: Key(e.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => onDeleteWeight(e),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.danger,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text('${e.kg.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_formatFullDay(e.loggedAt)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.black26),
                  onTap: () => onEditWeight(e),
                ),
              )),
        ],
      ),
    );
  }

  static double _targetToday(List<WeightEntry> all, WeightGoal goal) {
    final startDate = goal.startDate ?? (all.isNotEmpty ? all.first.loggedAt : DateTime.now());
    final startKg = goal.startKg ?? (all.isNotEmpty ? all.first.kg : goal.targetKg);
    if (goal.isRateBased) {
      final weeks = DateTime.now().difference(startDate).inDays / 7.0;
      return startKg + goal.rateKgPerWeek! * weeks;
    }
    if (goal.targetDate == null) return goal.targetKg;
    final totalDays = goal.targetDate!.difference(startDate).inDays;
    if (totalDays <= 0) return goal.targetKg;
    final elapsed = DateTime.now().difference(startDate).inDays.clamp(0, totalDays);
    return startKg + (goal.targetKg - startKg) * elapsed / totalDays;
  }

  static String _deltaString(double d) {
    final sign = d > 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(1)} kg';
  }

  static ({double min, double max}) _boundsFor(
    List<WeightEntry> raw,
    List<WeightEntry> smooth,
    WeightGoal? goal,
  ) {
    final all = [...raw, ...smooth];
    double minY = all.first.kg, maxY = all.first.kg;
    for (final e in all) {
      minY = math.min(minY, e.kg);
      maxY = math.max(maxY, e.kg);
    }
    // Include the goal trajectory only if it falls within the visible window
    if (goal != null && raw.isNotEmpty) {
      final windowStart = raw.first.loggedAt;
      final windowEnd = raw.last.loggedAt;
      final startDate = goal.startDate ?? windowStart;
      final startKg = goal.startKg ?? raw.first.kg;

      double goalKgAt(DateTime d) {
        if (goal.isRateBased) {
          return startKg + goal.rateKgPerWeek! * d.difference(startDate).inDays / 7.0;
        }
        if (goal.targetDate == null) return goal.targetKg;
        final total = goal.targetDate!.difference(startDate).inDays;
        if (total <= 0) return goal.targetKg;
        final elapsed = d.difference(startDate).inDays.clamp(0, total);
        return startKg + (goal.targetKg - startKg) * elapsed / total;
      }

      // Clamp dates to window and compute kg at those points
      for (final d in [windowStart, windowEnd]) {
        if (!d.isBefore(startDate) &&
            (goal.targetDate == null || !d.isAfter(goal.targetDate!))) {
          final kg = goalKgAt(d);
          minY = math.min(minY, kg);
          maxY = math.max(maxY, kg);
        }
      }
    }
    return (min: minY * 0.99, max: maxY * 1.01);
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
    final lastDate = all.last.loggedAt;
    final lastWindowEnd = DateTime(lastDate.year, lastDate.month, lastDate.day, 23, 59, 59);
    final to = lastWindowEnd.subtract(Duration(days: w * page));
    final from = to.subtract(Duration(days: w));
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

    final bars = [
      LineChartBarData(
        spots: smoothSpots,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        color: smoothColor,
        barWidth: 3.5,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: rawSpots,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        color: primary,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: primary.withValues(alpha: .15),
        ),
      ),
    ];

    if (weightGoal != null && rawSpots.isNotEmpty) {
      final goalStartDate = weightGoal!.startDate ?? allWeights.first.loggedAt;
      final startKg = weightGoal!.startKg ?? allWeights.first.kg;
      final startX = goalStartDate.difference(base).inDays.toDouble();
      final chartLeft = rawSpots.first.x;
      final chartRight = rawSpots.last.x;

      if (weightGoal!.isRateBased) {
        // Indefinite rate: trajectory extends across the visible window
        double rateKg(double x) =>
            startKg + weightGoal!.rateKgPerWeek! * (x - startX) / 7.0;
        final visStart = startX.clamp(chartLeft, chartRight);
        final visEnd = chartRight;
        if (visStart <= visEnd) {
          bars.add(LineChartBarData(
            spots: [FlSpot(visStart, rateKg(visStart)), FlSpot(visEnd, rateKg(visEnd))],
            isCurved: false,
            color: AppColors.success,
            barWidth: 2,
            dashArray: [8, 4],
            dotData: const FlDotData(show: false),
          ));
        }
      } else if (weightGoal!.targetDate != null) {
        // Fixed target: from goal start → target date
        final endX = weightGoal!.targetDate!.difference(base).inDays.toDouble();
        final endKg = weightGoal!.targetKg;
        double lerpKg(double x) {
          if (endX == startX) return endKg;
          return startKg + (endKg - startKg) * (x - startX) / (endX - startX);
        }
        final visStart = startX.clamp(chartLeft, chartRight);
        final visEnd = endX.clamp(chartLeft, chartRight);
        if (visStart < visEnd) {
          bars.add(LineChartBarData(
            spots: [FlSpot(visStart, lerpKg(visStart)), FlSpot(visEnd, lerpKg(visEnd))],
            isCurved: false,
            color: AppColors.success,
            barWidth: 2,
            dashArray: [8, 4],
            dotData: const FlDotData(show: false),
          ));
        }
      } else {
        // No target date, no rate — flat reference line at target kg
        bars.add(LineChartBarData(
          spots: [FlSpot(chartLeft, weightGoal!.targetKg), FlSpot(chartRight, weightGoal!.targetKg)],
          isCurved: false,
          color: AppColors.success,
          barWidth: 2,
          dashArray: [8, 4],
          dotData: const FlDotData(show: false),
        ));
      }
    }

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
            interval: (rawSpots.isEmpty ? 1 : (rawSpots.last.x / 4).clamp(1, 60)),
            getTitlesWidget: (v, meta) => Text(
              _formatDay(base.add(Duration(days: v.round()))),
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, meta) => Text(
              v.toStringAsFixed(0),
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
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
      lineBarsData: bars,
    );
  }

  static String _formatDay(DateTime d) => '${d.month}/${d.day}';
  static String _formatFullDay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
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
  final Color? valueColor;
  const _StatTile({required this.label, required this.value, this.valueColor});
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
            ).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
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
