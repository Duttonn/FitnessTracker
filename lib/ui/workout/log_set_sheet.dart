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
  // Sets logged this session (not yet persisted until "Add Set")
  final List<({double weight, int reps})> _sessionSets = [];

  @override
  void initState() {
    super.initState();
    final last = context.read<AppState>().lastSetFor(widget.exercise.id);
    _weight = last?.weight ?? 20.0;
    _reps = last?.reps ?? 8;
  }

  void _addSet() {
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
    setState(() {
      _sessionSets.add((weight: _weight, reps: _reps));
    });
  }

  void _removeSet(int index) {
    HapticFeedback.selectionClick();
    // Remove from state list only (already persisted; use deleteSetLog if needed)
    setState(() => _sessionSets.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final history = appState.logsForExercise(widget.exercise.id);
    // Group history by day — find the most recent previous session (before today)
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prevSets = history.where((l) => DateFormat('yyyy-MM-dd').format(l.at) != today).toList();
    // Last session: most recent day's worth
    List<SetLog> lastSession = [];
    if (prevSets.isNotEmpty) {
      final lastDay = DateFormat('yyyy-MM-dd').format(prevSets.last.at);
      lastSession = prevSets.where((l) => DateFormat('yyyy-MM-dd').format(l.at) == lastDay).toList();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white38 : Colors.black45;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Exercise name
          Text(
            widget.exercise.name.toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
          if (widget.exercise.muscleGroups.isNotEmpty)
            Text(
              widget.exercise.muscleGroups.join(' · '),
              style: TextStyle(color: subtleColor, fontSize: 13),
            ),

          const SizedBox(height: 16),

          // Last session reference
          if (lastSession.isNotEmpty) ...[
            Text('Last session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subtleColor, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (int i = 0; i < lastSession.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
                    ),
                    child: Text(
                      '${i + 1}  ${_fmtKg(lastSession[i].weight)} × ${lastSession[i].reps}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Sets logged this session
          if (_sessionSets.isNotEmpty) ...[
            Text('This session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subtleColor, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sessionSets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final s = _sessionSets[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .15),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_fmtKg(s.weight)} kg  ×  ${s.reps} reps',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeSet(i),
                        child: const Icon(Icons.close, size: 18, color: Colors.black38),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // Input area
          Text(
            _sessionSets.isEmpty ? 'Set 1' : 'Set ${_sessionSets.length + 1}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subtleColor, letterSpacing: 0.4),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              // Weight
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight (kg)', style: TextStyle(fontSize: 12, color: subtleColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _CompactStepper(
                      value: _fmtKg(_weight),
                      onDecrement: () => setState(() => _weight = (_weight - 2.5).clamp(0, 500)),
                      onIncrement: () => setState(() => _weight = (_weight + 2.5).clamp(0, 500)),
                      onLongDecrement: () => setState(() => _weight = (_weight - 0.5).clamp(0, 500)),
                      onLongIncrement: () => setState(() => _weight = (_weight + 0.5).clamp(0, 500)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Reps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reps', style: TextStyle(fontSize: 12, color: subtleColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _CompactStepper(
                      value: _reps.toString(),
                      onDecrement: () => setState(() => _reps = (_reps - 1).clamp(1, 100)),
                      onIncrement: () => setState(() => _reps = (_reps + 1).clamp(1, 100)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              if (_sessionSets.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _addSet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _sessionSets.isEmpty ? 'LOG SET' : '+ ADD SET',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtKg(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return DateFormat('MMM d').format(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _CompactStepper extends StatelessWidget {
  const _CompactStepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.onLongDecrement,
    this.onLongIncrement,
  });
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onLongDecrement;
  final VoidCallback? onLongIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepBtn(icon: Icons.remove_rounded, onTap: onDecrement, onLongPress: onLongDecrement),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        _StepBtn(icon: Icons.add_rounded, onTap: onIncrement, onLongPress: onLongIncrement),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, this.onLongPress});
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: onLongPress != null ? () {
        HapticFeedback.selectionClick();
        onLongPress!();
      } : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
