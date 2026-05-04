import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../workout/exercise_library.dart';
import '../../workout/models.dart';
import '../../theme.dart';
import 'log_set_sheet.dart';

Future<void> showExercisePicker(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AppState>(),
      child: const _ExercisePickerSheet(),
    ),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _selectedBodyPart = 'All';
  String _search = '';

  List<Exercise> _filtered(AppState appState) {
    var list = appState.allExercises;
    if (_selectedBodyPart != 'All') {
      list = list.where((e) => e.muscleGroups.contains(_selectedBodyPart)).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.cardDark : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final filtered = _filtered(appState);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        color: bgColor,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Exercise',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      // Create custom exercise button
                      TextButton.icon(
                        onPressed: () => _showCreateExerciseDialog(context, appState),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : AppColors.primary.withValues(alpha: .05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Body part chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kBodyPartFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final bp = kBodyPartFilters[i];
                        final selected = bp == _selectedBodyPart;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBodyPart = bp),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.surfaceDark : AppColors.primary.withValues(alpha: .08)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              bp,
                              style: TextStyle(
                                color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Divider(height: 1),
            // Exercise list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final exercise = filtered[i];
                  final isCustom = appState.customExercises.any((e) => e.id == exercise.id);
                  return _ExerciseRow(
                    exercise: exercise,
                    isCustom: isCustom,
                    onTap: () async {
                      Navigator.of(context).pop();
                      if (context.mounted) {
                        await showLogSetSheet(context, exercise);
                      }
                    },
                    onDelete: isCustom
                        ? () => appState.removeCustomExercise(exercise.id)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateExerciseDialog(BuildContext context, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateExerciseDialog(
        onSave: (ex) => appState.addCustomExercise(ex),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.isCustom,
    required this.onTap,
    this.onDelete,
  });
  final Exercise exercise;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white38 : Colors.black38;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Custom',
                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercise.muscleGroups.join(' · '),
                    style: TextStyle(fontSize: 12, color: subtleColor),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: subtleColor),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Icon(Icons.chevron_right_rounded, color: subtleColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Create Exercise Dialog ────────────────────────────────────────────────────

class _CreateExerciseDialog extends StatefulWidget {
  const _CreateExerciseDialog({required this.onSave});
  final ValueChanged<Exercise> onSave;

  @override
  State<_CreateExerciseDialog> createState() => _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends State<_CreateExerciseDialog> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedGroups = {};

  static const _categories = [
    'Back', 'Chest', 'Shoulders', 'Biceps', 'Triceps',
    'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Core',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an exercise name')),
      );
      return;
    }
    if (_selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one muscle group')),
      );
      return;
    }
    // Build a stable id from the name
    final id = 'custom_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
    widget.onSave(Exercise(
      id: id,
      name: name,
      muscleGroups: _selectedGroups.toList(),
      icon: '🏋️',
      defaultIncrementKg: 2.5,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Exercise name'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Muscle groups',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedGroups.contains(cat);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedGroups.remove(cat);
                    } else {
                      _selectedGroups.add(cat);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black54,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }
}
