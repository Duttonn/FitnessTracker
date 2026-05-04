import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fitness_app/theme.dart';

/// Vision-style bottom navigation bar.
/// Stateless / controlled via [currentIndex].
class VisionNavBar extends StatelessWidget {
  const VisionNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  static const _items = <_VisionItem>[
    _VisionItem(icon: Icons.grid_view_rounded, label: 'Home'),
    _VisionItem(icon: Icons.list_rounded, label: 'Logs'),
    _VisionItem(icon: Icons.show_chart_rounded, label: 'Progress'),
    _VisionItem(icon: Icons.restaurant_rounded, label: 'Foods'),
    _VisionItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  // Public height constant for layout helpers
  static const double kHeight = 68.0;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, pad > 0 ? pad - 4 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.cardDark.withValues(alpha: .96)
                : Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: .06) : Colors.black.withValues(alpha: .06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .3 : .08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final item = _items[i];
            return _NavIcon(
              icon: item.icon,
              label: item.label,
              selected: selected,
              onTap: () {
                HapticFeedback.selectionClick();
                onItemSelected(i);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _VisionItem {
  final IconData icon;
  final String label;
  const _VisionItem({required this.icon, required this.label});
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;
    final unselectedColor =
        isDark ? Colors.white.withValues(alpha: .45) : Colors.black.withValues(alpha: .38);
    final color = selected ? primary : unselectedColor;

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: selected
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                    : EdgeInsets.zero,
                decoration: selected
                    ? BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: selected ? 1.0 : 0.88,
                  curve: Curves.easeOut,
                  child: Icon(icon, size: 22, color: color),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: color,
                  letterSpacing: selected ? 0.2 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Backwards-compat constant
const double kVisionNavBarHeight = VisionNavBar.kHeight;
