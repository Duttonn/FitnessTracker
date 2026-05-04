import 'package:flutter/material.dart';

/// Workout-style bottom indicator bar.
/// - Stateless/controlled via [currentIndex].
/// - Parent updates page & index; we only render.
class WorkoutNavBar extends StatelessWidget {
  const WorkoutNavBar({
    super.key,
    required this.currentIndex,
    required this.onTab,
  });
  final int currentIndex;
  final ValueChanged<int> onTab;

  static const _items = <_Item>[
    _Item(icon: Icons.home_rounded, label: 'Today'),
    _Item(icon: Icons.fitness_center_rounded, label: 'Activity'),
    _Item(icon: Icons.trending_up_rounded, label: 'Progress'),
    _Item(icon: Icons.history_rounded, label: 'History'),
  ];

  // Public height for layout helpers
  static const double kHeight = 64;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context).bottom;
    return IgnorePointer(
      ignoring: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, (pad > 0 ? pad - 6 : 6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A).withOpacity(0.7),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_items.length, (i) {
                  final selected = i == currentIndex;
                  final item = _items[i];
                  return _NavIcon(
                    icon: item.icon,
                    label: item.label,
                    selected: selected,
                    onTap: () => onTab(i),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  const _Item({required this.icon, required this.label});
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFDC2626);
    final color = selected ? primary : const Color(0xFF9CA3AF);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 170),
        scale: selected ? 1.0 : 0.86,
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
