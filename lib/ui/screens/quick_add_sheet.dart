import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/segmented_meal_selector.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuickAddSheet extends StatefulWidget {
  final Meal initialMeal;
  final AppState appState;
  final MacroEntry? existing;
  final DateTime? initialDate;

  const QuickAddSheet({
    super.key,
    required this.initialMeal,
    required this.appState,
    this.existing,
    this.initialDate,
  });

  factory QuickAddSheet.edit({
    required MacroEntry entry,
    required AppState appState,
  }) => QuickAddSheet(
    initialMeal: entry.meal,
    appState: appState,
    existing: entry,
  );

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  late Meal meal = widget.initialMeal;
  late DateTime _targetDate;

  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetDate = widget.initialDate ?? DateTime.now();
    if (widget.existing != null) {
      final e = widget.existing!;
      meal = e.meal;
      _protein.text = e.protein.toStringAsFixed(0);
      _carbs.text = e.carbs.toStringAsFixed(0);
      _fat.text = e.fat.toStringAsFixed(0);
      _fiber.text = e.fiber.toStringAsFixed(0);
      _title.text = e.title ?? '';
      // Restore the day from the existing entry's dayKey
      try {
        _targetDate = DateTime.parse(e.dayKey);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    _title.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0;

  int get estimatedCalories {
    return (_parse(_protein) * 4 + _parse(_carbs) * 4 + _parse(_fat) * 9).round();
  }

  String _dayKey(DateTime dt) => AppState.dayKeyFrom(dt);
  String get _todayKey => _dayKey(DateTime.now());
  String get _tomorrowKey => _dayKey(DateTime.now().add(const Duration(days: 1)));

  String _dateLabel(DateTime dt) {
    final key = _dayKey(dt);
    if (key == _todayKey) return 'Today';
    if (key == _tomorrowKey) return 'Tomorrow';
    return DateFormat('MMM d').format(dt);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _submit() {
    final p = _parse(_protein);
    final c = _parse(_carbs);
    final f = _parse(_fat);
    final fi = _parse(_fiber);
    final kcal = (p * 4 + c * 4 + f * 9).round();
    if (Supabase.instance.client.auth.currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please sign in again.')),
        );
        Navigator.pop(context);
      }
      return;
    }
    final state = widget.appState;
    final dayKey = _dayKey(_targetDate);

    if (widget.existing == null) {
      final id = state.generateId();
      final entry = MacroEntry(
        id: id,
        dayKey: dayKey,
        createdAt: DateTime.now(),
        meal: meal,
        protein: p,
        carbs: c,
        fat: f,
        fiber: fi,
        kcal: kcal,
        title: _title.text.trim().isEmpty ? 'Quick Add' : _title.text.trim(),
      );
      state.addEntry(entry);
      HapticFeedback.lightImpact();
      Navigator.pop(context, meal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to ${_dateLabel(_targetDate)}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => state.deleteEntry(id, dayKey),
          ),
        ),
      );
    } else {
      final existing = widget.existing!;
      final updated = existing.copyWith(
        meal: meal,
        protein: p,
        carbs: c,
        fat: f,
        fiber: fi,
        kcal: kcal,
        title: _title.text.trim().isEmpty ? existing.title : _title.text.trim(),
      );
      state.updateEntry(updated);
      HapticFeedback.lightImpact();
      Navigator.pop(context, meal);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.cardDark : Colors.white;
    final isEditing = widget.existing != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        Text(
                          isEditing ? 'Edit Entry' : 'Log Food',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    // Date selector (only for new entries)
                    if (!isEditing) ...[
                      const SizedBox(height: 8),
                      _DateSelector(
                        selected: _targetDate,
                        todayKey: _todayKey,
                        tomorrowKey: _tomorrowKey,
                        dayKeyFn: _dayKey,
                        labelFn: _dateLabel,
                        onSelectToday: () => setState(() => _targetDate = DateTime.now()),
                        onSelectTomorrow: () => setState(() =>
                            _targetDate = DateTime.now().add(const Duration(days: 1))),
                        onPickDate: _pickDate,
                        isDark: isDark,
                      ),
                    ],

                    const SizedBox(height: 16),
                    SegmentedMealSelector(
                      value: meal,
                      onChanged: (m) => setState(() => meal = m),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _title,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name (optional)',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _numberField('Protein (g)', _protein, TextInputAction.next)),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField('Carbs (g)', _carbs, TextInputAction.next)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField('Fat (g)', _fat, TextInputAction.next)),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField('Fiber (g)', _fiber, TextInputAction.done)),
                      ],
                    ),

                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: Listenable.merge([_protein, _carbs, _fat]),
                      builder: (context, _) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Estimated: $estimatedCalories kcal',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditing ? 'Save Changes' : 'Log Macros'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController ctrl, TextInputAction action) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textInputAction: action,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.selected,
    required this.todayKey,
    required this.tomorrowKey,
    required this.dayKeyFn,
    required this.labelFn,
    required this.onSelectToday,
    required this.onSelectTomorrow,
    required this.onPickDate,
    required this.isDark,
  });

  final DateTime selected;
  final String todayKey;
  final String tomorrowKey;
  final String Function(DateTime) dayKeyFn;
  final String Function(DateTime) labelFn;
  final VoidCallback onSelectToday;
  final VoidCallback onSelectTomorrow;
  final VoidCallback onPickDate;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final selectedKey = dayKeyFn(selected);
    final isCustom = selectedKey != todayKey && selectedKey != tomorrowKey;

    return Row(
      children: [
        _Chip(
          label: 'Today',
          selected: selectedKey == todayKey,
          onTap: onSelectToday,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _Chip(
          label: 'Tomorrow',
          selected: selectedKey == tomorrowKey,
          onTap: onSelectTomorrow,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _Chip(
          label: isCustom ? labelFn(selected) : 'Pick date',
          selected: isCustom,
          onTap: onPickDate,
          icon: Icons.calendar_today_rounded,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceDark : AppColors.primary.withValues(alpha: .07)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
