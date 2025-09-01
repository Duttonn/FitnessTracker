import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/macro_progress_bar.dart';
import 'package:flutter_fitness_app/ui/widgets/donut_chart.dart';
import 'package:flutter_fitness_app/ui/layout.dart';
import 'package:flutter_fitness_app/ui/widgets/macro_mode_toggle.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomReserve(context)),
            child: const GoalsPanel(),
          ),
        ),
      );
}

class GoalsPanel extends StatefulWidget {
  const GoalsPanel({super.key, this.compact = false});
  final bool compact; // tighter spacing when true
  @override
  State<GoalsPanel> createState() => _GoalsPanelState();
}

class _GoalsPanelState extends State<GoalsPanel> {
  MacroViewMode _mode = MacroViewMode.remaining;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = state.goals;
    final dayKey = AppState.dayKeyFrom(DateTime.now());
    final t = state.totalsForDay(dayKey);
    final double p = (t['protein'] as double);
    final double c = (t['carbs'] as double);
    final double f = (t['fat'] as double);
    final double fi = (t['fiber'] as double);
    final int kcal = (t['kcal'] as int);
    final double macroSum = (p + c + f);
    final double pPct = macroSum == 0 ? 0 : p / macroSum;
    final double cPct = macroSum == 0 ? 0 : c / macroSum;
    final double fPct = macroSum == 0 ? 0 : f / macroSum;
    final spacer = SizedBox(height: widget.compact ? 12 : 16);
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Goals',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              MacroModeToggle(
                value: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 12),
              Center(
                child: MacroDonutChart(
                  carbsPct: cPct,
                  fatPct: fPct,
                  proteinPct: pPct,
                  totalCalories: kcal,
                  size: 160,
                  radiusScale: 0.7,
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final pres = presentMacro(
                    consumed: (t['kcal'] as int).toDouble(),
                    goal: g.kcal.toDouble(),
                    baseColor: AppColors.primary,
                    mode: _mode,
                    unit: 'kcal',
                  );
                  return MacroProgressBar(
                    label: 'Calories',
                    value: pres.barValue,
                    goal: pres.goal,
                    color: pres.color,
                    compact: true,
                    unit: 'kcal',
                    rightTextOverride: pres.rightText,
                    rightTextColor:
                        pres.color == Colors.redAccent ? pres.color : null,
                  );
                },
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final pres = presentMacro(
                    consumed: p,
                    goal: g.protein,
                    baseColor: AppColors.protein,
                    mode: _mode,
                  );
                  return MacroProgressBar(
                    label: 'Protein',
                    value: pres.barValue,
                    goal: pres.goal,
                    color: pres.color,
                    compact: true,
                    rightTextOverride: pres.rightText,
                    rightTextColor:
                        pres.color == Colors.redAccent ? pres.color : null,
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final pres = presentMacro(
                    consumed: c,
                    goal: g.carbs,
                    baseColor: AppColors.carbs,
                    mode: _mode,
                  );
                  return MacroProgressBar(
                    label: 'Carbs',
                    value: pres.barValue,
                    goal: pres.goal,
                    color: pres.color,
                    compact: true,
                    rightTextOverride: pres.rightText,
                    rightTextColor:
                        pres.color == Colors.redAccent ? pres.color : null,
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final pres = presentMacro(
                    consumed: f,
                    goal: g.fat,
                    baseColor: AppColors.fat,
                    mode: _mode,
                  );
                  return MacroProgressBar(
                    label: 'Fat',
                    value: pres.barValue,
                    goal: pres.goal,
                    color: pres.color,
                    compact: true,
                    rightTextOverride: pres.rightText,
                    rightTextColor:
                        pres.color == Colors.redAccent ? pres.color : null,
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final pres = presentMacro(
                    consumed: fi,
                    goal: g.fiber,
                    baseColor: AppColors.fiber,
                    mode: _mode,
                  );
                  return MacroProgressBar(
                    label: 'Fiber',
                    value: pres.barValue,
                    goal: pres.goal,
                    color: pres.color,
                    compact: true,
                    rightTextOverride: pres.rightText,
                    rightTextColor:
                        pres.color == Colors.redAccent ? pres.color : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _editGoals(context, g),
                child: const Text('Edit Goals'),
              ),
            ],
          ),
        ),
        spacer,
        const _GoalPresetsCard(),
      ],
    );
  }

  void _editGoals(BuildContext context, Goals goals) {
    // moved from old _GoalsScreenState
    double protein = goals.protein;
    double carbs = goals.carbs;
    double fat = goals.fat;
    double fiber = goals.fiber;
    final proteinCtrl = TextEditingController(text: protein.toStringAsFixed(0));
    final carbsCtrl = TextEditingController(text: carbs.toStringAsFixed(0));
    final fatCtrl = TextEditingController(text: fat.toStringAsFixed(0));
    final fiberCtrl = TextEditingController(text: fiber.toStringAsFixed(0));
    double _parseOr(double Function() current, TextEditingController c) {
      final raw = c.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) return current();
      final v = double.tryParse(raw);
      return v ?? current();
    }

    int kcalCalc() => (protein * 4 + carbs * 4 + fat * 9).round();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (c, setState) {
                Widget macroEditor({
                  required String label,
                  required double max,
                  required double Function() getVal,
                  required void Function(double) setVal,
                  required TextEditingController controller,
                }) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(label)),
                          SizedBox(
                            width: 86,
                            child: TextField(
                              controller: controller,
                              textAlign: TextAlign.end,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                isDense: true,
                                suffixText: 'g',
                                border: InputBorder.none,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                              ],
                              onChanged: (txt) {
                                final raw = txt.replaceAll(',', '.');
                                if (raw.isEmpty) return;
                                final v = double.tryParse(raw);
                                if (v != null) {
                                  setState(() => setVal(v.clamp(0, max).toDouble()));
                                }
                              },
                              onSubmitted: (_) {
                                final raw = controller.text.trim().replaceAll(',', '.');
                                final v = double.tryParse(raw) ?? 0;
                                setState(() {
                                  setVal(v.clamp(0, max).toDouble());
                                  controller.text = getVal().toStringAsFixed(0);
                                  controller.selection = TextSelection.collapsed(offset: controller.text.length);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: getVal().clamp(0, max),
                        max: max,
                        divisions: max.toInt(),
                        label: getVal().toStringAsFixed(0),
                        onChanged: (v) => setState(() {
                          setVal(v);
                          if (controller.text.isEmpty ||
                              double.tryParse(controller.text.replaceAll(',', '.')) != v.roundToDouble()) {
                            controller.text = v.toStringAsFixed(0);
                            controller.selection = TextSelection.collapsed(offset: controller.text.length);
                          }
                        }),
                      ),
                    ],
                  );
                }

                final kcal = kcalCalc();
                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        width: 44,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Text(
                        'Edit Goals',
                        style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      macroEditor(label: 'Protein', max: 300, getVal: () => protein, setVal: (v) => protein = v, controller: proteinCtrl),
                      macroEditor(label: 'Carbs', max: 500, getVal: () => carbs, setVal: (v) => carbs = v, controller: carbsCtrl),
                      macroEditor(label: 'Fat', max: 200, getVal: () => fat, setVal: (v) => fat = v, controller: fatCtrl),
                      macroEditor(label: 'Fiber', max: 100, getVal: () => fiber, setVal: (v) => fiber = v, controller: fiberCtrl),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Calories (derived): $kcal',
                          style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            protein = _parseOr(() => protein, proteinCtrl);
                            carbs = _parseOr(() => carbs, carbsCtrl);
                            fat = _parseOr(() => fat, fatCtrl);
                            fiber = _parseOr(() => fiber, fiberCtrl);
                            final kcalFinal = (protein * 4 + carbs * 4 + fat * 9).round();
                            context.read<AppState>().setGoals(Goals(
                                  protein: protein,
                                  carbs: carbs,
                                  fat: fat,
                                  fiber: fiber,
                                  kcal: kcalFinal,
                                ));
                            Navigator.pop(c);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _GoalPresetsCard extends StatelessWidget {
  const _GoalPresetsCard();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final presets = state.goalPresets; // id -> GoalPreset
    final activeId = state.activeGoalPresetId;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Goal Presets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New'),
                onPressed: () => _createPreset(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (presets.isEmpty)
            Text(
              'No presets yet. Create one to switch goals quickly.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.values.map((p) {
                final selected = p.id == activeId;
                return ChoiceChip(
                  label: Text(p.name),
                  selected: selected,
                  onSelected: (_) =>
                      context.read<AppState>().activateGoalPreset(p.id),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('-20g Carbs'),
                  onPressed: () => context.read<AppState>().bumpCarbs(-20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('+20g Carbs'),
                  onPressed: () => context.read<AppState>().bumpCarbs(20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createPreset(BuildContext context) async {
    final app = context.read<AppState>();
    final nameCtrl = TextEditingController();
    double p = app.goals.protein;
    double c = app.goals.carbs;
    double f = app.goals.fat;
    double fi = app.goals.fiber;
    int kcalCalc() => (p * 4 + c * 4 + f * 9).round();
    await showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setState) {
          Widget row(
            String label,
            double value,
            ValueChanged<double> onChanged, {
            double max = 500,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${value.toStringAsFixed(0)}g',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value,
                  max: max,
                  divisions: max.toInt(),
                  onChanged: (v) => setState(() => onChanged(v)),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('New Goal Preset'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preset name',
                      hintText: 'e.g. Cut, Bulk',
                    ),
                  ),
                  const SizedBox(height: 8),
                  row('Protein', p, (v) => p = v, max: 300),
                  row('Carbs', c, (v) => c = v, max: 600),
                  row('Fat', f, (v) => f = v, max: 200),
                  row('Fiber', fi, (v) => fi = v, max: 120),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: Text('Calories: ${kcalCalc()}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dc),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameCtrl.text.trim().isEmpty
                      ? 'Preset ${DateTime.now().millisecondsSinceEpoch % 1000}'
                      : nameCtrl.text.trim();
                  final goals = Goals(
                    protein: p,
                    carbs: c,
                    fat: f,
                    fiber: fi,
                    kcal: kcalCalc(),
                  );
                  final id = app.addGoalPreset(name, goals);
                  app.activateGoalPreset(id);
                  Navigator.pop(dc);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
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

class GoalsEditorCard extends StatefulWidget {
  const GoalsEditorCard({super.key});
  @override
  State<GoalsEditorCard> createState() => _GoalsEditorCardState();
}

class _GoalsEditorCardState extends State<GoalsEditorCard> {
  double protein = 0, carbs = 0, fat = 0, fiber = 0;
  @override
  void initState() {
    super.initState();
    final g = context.read<AppState>().goals;
    protein = g.protein;
    carbs = g.carbs;
    fat = g.fat;
    fiber = g.fiber;
  }

  int get kcal => (protein * 4 + carbs * 4 + fat * 9).round();

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    String suffix = 'g',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${value.round()}$suffix'),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          max: max,
          divisions: max.toInt(),
          label: value.round().toString(),
          onChanged: (v) => setState(() => onChanged(v)),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _save() {
    final app = context.read<AppState>();
    app.setGoals(Goals(
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      kcal: kcal,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goals saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Goals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _slider(
              label: 'Protein',
              value: protein,
              max: 300,
              onChanged: (v) => protein = v,
            ),
            _slider(
              label: 'Carbs',
              value: carbs,
              max: 600,
              onChanged: (v) => carbs = v,
            ),
            _slider(
              label: 'Fat',
              value: fat,
              max: 250,
              onChanged: (v) => fat = v,
            ),
            _slider(
              label: 'Fiber',
              value: fiber,
              max: 120,
              onChanged: (v) => fiber = v,
            ),
            const SizedBox(height: 4),
            Text('Calories (derived): $kcal'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save Goals'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
