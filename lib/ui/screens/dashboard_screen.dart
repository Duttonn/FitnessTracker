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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.openFoodsTab});
  final void Function(int tabIndex)? openFoodsTab;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  MacroViewMode _mode = MacroViewMode.remaining;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _greeting() {
    final h = TimeOfDay.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _userFirstName() {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.isEmpty) return '';
    final local = email.split('@').first;
    return local[0].toUpperCase() + local.substring(1);
  }

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
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final app = context.read<AppState>();
    app.deleteEntry(entry.id, entry.dayKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => app.addEntry(entry),
        ),
      ),
    );
  }

  void _openTab(int tab) {
    final cb = widget.openFoodsTab;
    if (cb != null) {
      cb(tab);
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, __, ___) => FoodsScreen(initialTab: tab),
          transitionsBuilder: (_, anim, __, child) {
            final curved =
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
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

  // ── Entry tile with swipe-to-delete ───────────────────────────────────────

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
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => app.addEntry(e),
              ),
            ),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayKey = AppState.dayKeyFrom(DateTime.now());
    final totals = state.totalsForDay(dayKey);
    final consumed = totals['kcal'] as int;
    final goal = state.goals.kcal;

    final entries = state.entriesForDay(dayKey)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final streak = state.currentStreak;

    // Group entries by meal
    final Map<Meal, List<MacroEntry>> byMeal = {};
    for (final e in entries) {
      (byMeal[e.meal] ??= []).add(e);
    }
    final mealOrder = [Meal.breakfast, Meal.lunch, Meal.dinner, Meal.snack];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}${_userFirstName().isNotEmpty ? ', ${_userFirstName()}' : ''}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                      ),
                    ],
                  ),
                ),
                if (streak > 0)
                  Semantics(
                    label: '$streak day streak',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            '$streak',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Calorie hero card ──────────────────────────────────────────
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CalorieRingWidget(
                          consumed: consumed,
                          goal: goal,
                          size: 160,
                          strokeWidth: 14,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CalStat(
                              label: 'Goal',
                              value: '$goal',
                              unit: 'kcal',
                            ),
                            const SizedBox(height: 10),
                            _CalStat(
                              label: 'Consumed',
                              value: '$consumed',
                              unit: 'kcal',
                              valueColor: AppColors.primary,
                            ),
                            const SizedBox(height: 10),
                            _CalStat(
                              label: consumed > goal ? 'Over' : 'Remaining',
                              value: '${(goal - consumed).abs()}',
                              unit: 'kcal',
                              valueColor: consumed > goal
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Quick Actions ──────────────────────────────────────────────
            Row(
              children: [
                _QuickBtn(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Quick Add',
                  onTap: _openQuickAdd,
                  primary: true,
                ),
                const SizedBox(width: 8),
                _QuickBtn(
                  icon: Icons.kitchen_rounded,
                  label: 'Ingredients',
                  onTap: () => _openTab(0),
                ),
                const SizedBox(width: 8),
                _QuickBtn(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Meals',
                  onTap: () => _openTab(1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Macros card ────────────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Today's Macros",
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      MacroModeToggle(
                        value: _mode,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMacroBar('Protein', totals['protein'] as double,
                      state.goals.protein, AppColors.protein),
                  _buildMacroBar('Carbs', totals['carbs'] as double,
                      state.goals.carbs, AppColors.carbs),
                  _buildMacroBar('Fat', totals['fat'] as double,
                      state.goals.fat, AppColors.fat),
                  _buildMacroBar('Fiber', totals['fiber'] as double,
                      state.goals.fiber, AppColors.fiber),
                ],
              ),
            ),


            // ── Today's entries (grouped by meal) ─────────────────────────
            if (entries.isEmpty)
              _Card(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Icon(
                      Icons.restaurant_outlined,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No entries yet today',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap Quick Add to log your first meal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openQuickAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Log Food'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              )
            else
              for (final meal in mealOrder)
                if (byMeal.containsKey(meal)) ...[
                  _MealSection(
                    meal: meal,
                    entries: byMeal[meal]!,
                    entryTileBuilder: _entryTile,
                  ),
                  const SizedBox(height: 12),
                ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(
      String label, double consumed, double goal, Color color) {
    final p = presentMacro(
      consumed: consumed,
      goal: goal,
      baseColor: color,
      mode: _mode,
      unit: label == 'Calories' ? 'kcal' : 'g',
    );
    return MacroProgressBar(
      label: label,
      value: p.barValue,
      goal: p.goal,
      color: p.color,
      rightTextOverride: p.rightText,
      rightTextColor: p.color == Colors.redAccent ? p.color : null,
    );
  }
}

// ── Meal section header + entries ───────────────────────────────────────────

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meal,
    required this.entries,
    required this.entryTileBuilder,
  });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mealKcal = entries.fold<int>(0, (s, e) => s + e.kcal);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon(meal),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _label(meal),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '$mealKcal kcal',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...entries.map(entryTileBuilder),
        ],
      ),
    );
  }
}

// ── Small stat label/value pair ─────────────────────────────────────────────

class _CalStat extends StatelessWidget {
  const _CalStat({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor ??
                          (isDark ? Colors.white : Colors.black87),
                    ),
              ),
              TextSpan(
                text: ' $unit',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quick action button ──────────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: primary
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.cardDark
                      : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: primary
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: .08)
                          : Colors.black.withValues(alpha: .07),
                    ),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: primary
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primary
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card wrapper ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: appCardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
