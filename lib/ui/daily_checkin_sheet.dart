import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';

Future<void> showDailyCheckin(BuildContext context, {bool dismissible = false}) async {
  final appState = context.read<AppState>();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    builder: (_) => _DailyCheckinSheet(appState: appState, dismissible: dismissible),
  );
}

class _DailyCheckinSheet extends StatelessWidget {
  const _DailyCheckinSheet({required this.appState, this.dismissible = false});
  final AppState appState;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = appState.macroPresets;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "What's today?",
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (dismissible)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your macro targets will adjust automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          for (int i = 0; i < presets.length; i++) ...[
            _PresetCard(
              preset: presets[i],
              color: _colorForIndex(i),
              isToday: appState.todayPresetId == presets[i].id,
              onTap: () {
                appState.setPreset(presets[i].id);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  static Color _colorForIndex(int i) {
    const palette = [
      Color(0xFF48CAE4),
      AppColors.primary,
      AppColors.danger,
      Color(0xFF38B2AC),
      Color(0xFF9F7AEA),
      Color(0xFFED8936),
    ];
    return palette[i % palette.length];
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.color,
    required this.isToday,
    required this.onTap,
  });

  final MacroPreset preset;
  final Color color;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: isToday ? .12 : .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: isToday ? .5 : .3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        preset.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${preset.kcal} kcal  ·  ${preset.protein.toInt()}p  ${preset.carbs.toInt()}c  ${preset.fat.toInt()}f',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
