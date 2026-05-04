import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';

Future<void> showDailyCheckin(BuildContext context) async {
  final appState = context.read<AppState>();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => _DailyCheckinSheet(appState: appState),
  );
}

class _DailyCheckinSheet extends StatelessWidget {
  const _DailyCheckinSheet({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's today?",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your macro targets will adjust automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          for (final type in DayType.values) ...[
            _DayTypeCard(
              dayType: type,
              profile: appState.macroProfiles[type]!,
              onTap: () {
                appState.setDayType(type);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DayTypeCard extends StatelessWidget {
  const _DayTypeCard({
    required this.dayType,
    required this.profile,
    required this.onTap,
  });

  final DayType dayType;
  final MacroProfile profile;
  final VoidCallback onTap;

  Color get _color => switch (dayType) {
    DayType.rest => const Color(0xFF48CAE4),
    DayType.training => AppColors.primary,
    DayType.intense => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _color.withValues(alpha: .3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Text(dayType.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayType.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${profile.kcal} kcal  ·  ${profile.protein.toInt()}p  ${profile.carbs.toInt()}c  ${profile.fat.toInt()}f',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _color),
          ],
        ),
      ),
    );
  }
}
