import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/theme.dart';

/// Vision-style bottom indicator bar.
/// - Stateless/controlled via [currentIndex].
/// - Parent updates page & index; we only render.
class VisionNavBar extends StatelessWidget {
  const VisionNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  static const _items = <_VisionItem>[
    _VisionItem(icon: Icons.grid_view, label: 'Home'),
    _VisionItem(icon: Icons.list_rounded, label: 'Logs'),
    _VisionItem(icon: Icons.bar_chart, label: 'Progress'),
    _VisionItem(icon: Icons.restaurant, label: 'Foods'),
    _VisionItem(icon: Icons.settings, label: 'Settings'),
  ];

  // Public height for layout helpers
  static const double kHeight =
      64; // includes visual pill (container is 44 inside)

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context).bottom;
    return IgnorePointer(
      ignoring: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, (pad > 0 ? pad - 6 : 6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white30.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
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
              // Removed background highlight pill per request; only icon color indicates selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_items.length, (i) {
                  final selected = i == currentIndex;
                  final item = _items[i];
                  return _NavIcon(
                    icon: item.icon,
                    label: item.label,
                    selected: selected,
                    onTap: () => onItemSelected(i),
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
    final primary = AppColors.primary;
    final color = selected ? primary : Colors.black.withValues(alpha: .45);
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

// Backwards compat constant for older helpers
const double kVisionNavBarHeight = VisionNavBar.kHeight;
