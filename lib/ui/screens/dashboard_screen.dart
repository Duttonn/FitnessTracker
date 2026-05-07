import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/macro_progress_bar.dart';
import 'package:flutter_fitness_app/ui/widgets/entry_tile.dart';
import 'package:flutter_fitness_app/ui/screens/foods_screen.dart';
import 'package:flutter_fitness_app/ui/screens/quick_add_sheet.dart';
import 'package:flutter_fitness_app/ui/widgets/macro_mode_toggle.dart';
import 'package:flutter_fitness_app/ui/widgets/calorie_ring.dart';
import 'package:flutter_fitness_app/ui/daily_checkin_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.openFoodsTab});
  final void Function(int tabIndex)? openFoodsTab;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  MacroViewMode _mode = MacroViewMode.remaining;
  int _dateOffset = 0; // 0 = today, -1 = yesterday, +1 = tomorrow

  String _greeting() {
    final h = TimeOfDay.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _userFirstName() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.isEmpty) return '';
    final local = email.split('@').first;
    return local[0].toUpperCase() + local.substring(1);
  }

  DateTime get _targetDate => DateTime.now().add(Duration(days: _dateOffset));
  bool get _isToday => _dateOffset == 0;

  Future<void> _editEntry(MacroEntry entry) async {
    final appState = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => QuickAddSheet.edit(entry: entry, appState: appState),
    );
  }

  Future<void> _deleteEntry(MacroEntry entry) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ) ?? false;
    if (!confirmed) return;
    final app = context.read<AppState>();
    app.deleteEntry(entry.id, entry.dayKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () => app.addEntry(entry)),
      ),
    );
  }

  void _openTab(int tabIndex) {
    final cb = widget.openFoodsTab;
    if (cb != null) {
      cb(tabIndex);
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, __, ___) => FoodsScreen(initialTab: tabIndex),
          transitionsBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  void _openQuickAdd() {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => QuickAddSheet(
        initialMeal: _timeAwareMeal(),
        appState: appState,
        initialDate: _targetDate,
      ),
    );
  }

  Meal _timeAwareMeal() {
    final h = TimeOfDay.now().hour;
    if (h < 10) return Meal.breakfast;
    if (h < 14) return Meal.lunch;
    if (h < 19) return Meal.dinner;
    return Meal.snack;
  }

  Widget _entryTile(MacroEntry e) => Dismissible(
        key: ValueKey(e.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          final app = context.read<AppState>();
          app.deleteEntry(e.id, e.dayKey);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${e.title ?? 'Entry'}"'),
              action: SnackBarAction(label: 'Undo', onPressed: () => app.addEntry(e)),
            ),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        ),
        child: EntryTile(
          entry: e,
          onTap: () => _editEntry(e),
          onEdit: () => _editEntry(e),
          onDelete: () => _deleteEntry(e),
          onDuplicate: () => context.read<AppState>().duplicateEntry(e),
        ),
      );

  Widget _buildMacroBar(String label, double consumed, double goal, Color color) {
    final p = presentMacro(consumed: consumed, goal: goal, baseColor: color, mode: _mode, unit: label == 'Calories' ? 'kcal' : 'g');
    return MacroProgressBar(
      label: label,
      value: p.barValue,
      goal: p.goal,
      color: p.color,
      rightTextOverride: p.rightText,
      rightTextColor: p.color == Colors.redAccent ? p.color : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayKey = AppState.dayKeyFrom(_targetDate);
    final totals = state.totalsForDay(dayKey);
    final consumed = totals['kcal'] as int;
    final goal = state.goals.kcal;
    final streak = state.currentStreak;

    final entries = state.entriesForDay(dayKey)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final Map<Meal, List<MacroEntry>> byMeal = {};
    for (final e in entries) { (byMeal[e.meal] ??= []).add(e); }
    final mealOrder = [Meal.breakfast, Meal.lunch, Meal.dinner, Meal.snack];

    final name = _userFirstName();
    final firstName = name.isNotEmpty ? ', $name' : '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${_greeting()}$firstName',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text('$streak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.warning)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // ── Date navigator card ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  _NavChevron(
                    icon: Icons.chevron_left_rounded,
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _dateOffset--); },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () { if (!_isToday) setState(() => _dateOffset = 0); },
                      child: Column(
                        children: [
                          Text(
                            _isToday ? 'Today' : DateFormat('EEE, MMM d').format(_targetDate),
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _isToday ? AppColors.primary : Colors.black87,
                            ),
                          ),
                          Text(
                            _isToday
                                ? DateFormat('EEEE, MMM d').format(_targetDate)
                                : (_dateOffset > 0 ? 'Meal prep' : 'Edit past day'),
                            style: const TextStyle(fontSize: 10, color: Colors.black38),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _NavChevron(
                    icon: Icons.chevron_right_rounded,
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _dateOffset++); },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Day-type preset chips ───────────────────────────────────────
            _DayPresetChips(
              presets: state.macroPresets,
              activeId: state.todayPresetId,
              onSelect: (id) {
                HapticFeedback.selectionClick();
                state.setPreset(id);
              },
              onManage: () => showDailyCheckin(context, dismissible: true),
            ),
            const SizedBox(height: 12),

            // ── Hero card — ring + stats + macro bars ──────────────────────
            _FMCard(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CalorieRingWidget(consumed: consumed, goal: goal, size: 132, strokeWidth: 12),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatLine(label: 'GOAL', value: goal, unit: 'kcal'),
                            const SizedBox(height: 8),
                            _StatLine(label: 'EATEN', value: consumed, unit: 'kcal', valueColor: AppColors.primary),
                            const SizedBox(height: 8),
                            _StatLine(
                              label: consumed > goal ? 'OVER' : 'LEFT',
                              value: (goal - consumed).abs(),
                              unit: 'kcal',
                              valueColor: consumed > goal ? AppColors.danger : AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0x0F000000)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Macros",
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: .5,
                          ),
                        ),
                      ),
                      MacroModeToggle(value: _mode, onChanged: (m) => setState(() => _mode = m)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildMacroBar('Protein', totals['protein'] as double, state.goals.protein, AppColors.protein),
                  _buildMacroBar('Carbs',   totals['carbs']   as double, state.goals.carbs,   AppColors.carbs),
                  _buildMacroBar('Fat',     totals['fat']     as double, state.goals.fat,     AppColors.fat),
                  _buildMacroBar('Fiber',   totals['fiber']   as double, state.goals.fiber,   AppColors.fiber),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 3-button action grid ────────────────────────────────────────
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan',
                  onTap: () => _openTab(0),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.calculate_rounded,
                  label: 'Macros',
                  onTap: _openQuickAdd,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  onTap: () => _openTab(0),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Today's meals section header ───────────────────────────────
            _SectionHead(
              icon: Icons.restaurant_rounded,
              title: _isToday ? "Today's meals" : DateFormat('MMM d').format(_targetDate),
              actionLabel: entries.isNotEmpty ? 'Log food' : null,
              onAction: entries.isNotEmpty ? _openQuickAdd : null,
            ),
            const SizedBox(height: 10),

            // ── Meal entries ───────────────────────────────────────────────
            if (entries.isEmpty)
              _FMCard(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.restaurant_outlined, size: 44, color: Colors.black26),
                    const SizedBox(height: 10),
                    Text('Nothing logged yet', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black45)),
                    const SizedBox(height: 4),
                    Text(
                      _isToday ? 'Tap Log Food to add your first entry' : 'No entries for this day',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black38),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    if (_isToday)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openQuickAdd,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log Food'),
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              )
            else
              for (final meal in mealOrder)
                if (byMeal.containsKey(meal)) ...[
                  _MealSection(meal: meal, entries: byMeal[meal]!, entryTileBuilder: _entryTile),
                  const SizedBox(height: 10),
                ],
          ],
        ),
      ),
    );
  }
}

