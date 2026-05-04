import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../workout/models.dart';
import '../../theme.dart';

Future<void> showLogSetSheet(BuildContext context, Exercise exercise) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AppState>(),
      child: _LogSetSheet(exercise: exercise),
    ),
  );
}

class _LogSetSheet extends StatefulWidget {
  const _LogSetSheet({required this.exercise});
  final Exercise exercise;

  @override
  State<_LogSetSheet> createState() => _LogSetSheetState();
}

class _LogSetSheetState extends State<_LogSetSheet> {
  late double _weight;
  late int _reps;

  @override
  void initState() {
    super.initState();
    final last = context.read<AppState>().lastSetFor(widget.exercise.id);
    _weight = last?.weight ?? 20.0;
    _reps = last?.reps ?? 8;
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    final appState = context.read<AppState>();
    final log = SetLog(
      at: DateTime.now(),
      exerciseId: widget.exercise.id,
      exerciseName: widget.exercise.name,
      weight: _weight,
      reps: _reps,
    );
    appState.logSet(log);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final last = appState.lastSetFor(widget.exercise.id);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white38 : Colors.black38;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Exercise name + body parts
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exercise.name.toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      widget.exercise.muscleGroups.join(' · '),
                      style: TextStyle(color: subtleColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Last set info
          if (last != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Last: ${last.weight % 1 == 0 ? last.weight.toInt() : last.weight}kg × ${last.reps}  ·  ${_timeAgo(last.at)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Weight stepper
          _FieldLabel(label: 'Weight (kg)', color: textColor),
          const SizedBox(height: 8),
          _Stepper(
            value: _weight % 1 == 0 ? _weight.toInt().toString() : _weight.toStringAsFixed(1),
            onDecrement: () => setState(() => _weight = (_weight - 2.5).clamp(0, 500)),
            onIncrement: () => setState(() => _weight = (_weight + 2.5).clamp(0, 500)),
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // Reps stepper
          _FieldLabel(label: 'Reps', color: textColor),
          const SizedBox(height: 8),
          _Stepper(
            value: _reps.toString(),
            onDecrement: () => setState(() => _reps = (_reps - 1).clamp(1, 100)),
            onIncrement: () => setState(() => _reps = (_reps + 1).clamp(1, 100)),
            isDark: isDark,
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'LOG SET',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return DateFormat('MMM d').format(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.3,
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.isDark,
  });
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.primary.withValues(alpha: .06);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        _StepBtn(icon: Icons.remove_rounded, onTap: onDecrement, isDark: isDark),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
        _StepBtn(icon: Icons.add_rounded, onTap: onIncrement, isDark: isDark),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.isDark});
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }
}
