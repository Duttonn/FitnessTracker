import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/theme.dart';

class EntryTile extends StatelessWidget {
  final MacroEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  const EntryTile({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
  });
  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(entry.createdAt);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _mealIcon(entry.meal),
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title ?? 'Quick Add',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'edit') onEdit?.call();
                          if (val == 'duplicate') onDuplicate?.call();
                          if (val == 'delete') onDelete?.call();
                        },
                        itemBuilder: (c) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicate'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
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
            const SizedBox(width: 8),
            Text(
              '${entry.kcal} kcal',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  IconData _mealIcon(Meal meal) {
    switch (meal) {
      case Meal.breakfast:
        return Icons.free_breakfast;
      case Meal.lunch:
        return Icons.lunch_dining;
      case Meal.dinner:
        return Icons.dinner_dining;
      case Meal.snack:
        return Icons.fastfood;
    }
  }
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
