import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/entry_tile.dart';
import 'package:flutter_fitness_app/data/old_export_parser.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayKeys = state.entriesByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // height of your floating nav pill + a little breathing room
    final navPillHeight = 64.0; // keep in sync with VisionNavBar
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final listBottomPadding = navPillHeight + bottomInset + 24;

    return SafeArea(
      top: true,
      bottom: false, // let content extend behind the floating pill
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Logs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Import',
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.download),
                ),
                IconButton(
                  tooltip: 'Export',
                  onPressed: () => _export(context),
                  icon: const Icon(Icons.upload),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dayKeys.isEmpty
                  ? Center(
                      child: Text(
                        'No entries yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: dayKeys.length,
                      itemBuilder: (c, i) => _DayBlock(dayKey: dayKeys[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _export(BuildContext context) {
    final state = context.read<AppState>();
    final map = <String, dynamic>{};
    for (final e in state.entriesByDay.entries) {
      final totals = state.totalsForDay(e.key);
      map[e.key] = {
        'totals': totals,
        'entries': e.value.map((m) => m.toJson()).toList(),
      };
    }
    final json = {
      'days': map,
      'weights': state.weights.map((w) => w.toJson()).toList(),
      'goals': state.goals.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final text = const JsonEncoder.withIndent('  ').convert(json);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Export Data'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _import(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste export JSON or legacy text here',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final pasted = controller.text.trim();
              if (pasted.isNotEmpty) {
                if (pasted.startsWith('{')) {
                  // new JSON format
                  try {
                    final decoded = jsonDecode(pasted) as Map<String, dynamic>;
                    context.read<AppState>().importExportJson(decoded);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Imported JSON export')),
                    );
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid JSON')),
                    );
                  }
                } else {
                  // legacy free-text
                  final result = OldExportParser.parse(pasted);
                  context.read<AppState>().mergeImport(
                    result.entriesByDay,
                    result.weights,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Imported legacy log')),
                  );
                }
              }
              Navigator.pop(c);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  final String dayKey;
  const _DayBlock({required this.dayKey});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.entriesForDay(dayKey)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final totals = state.totalsForDay(dayKey);
    final date = DateTime.parse(dayKey);
    final dateStr = DateFormat('MMM d, yyyy').format(date);
    double protein = totals['protein'] as double;
    double carbs = totals['carbs'] as double;
    double fat = totals['fat'] as double;
    int kcal = totals['kcal'] as int;
    double fiber = totals['fiber'] as double;
    double sumMacros = protein + carbs + fat;
    double proteinPct = sumMacros == 0 ? 0 : protein / sumMacros * 100;
    double carbsPct = sumMacros == 0 ? 0 : carbs / sumMacros * 100;
    double fatPct = sumMacros == 0 ? 0 : fat / sumMacros * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: appCardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$kcal kcal',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '${protein.toStringAsFixed(0)}g Protein',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${carbs.toStringAsFixed(0)}g Carbs',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${fat.toStringAsFixed(0)}g Fat',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${fiber.toStringAsFixed(0)}g Fiber',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'P${proteinPct.toStringAsFixed(0)}/F${fatPct.toStringAsFixed(0)}/C${carbsPct.toStringAsFixed(0)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in entries)
            EntryTile(
              entry: e,
              onEdit: () => _editEntry(context, e),
              onDelete: () =>
                  context.read<AppState>().deleteEntry(e.id, e.dayKey),
              onDuplicate: () => context.read<AppState>().duplicateEntry(e),
            ),
        ],
      ),
    );
  }
}

void _editEntry(BuildContext context, MacroEntry entry) {
  final state = context.read<AppState>();
  final proteinCtrl = TextEditingController(
    text: entry.protein.toStringAsFixed(0),
  );
  final carbsCtrl = TextEditingController(text: entry.carbs.toStringAsFixed(0));
  final fatCtrl = TextEditingController(text: entry.fat.toStringAsFixed(0));
  final fiberCtrl = TextEditingController(text: entry.fiber.toStringAsFixed(0));
  final titleCtrl = TextEditingController(text: entry.title ?? '');
  Meal selectedMeal = entry.meal;
  DateTime createdAt = entry.createdAt;
  int computedKcal() {
    final p = double.tryParse(proteinCtrl.text) ?? 0;
    final c = double.tryParse(carbsCtrl.text) ?? 0;
    final f = double.tryParse(fatCtrl.text) ?? 0;
    return (p * 4 + c * 4 + f * 9).round();
  }

  showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) {
        void hook() => setSt(() {});
        proteinCtrl.addListener(hook);
        carbsCtrl.addListener(hook);
        fatCtrl.addListener(hook);
        return AlertDialog(
          title: const Text('Edit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: proteinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protein g',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Carbs g'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fat g'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fiberCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fiber g'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Calories (auto): ${computedKcal()} kcal',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<Meal>(
                  value: selectedMeal,
                  onChanged: (m) =>
                      setSt(() => selectedMeal = m ?? selectedMeal),
                  items: Meal.values
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m.name)),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(createdAt),
                    );
                    if (picked != null) {
                      setSt(
                        () => createdAt = DateTime(
                          createdAt.year,
                          createdAt.month,
                          createdAt.day,
                          picked.hour,
                          picked.minute,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Time: ${DateFormat('h:mm a').format(createdAt)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                double parseD(TextEditingController ctrl) =>
                    double.tryParse(ctrl.text) ?? 0;
                final updated = entry.copyWith(
                  title: titleCtrl.text.trim().isEmpty
                      ? null
                      : titleCtrl.text.trim(),
                  protein: parseD(proteinCtrl),
                  carbs: parseD(carbsCtrl),
                  fat: parseD(fatCtrl),
                  fiber: parseD(fiberCtrl),
                  kcal: computedKcal(),
                  meal: selectedMeal,
                  createdAt: createdAt,
                );
                state.updateEntry(updated);
                Navigator.pop(c);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}
