import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/macro_progress_bar.dart';
import 'package:flutter_fitness_app/ui/widgets/entry_tile.dart';
import 'package:flutter_fitness_app/ui/screens/foods_screen.dart';
import 'package:flutter_fitness_app/ui/screens/quick_add_sheet.dart';
import 'package:flutter_fitness_app/ui/widgets/macro_mode_toggle.dart'; // added

class DashboardScreen extends StatefulWidget {
  // was StatelessWidget
  const DashboardScreen({super.key, this.openFoodsTab});
  final void Function(int tabIndex)? openFoodsTab;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  MacroViewMode _mode =
      MacroViewMode.remaining; // changed default from consumed
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayKey = AppState.dayKeyFrom(DateTime.now());
    final totals = state.totalsForDay(dayKey);
    final entries = state.entriesForDay(dayKey)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    void openTab(int tab) {
      final cb = widget.openFoodsTab;
      if (cb != null) {
        cb(tab);
      } else {
        // fallback push with a subtle fade/slide for smoother feel
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (_, __, ___) => FoodsScreen(initialTab: tab),
            transitionsBuilder: (_, anim, __, child) {
              final curved = CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutCubic,
              );
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RemainingCalories(totals: totals, goals: state.goals),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionsRow(
                    onQuickAdd: () => _openQuickAdd(context),
                    onOpenIngredients: () => openTab(0),
                    onOpenMeals: () => openTab(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Progress",
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
                  // Calories
                  Builder(
                    builder: (context) {
                      final p = presentMacro(
                        consumed: (totals['kcal'] as int).toDouble(),
                        goal: state.goals.kcal.toDouble(),
                        baseColor: AppColors.primary,
                        mode: _mode,
                        unit: 'kcal',
                      );
                      return MacroProgressBar(
                        label: 'Calories',
                        value: p.barValue,
                        goal: p.goal,
                        color: p.color,
                        unit: 'kcal',
                        rightTextOverride: p.rightText,
                        rightTextColor: p.color == Colors.redAccent
                            ? p.color
                            : null,
                      );
                    },
                  ),
                  // Protein
                  Builder(
                    builder: (context) {
                      final p = presentMacro(
                        consumed: (totals['protein'] as double),
                        goal: state.goals.protein,
                        baseColor: AppColors.protein,
                        mode: _mode,
                      );
                      return MacroProgressBar(
                        label: 'Protein',
                        value: p.barValue,
                        goal: p.goal,
                        color: p.color,
                        rightTextOverride: p.rightText,
                        rightTextColor: p.color == Colors.redAccent
                            ? p.color
                            : null,
                      );
                    },
                  ),
                  // Carbs
                  Builder(
                    builder: (context) {
                      final p = presentMacro(
                        consumed: (totals['carbs'] as double),
                        goal: state.goals.carbs,
                        baseColor: AppColors.carbs,
                        mode: _mode,
                      );
                      return MacroProgressBar(
                        label: 'Carbs',
                        value: p.barValue,
                        goal: p.goal,
                        color: p.color,
                        rightTextOverride: p.rightText,
                        rightTextColor: p.color == Colors.redAccent
                            ? p.color
                            : null,
                      );
                    },
                  ),
                  // Fat
                  Builder(
                    builder: (context) {
                      final p = presentMacro(
                        consumed: (totals['fat'] as double),
                        goal: state.goals.fat,
                        baseColor: AppColors.fat,
                        mode: _mode,
                      );
                      return MacroProgressBar(
                        label: 'Fat',
                        value: p.barValue,
                        goal: p.goal,
                        color: p.color,
                        rightTextOverride: p.rightText,
                        rightTextColor: p.color == Colors.redAccent
                            ? p.color
                            : null,
                      );
                    },
                  ),
                  // Fiber
                  Builder(
                    builder: (context) {
                      final p = presentMacro(
                        consumed: (totals['fiber'] as double),
                        goal: state.goals.fiber,
                        baseColor: AppColors.fiber,
                        mode: _mode,
                      );
                      return MacroProgressBar(
                        label: 'Fiber',
                        value: p.barValue,
                        goal: p.goal,
                        color: p.color,
                        rightTextOverride: p.rightText,
                        rightTextColor: p.color == Colors.redAccent
                            ? p.color
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Entries',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No entries yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ...entries.take(6).map((e) => EntryTile(entry: e)),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  static void _openQuickAdd(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) =>
          QuickAddSheet(initialMeal: Meal.lunch, appState: appState),
    );
  }
}

class _RemainingCalories extends StatelessWidget {
  final Map<String, dynamic> totals;
  final Goals goals;
  const _RemainingCalories({required this.totals, required this.goals});
  @override
  Widget build(BuildContext context) {
    final consumed = (totals['kcal'] as int);
    final remain = (goals.kcal - consumed).clamp(-99999, 99999);
    return Row(
      children: [
        const Icon(Icons.local_fire_department, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'You have $remain calories remaining today',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onQuickAdd;
  final VoidCallback onOpenIngredients;
  final VoidCallback onOpenMeals;
  const _QuickActionsRow({
    required this.onQuickAdd,
    required this.onOpenIngredients,
    required this.onOpenMeals,
  });
  @override
  Widget build(BuildContext context) {
    Widget btn(
      IconData icon,
      String label,
      VoidCallback onPressed, {
      int flex = 4,
    }) => Expanded(
      flex: flex,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.black.withOpacity(.06)),
          ),
        ),
      ),
    );
    return Row(
      children: [
        btn(Icons.add, 'Quick Add', onQuickAdd, flex: 4),
        const SizedBox(width: 8),
        btn(
          Icons.kitchen,
          'Ingredients',
          onOpenIngredients,
          flex: 5,
        ), // slightly wider
        const SizedBox(width: 8),
        btn(Icons.restaurant, 'Meals', onOpenMeals, flex: 4),
      ],
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
