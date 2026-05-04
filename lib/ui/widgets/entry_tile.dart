import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/theme.dart';

class EntryTile extends StatelessWidget {
  final MacroEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  const EntryTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(entry.createdAt);
    final semanticsLabel =
        '${entry.title ?? "Quick Add"} at $timeStr'
        ' — ${entry.kcal} calories,'
        ' protein ${entry.protein.toStringAsFixed(0)}g,'
        ' carbs ${entry.carbs.toStringAsFixed(0)}g,'
        ' fat ${entry.fat.toStringAsFixed(0)}g';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: semanticsLabel,
      hint: 'Tap to edit, swipe left to delete',
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              Icon(_mealIcon(entry.meal), size: 22, color: AppColors.primary),
        ),
        title: Text(
          entry.title ?? 'Quick Add',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black54,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _MacroChip(
                    label: 'P ${entry.protein.toStringAsFixed(0)}g',
                    color: AppColors.protein,
                  ),
                  _MacroChip(
                    label: 'C ${entry.carbs.toStringAsFixed(0)}g',
                    color: AppColors.carbs,
                  ),
                  _MacroChip(
                    label: 'F ${entry.fat.toStringAsFixed(0)}g',
                    color: AppColors.fat,
                  ),
                  _MacroChip(
                    label: 'Fi ${entry.fiber.toStringAsFixed(0)}g',
                    color: AppColors.fiber,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${entry.kcal} kcal',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Entry options',
              onSelected: (val) {
                if (val == 'edit') onEdit?.call();
                if (val == 'duplicate') onDuplicate?.call();
                if (val == 'delete') onDelete?.call();
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onDuplicate != null)
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('Duplicate')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _mealIcon(Meal meal) => switch (meal) {
        Meal.breakfast => Icons.free_breakfast_rounded,
        Meal.lunch => Icons.lunch_dining_rounded,
        Meal.dinner => Icons.dinner_dining_rounded,
        Meal.snack => Icons.fastfood_rounded,
      };
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