// ── FM Card (design token wrapper) ───────────────────────────────────────────

class _FMCard extends StatelessWidget {
  const _FMCard({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 20, offset: const Offset(0, 6))],
    ),
    padding: padding,
    child: child,
  );
}

// ── Date nav chevron button ───────────────────────────────────────────────────

class _NavChevron extends StatelessWidget {
  const _NavChevron({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 22, color: Colors.black45),
    ),
  );
}

// ── Day preset chips ──────────────────────────────────────────────────────────

class _DayPresetChips extends StatelessWidget {
  const _DayPresetChips({required this.presets, required this.activeId, required this.onSelect, required this.onManage});
  final List<MacroPreset> presets;
  final String? activeId;
  final void Function(String id) onSelect;
  final VoidCallback onManage;

  static const _palette = [
    Color(0xFF4DB8C0), AppColors.primary, Color(0xFFED8936),
    Color(0xFF38B2AC), Color(0xFF9F7AEA), Color(0xFFD69E2E),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = presets.take(4).toList();
    return Row(
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _PresetChip(
            preset: visible[i],
            color: _palette[i % _palette.length],
            isActive: activeId == visible[i].id,
            onTap: () => onSelect(visible[i].id),
          )),
        ],
        if (presets.length > 4) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onManage,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 18, color: Colors.black38),
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset, required this.color, required this.isActive, required this.onTap});
  final MacroPreset preset;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: .12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive ? [] : [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 4))],
          border: isActive ? Border.all(color: color.withValues(alpha: .4)) : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                preset.name,
                style: TextStyle(
                  fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? color : Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat label/value line ────────────────────────────────────────────────────

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value, required this.unit, this.valueColor});
  final String label;
  final int value;
  final String unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black38, letterSpacing: .6)),
      const SizedBox(height: 2),
      RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(text: '$value', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: valueColor ?? Colors.black87)),
            TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ),
      ),
    ],
  );
}

// ── 3-button action ──────────────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); HapticFeedback.selectionClick(); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? .95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: .06)),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 22, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.icon, required this.title, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      if (actionLabel != null && onAction != null)
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
    ],
  );
}

// ── Meal section ─────────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.entries, required this.entryTileBuilder});
  final Meal meal;
  final List<MacroEntry> entries;
  final Widget Function(MacroEntry) entryTileBuilder;

  IconData _icon(Meal m) => switch (m) {
    Meal.breakfast => Icons.wb_sunny_rounded,
    Meal.lunch => Icons.light_mode_rounded,
    Meal.dinner => Icons.nightlight_round,
    Meal.snack => Icons.cookie_outlined,
  };

  String _label(Meal m) => switch (m) {
    Meal.breakfast => 'Breakfast',
    Meal.lunch => 'Lunch',
    Meal.dinner => 'Dinner',
    Meal.snack => 'Snacks',
  };

  @override
  Widget build(BuildContext context) {
    final mealKcal = entries.fold<int>(0, (s, e) => s + e.kcal);
    return _FMCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(meal), size: 16, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(_label(meal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$mealKcal kcal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45)),
            ],
          ),
          ...entries.map(entryTileBuilder),
        ],
      ),
    );
  }
}

