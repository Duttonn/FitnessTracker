import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/entry_tile.dart';
import 'package:flutter_fitness_app/data/old_export_parser.dart';
import 'package:flutter_fitness_app/ui/screens/quick_add_sheet.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  // Returns a user-friendly relative label for a dayKey (yyyy-MM-dd)
  static String _dayLabel(String dayKey) {
    final date = DateTime.parse(dayKey);
    final today = AppState.dayKeyFrom(DateTime.now());
    final yesterday = AppState.dayKeyFrom(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    if (dayKey == today) return 'Today';
    if (dayKey == yesterday) return 'Yesterday';
    // Within the last 7 days → weekday name
    final diff = DateTime.now().difference(date).inDays;
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayKeys = state.entriesByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final navPillHeight = 64.0;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final listBottomPadding = navPillHeight + bottomInset + 24;

    return SafeArea(
      top: true,
      bottom: false,
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Import data',
                  child: IconButton(
                    tooltip: 'Import',
                    onPressed: () => _import(context),
                    icon: const Icon(Icons.download_rounded),
                  ),
                ),
                Semantics(
                  label: 'Export data',
                  child: IconButton(
                    tooltip: 'Export',
                    onPressed: () => _export(context),
                    icon: const Icon(Icons.upload_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dayKeys.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 56,
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.white24
                                : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs yet',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add food on the Home tab to start tracking',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: dayKeys.length,
                      itemBuilder: (c, i) => _DayBlock(
                        dayKey: dayKeys[i],
                        label: _dayLabel(dayKeys[i]),
                      ),
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
  final String label;
  const _DayBlock({required this.dayKey, required this.label});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.entriesForDay(dayKey)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final totals = state.totalsForDay(dayKey);
    double protein = totals['protein'] as double;
    double carbs = totals['carbs'] as double;
    double fat = totals['fat'] as double;
    int kcal = totals['kcal'] as int;
    double fiber = totals['fiber'] as double;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: appCardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$kcal kcal',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Macro chips row
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MiniChip('P ${protein.toStringAsFixed(0)}g', AppColors.protein),
              _MiniChip('C ${carbs.toStringAsFixed(0)}g', AppColors.carbs),
              _MiniChip('F ${fat.toStringAsFixed(0)}g', AppColors.fat),
              _MiniChip('Fi ${fiber.toStringAsFixed(0)}g', AppColors.fiber),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          for (final e in entries)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                HapticFeedback.mediumImpact();
                final app = context.read<AppState>();
                app.deleteEntry(e.id, e.dayKey);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${e.title ?? 'Entry'}"'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => app.addEntry(e),
                    ),
                  ),
                );
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
              ),
              child: EntryTile(
                entry: e,
                onEdit: () => _editEntrySheet(context, e),
                onDelete: () {
                  context.read<AppState>().deleteEntry(e.id, e.dayKey);
                },
                onDuplicate: () =>
                    context.read<AppState>().duplicateEntry(e),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

void _editEntrySheet(BuildContext context, MacroEntry entry) {
  final appState = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => QuickAddSheet.edit(entry: entry, appState: appState),
  );
}
